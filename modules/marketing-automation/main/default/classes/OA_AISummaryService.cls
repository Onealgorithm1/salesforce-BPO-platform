// ── SKELETON — not deployable without Named Credential ──────────────────────────
// Deployment prerequisite: create a Named Credential named "OA_Anthropic":
//   Label:              OA Anthropic API
//   Name:               OA_Anthropic
//   URL:                https://api.anthropic.com
//   Identity Type:      Named Principal
//   Authentication:     No Authentication (key is passed in x-api-key header)
//   Custom Headers:     x-api-key = <Anthropic API key from Anthropic console>
//                       anthropic-version = 2023-06-01
// Alternatively, store the API key in a Protected Custom Setting and add it at runtime.
// ─────────────────────────────────────────────────────────────────────────────────
public class OA_AISummaryService {

    @TestVisible private static final String ENDPOINT =
        'callout:OA_Anthropic/v1/messages';

    private static final String  MODEL      = 'claude-sonnet-4-6';
    private static final Integer MAX_TOKENS = 2048;

    // System prompt establishes the B2G analysis context for One Algorithm LLC.
    // Output must be valid JSON matching the schema in OUTPUT_SCHEMA_INSTRUCTION so
    // the caller can deserialize the response without regex fragility.
    private static final String SYSTEM_PROMPT =
        'You are a B2G (business-to-government) business development analyst for One Algorithm LLC, '
        + 'an 8(a)-eligible, EDWOSB technology firm specializing in AI/ML solutions, data engineering, '
        + 'and digital modernization for U.S. federal agencies. '
        + 'You analyze introductory meeting transcripts between Louis Rubino (OA principal) and external '
        + 'parties (prospective teaming partners, prime contractors, or government representatives). '
        + 'Your job is to extract actionable business intelligence from the transcript and produce a '
        + 'structured JSON object. Do not hallucinate or infer beyond what is stated in the transcript. '
        + 'Be concise and factual. Output only the JSON object — no markdown, no explanation.';

    private static final String OUTPUT_SCHEMA_INSTRUCTION =
        'Analyze the transcript and return ONLY a valid JSON object with the following fields:\n'
        + '{\n'
        + '  "customer_needs": ["string array of stated pain points, requirements, or problems"],\n'
        + '  "opportunities_identified": ["string array of specific teaming, subcontracting, or capture opportunities"],\n'
        + '  "risks_or_concerns": ["string array of objections, red flags, or areas of uncertainty"],\n'
        + '  "action_items": ["string array of explicit next steps committed during the meeting"],\n'
        + '  "follow_up_commitments": ["string array of deliverables OA committed to send or schedule"],\n'
        + '  "proposal_indicators": ["string array of signals that a proposal or capability statement was requested"],\n'
        + '  "teaming_indicators": ["string array of signals pointing to a teaming agreement or partnership"],\n'
        + '  "recommended_outcome": "one of: Meeting Completed | Qualified Opportunity | Teaming Opportunity | Follow-Up Required | Proposal Requested | No Action Required | Not Interested",\n'
        + '  "confidence": "one of: High | Medium | Low",\n'
        + '  "summary_paragraph": "2-4 sentence narrative summary of the meeting outcome and next steps"\n'
        + '}';

    // ── Public entry point: called after OA_ArtifactPoller sets Recording_Retrieved__c ──
    // The @future wrapper is required because this class makes HTTP callouts and is
    // intended to be invoked from a Flow, trigger, or post-artifact-retrieval process.
    // Idempotency: exits immediately if AI_Summary__c is already populated.
    @future(callout=true)
    public static void summarize(Id leadId) {
        Lead lead = [
            SELECT Id, FirstName, LastName, Company, Transcript_Content__c, AI_Summary__c
            FROM Lead WHERE Id = :leadId LIMIT 1
        ];

        if (String.isBlank(lead.Transcript_Content__c)) {
            System.debug('[OA_AISummaryService] No transcript content for Lead ' + leadId + '. Exiting.');
            return;
        }

        if (lead.AI_Summary__c != null) {
            System.debug('[OA_AISummaryService] Summary already exists for Lead ' + leadId + '. Skipping.');
            return;
        }

        String requestBody = buildRequest(lead);
        String rawResponse = callAnthropicApi(requestBody);
        if (rawResponse == null) return;

        String summaryJson = extractContent(rawResponse);
        if (String.isBlank(summaryJson)) {
            System.debug('[OA_AISummaryService] No content in Anthropic response for Lead ' + leadId);
            return;
        }

        try {
            update new Lead(Id = leadId, AI_Summary__c = summaryJson.left(32768));
            System.debug('[OA_AISummaryService] AI_Summary__c updated for Lead ' + leadId);
        } catch (Exception e) {
            System.debug('[OA_AISummaryService] Lead update failed: ' + e.getMessage());
        }
    }

    // ── Build the Anthropic messages API request body ────────────────────────────
    @TestVisible
    static String buildRequest(Lead lead) {
        String userContent = 'Company: ' + (lead.Company != null ? lead.Company : 'Unknown') + '\n'
            + 'Contact: ' + (lead.FirstName != null ? lead.FirstName : '') + ' '
            + (lead.LastName != null ? lead.LastName : '') + '\n\n'
            + OUTPUT_SCHEMA_INSTRUCTION + '\n\n'
            + 'TRANSCRIPT:\n'
            + lead.Transcript_Content__c;

        // Apex has no JSON serialization for dynamic message arrays, so build manually.
        // The transcript is injected as a string value — it does not contain JSON metacharacters
        // that would break the payload (VTT preprocessing strips all angle brackets and colons
        // outside of "Speaker: text" format). Sanitize the content to be safe.
        String sanitizedContent = userContent.replace('\\', '\\\\').replace('"', '\\"')
            .replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t');

        return '{'
            + '"model":"' + MODEL + '",'
            + '"max_tokens":' + MAX_TOKENS + ','
            + '"system":"' + SYSTEM_PROMPT.replace('"', '\\"') + '",'
            + '"messages":[{"role":"user","content":"' + sanitizedContent + '"}]'
            + '}';
    }

    // ── Call the Anthropic Messages API ─────────────────────────────────────────
    @TestVisible
    static String callAnthropicApi(String requestBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setBody(requestBody);
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('[OA_AISummaryService] Anthropic API HTTP ' + res.getStatusCode()
                + ': ' + res.getBody().abbreviate(300));
            return null;
        }
        return res.getBody();
    }

    // ── Extract the text content from the Anthropic response payload ─────────────
    // Response shape: {"content":[{"type":"text","text":"..."}],...}
    @TestVisible
    static String extractContent(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> content = (List<Object>) parsed.get('content');
            if (content == null || content.isEmpty()) return null;
            Map<String, Object> block = (Map<String, Object>) content[0];
            return (String) block.get('text');
        } catch (Exception e) {
            System.debug('[OA_AISummaryService] Response parse error: ' + e.getMessage());
            return null;
        }
    }
}
