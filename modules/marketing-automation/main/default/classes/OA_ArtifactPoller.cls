public class OA_ArtifactPoller implements Schedulable {

    // Schedule: System.schedule('OA Artifact Poller', '0 15 * * * ?', new OA_ArtifactPoller());
    // Runs at :15 past every hour. Retrieves recording and transcript artifacts for all
    // Leads that have a confirmed Teams meeting but have not yet had artifacts retrieved.

    public void execute(SchedulableContext sc) {
        processArtifacts();
    }

    @future(callout=true)
    public static void processArtifacts() {
        OA_Graph_Config__mdt cfg = OA_Graph_Config__mdt.getInstance('Default');
        if (cfg == null || !cfg.Is_Enabled__c) {
            System.debug('[OA_ArtifactPoller] Not configured or disabled. Exiting.');
            return;
        }

        OA_Graph_Credential__c cred = OA_Graph_Credential__c.getOrgDefaults();
        if (cred == null || String.isBlank(cred.Client_Id__c) || String.isBlank(cred.Tenant_Id__c)) {
            System.debug('[OA_ArtifactPoller] Graph credentials not configured. Exiting.');
            return;
        }

        // Limit 20: worst-case 1 (token) + 3 × 20 = 61 callouts — well within the 100 limit.
        // Recording_Retrieved__c = false is the idempotency guard; once set true, the lead
        // is permanently excluded from all future poller queries.
        List<Lead> candidates = [
            SELECT Id, Teams_Meeting_Id__c, Recording_Id__c, Transcript_Id__c
            FROM Lead
            WHERE Teams_Meeting_Id__c != null
            AND Recording_Retrieved__c = false
            AND IsConverted = false
            LIMIT 20
        ];

        if (candidates.isEmpty()) {
            System.debug('[OA_ArtifactPoller] No leads pending artifact retrieval.');
            return;
        }

        System.debug('[OA_ArtifactPoller] Processing ' + candidates.size() + ' candidate Lead(s).');

        String token = getAccessToken(cred);
        if (token == null) {
            System.debug('[OA_ArtifactPoller] Failed to obtain Graph access token. Exiting.');
            return;
        }

        List<Lead> toUpdate = new List<Lead>();

        for (Lead lead : candidates) {
            try {
                Lead updated = processLeadArtifacts(lead, token, cfg.Graph_User_OID__c);
                if (updated != null) {
                    toUpdate.add(updated);
                }
            } catch (Exception e) {
                System.debug('[OA_ArtifactPoller] Error processing Lead ' + lead.Id
                    + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
                // Non-fatal: continue processing remaining leads; this lead retries next cycle.
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('[OA_ArtifactPoller] Updated ' + toUpdate.size() + ' Lead(s) with retrieved artifacts.');

            // Handoff to AI summary for any Lead where transcript content was retrieved.
            // System.enqueueJob from @future is allowed; the Queueable bridges the
            // @future-to-@future restriction before calling OA_AISummaryService.summarize.
            for (Lead updated : toUpdate) {
                if (updated.Transcript_Content__c != null) {
                    System.enqueueJob(new OA_AISummaryQueueable(updated.Id));
                    System.debug('[OA_ArtifactPoller] AI summary handoff enqueued for Lead ' + updated.Id);
                }
            }
        }
    }

    // ── Process a single Lead — retrieve recording and transcript ────────────────
    // Returns a Lead sObject ready for DML if artifacts were retrieved, or null if
    // the meeting has no artifacts yet (retry next cycle by leaving flag false).
    private static Lead processLeadArtifacts(Lead lead, String token, String graphUserOid) {
        String meetingId = lead.Teams_Meeting_Id__c;

        // Callout 1: check whether any recordings are available for this meeting.
        String recordingId = getFirstRecordingId(meetingId, token, graphUserOid);
        if (recordingId == null) {
            System.debug('[OA_ArtifactPoller] No recording available yet for Lead ' + lead.Id
                + ' — will retry next cycle.');
            return null;
        }
        System.debug('[OA_ArtifactPoller] Recording found for Lead ' + lead.Id + ': ' + recordingId);

        // Callout 2: check whether any transcripts are available.
        String transcriptId = getFirstTranscriptId(meetingId, token, graphUserOid);
        String transcriptContent = null;

        if (transcriptId != null) {
            System.debug('[OA_ArtifactPoller] Transcript found for Lead ' + lead.Id + ': ' + transcriptId);
            // Callout 3: retrieve VTT content and preprocess into clean dialogue text.
            String rawVtt = getTranscriptContent(meetingId, transcriptId, token, graphUserOid);
            if (rawVtt != null) {
                transcriptContent = preprocessVtt(rawVtt);
                System.debug('[OA_ArtifactPoller] Transcript content retrieved ('
                    + (transcriptContent != null ? transcriptContent.length() : 0) + ' chars).');
            }
        } else {
            System.debug('[OA_ArtifactPoller] No transcript available for Lead ' + lead.Id
                + ' — storing recording only and marking retrieved.');
        }

        // Build the sObject for DML. Recording_Retrieved__c is set true here because
        // a recording was confirmed — this Lead will not be queried again. Transcript
        // fields are null-safe (stored if retrieved, left null otherwise).
        return new Lead(
            Id                       = lead.Id,
            Recording_Id__c          = recordingId,
            Transcript_Id__c         = transcriptId,
            Transcript_Content__c    = transcriptContent,
            Recording_Retrieved__c   = true
        );
    }

    // ── Graph: get the ID of the first available recording for a meeting ─────────
    private static String getFirstRecordingId(String meetingId, String token, String graphUserOid) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + graphUserOid
            + '/onlineMeetings/' + EncodingUtil.urlEncode(meetingId, 'UTF-8')
            + '/recordings?$select=id,createdDateTime&$top=1');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('[OA_ArtifactPoller] Recordings GET HTTP ' + res.getStatusCode()
                + ' for meeting ' + meetingId.left(40) + ': ' + res.getBody().abbreviate(200));
            return null;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> recordings  = (List<Object>) body.get('value');
        if (recordings == null || recordings.isEmpty()) return null;

        return (String)((Map<String, Object>) recordings[0]).get('id');
    }

    // ── Graph: get the ID of the first available transcript for a meeting ────────
    private static String getFirstTranscriptId(String meetingId, String token, String graphUserOid) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + graphUserOid
            + '/onlineMeetings/' + EncodingUtil.urlEncode(meetingId, 'UTF-8')
            + '/transcripts?$select=id&$top=1');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('[OA_ArtifactPoller] Transcripts GET HTTP ' + res.getStatusCode()
                + ': ' + res.getBody().abbreviate(200));
            return null;
        }

        Map<String, Object> body   = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> transcripts   = (List<Object>) body.get('value');
        if (transcripts == null || transcripts.isEmpty()) return null;

        return (String)((Map<String, Object>) transcripts[0]).get('id');
    }

    // ── Graph: retrieve VTT transcript content ────────────────────────────────────
    // Returns raw VTT string or null on any error. Content is passed through preprocessVtt()
    // before storage — the raw VTT is never persisted.
    private static String getTranscriptContent(String meetingId, String transcriptId,
                                                String token, String graphUserOid) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + graphUserOid
            + '/onlineMeetings/' + EncodingUtil.urlEncode(meetingId, 'UTF-8')
            + '/transcripts/' + EncodingUtil.urlEncode(transcriptId, 'UTF-8')
            + '/content?$format=text/vtt');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'text/vtt');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('[OA_ArtifactPoller] Transcript content GET HTTP ' + res.getStatusCode()
                + ': ' + res.getBody().abbreviate(200));
            return null;
        }

        String body = res.getBody();
        return String.isBlank(body) ? null : body;
    }

    // ── VTT preprocessing: strip header and timestamps, extract speaker dialogue ──
    // Input:  raw VTT text from Graph transcript content endpoint
    // Output: clean "Speaker: Text" lines joined by newlines; suitable for AI input
    // Rules:
    //   - Skip the "WEBVTT" header line
    //   - Skip blank lines and numeric-only cue identifier lines
    //   - Skip timestamp lines (contain " --> ")
    //   - Speaker cue lines match "<v Speaker Name>Text</v>" — extract both parts
    //   - Any non-matching content line is preserved as-is
    // The result is truncated to 120000 chars to fit within Transcript_Content__c (131072 max).
    @TestVisible
    static String preprocessVtt(String vtt) {
        if (String.isBlank(vtt)) return null;

        List<String> lines  = vtt.split('\n');
        List<String> output = new List<String>();

        for (String rawLine : lines) {
            String line = rawLine.trim();
            if (line.length() == 0) continue;
            if (line.equalsIgnoreCase('WEBVTT')) continue;
            if (line.contains(' --> ')) continue;
            if (line.isNumeric()) continue;

            // Teams VTT speaker cue: <v Speaker Name>Text</v>
            if (line.startsWith('<v ') && line.contains('>')) {
                Integer nameEnd   = line.indexOf('>');
                String speaker    = line.substring(3, nameEnd).trim();
                String text       = line.substring(nameEnd + 1);
                // Strip closing </v> tag if present
                if (text.endsWith('</v>')) {
                    text = text.substring(0, text.length() - 4);
                }
                text = text.trim();
                if (String.isNotBlank(text)) {
                    output.add(speaker + ': ' + text);
                }
                continue;
            }

            output.add(line);
        }

        if (output.isEmpty()) return null;
        String joined = String.join(output, '\n');
        return joined.length() > 120000 ? joined.left(120000) : joined;
    }

    // ── Microsoft OAuth 2.0 Client Credentials token ────────────────────────────
    private static String getAccessToken(OA_Graph_Credential__c cred) {
        String tokenEndpoint = 'https://login.microsoftonline.com/'
            + cred.Tenant_Id__c.trim()
            + '/oauth2/v2.0/token';

        String reqBody = 'client_id='     + EncodingUtil.urlEncode(cred.Client_Id__c.trim(), 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(cred.Client_Secret__c.trim(), 'UTF-8')
            + '&scope='         + EncodingUtil.urlEncode('https://graph.microsoft.com/.default', 'UTF-8')
            + '&grant_type=client_credentials';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(reqBody);
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('[OA_ArtifactPoller] Token endpoint HTTP ' + res.getStatusCode()
                + ': ' + res.getBody().abbreviate(300));
            return null;
        }

        Map<String, Object> tokenResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) tokenResp.get('access_token');
    }
}
