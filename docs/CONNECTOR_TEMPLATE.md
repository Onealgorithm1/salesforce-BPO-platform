# Connector Template — add a new connector in a few hours

_Copy this template, replace `Xxx`/`XXX` with your source, and fill the three source-specific
methods. You should not touch any platform class. Reference: the SAM.gov connector (Phase 8) +
`CONNECTOR_DEVELOPER_GUIDE.md`._

After Phase 9, a connector is: **3 source methods (Request/Parser/Mapper) + one class that
implements `OA_IEnrichmentConnector` + metadata.** The `OA_ConnectorRunner` dispatches it
generically from the registry — no platform code changes, no `if source == …`.

---

## 1. Required classes (4) + tests

### `OA_Xxx_Request`
```apex
public with sharing class OA_Xxx_Request {
    private static final String DEFAULT_NAMED_CRED = 'OA_Xxx';
    private static final String DEFAULT_PATH = '/your/endpoint/path';
    public HttpRequest build(String input, OA_Connector_Registry__mdt cfg) {
        String nc = (cfg != null && String.isNotBlank(cfg.Named_Credential__c)) ? cfg.Named_Credential__c : DEFAULT_NAMED_CRED;
        String path = (cfg != null && String.isNotBlank(cfg.Endpoint_Path__c)) ? cfg.Endpoint_Path__c : DEFAULT_PATH;
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + nc + path + '?q=' + EncodingUtil.urlEncode(input == null ? '' : input, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);
        return req;                 // NEVER put a key in the URL — inject it via the External Credential
    }
}
```

### `OA_Xxx_ResponseParser` — the only place your source's JSON shape lives
```apex
public with sharing class OA_Xxx_ResponseParser {
    public class ParseException extends Exception {}
    public List<OA_CanonicalOrg> parse(String body) {
        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();
        Map<String, Object> root;
        try { root = (Map<String, Object>) JSON.deserializeUntyped(body); }
        catch (Exception e) { throw new ParseException('Xxx: malformed body — ' + e.getMessage()); }
        Object records = root.get('results');            // <- your result array key
        if (!(records instanceof List<Object>)) { return out; }   // graceful empty
        for (Object o : (List<Object>) records) {
            Map<String, Object> rec = (Map<String, Object>) o;
            OA_CanonicalOrg org = new OA_CanonicalOrg();
            org.sourceSystem = 'Xxx';
            org.uei = str(rec.get('uei'));               // map identifiers you have
            org.organizationName = str(rec.get('name'));
            org.normalizedName = OA_NameNormalizer.normalize(org.organizationName);
            if (String.isNotBlank(str(rec.get('someStatus')))) { org.attributes.put('Some_Status', str(rec.get('someStatus'))); }
            // Unavailable field? leave it null — NEVER fabricate.
            org.sourceConfidence = org.hasDeterministicId() ? OA_ConfidenceEvaluator.HIGH
                : (String.isNotBlank(org.organizationName) ? OA_ConfidenceEvaluator.MEDIUM : OA_ConfidenceEvaluator.LOW);
            org.sourcePayloadHash = org.payloadHash();
            out.add(org);
        }
        return out;
    }
    private static String str(Object o) { return o == null ? null : String.valueOf(o); }
}
```

### `OA_Xxx_Mapper` — canonical → CRM field proposals
```apex
public with sharing class OA_Xxx_Mapper {
    public static final String SOURCE = 'Xxx';
    public List<OA_EnrichmentWriter.FieldProposal> toLeadProposals(OA_CanonicalOrg org) {
        List<OA_EnrichmentWriter.FieldProposal> ps = new List<OA_EnrichmentWriter.FieldProposal>();
        if (org == null) { return ps; }
        String band = String.isBlank(org.sourceConfidence) ? OA_ConfidenceEvaluator.LOW : org.sourceConfidence;
        add(ps, 'UEI__c', org.uei, band);
        add(ps, 'Website', org.website, band);
        // add(ps, 'Your_Field__c', org.attributes.get('Some_Status'), band);
        return ps;
    }
    private static void add(List<OA_EnrichmentWriter.FieldProposal> ps, String field, Object v, String band) {
        if (v != null && String.isNotBlank(String.valueOf(v))) { ps.add(new OA_EnrichmentWriter.FieldProposal(field, v, SOURCE, band)); }
    }
}
```

### `OA_Xxx_Connector` — implements the interface (boilerplate; copy from SAM)
```apex
public with sharing class OA_Xxx_Connector implements OA_IEnrichmentConnector {
    public static final String SOURCE_KEY = 'Xxx';
    @TestVisible private static Boolean debugStoreRawPayload = false;   // OFF by default; never auto
    public String sourceKey() { return SOURCE_KEY; }
    public OA_ConnectorResult fetch(String input) { return fetch(input, null); }
    public OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg) {
        OA_ConnectorResult res = new OA_ConnectorResult(SOURCE_KEY);
        res.requested = 1;
        HttpRequest req = new OA_Xxx_Request().build(input, cfg);
        try {
            HttpResponse http = new Http().send(req);
            res.lastStatus = http.getStatusCode();
            if (debugStoreRawPayload) { res.rawPayload = http.getBody(); }
            if (res.lastStatus < 200 || res.lastStatus >= 300) { res.httpErrors++; res.messages.add('HTTP ' + res.lastStatus); return res; }
            res.organizations = new OA_Xxx_ResponseParser().parse(http.getBody());
            res.parsed = res.organizations.size();
        } catch (OA_Xxx_ResponseParser.ParseException pe) { res.parseErrors++; res.messages.add('Parse: ' + pe.getMessage()); }
        catch (Exception e) { res.httpErrors++; res.messages.add(e.getTypeName() + ': ' + e.getMessage()); }
        return res;
    }
}
```

**Tests (≥90%):** request (routes via NC, no key in URL); parser contract (identifiers exist,
additive/unknown tolerated, malformed → ParseException, unavailable → null); mapper (present values
only); connector (mock 2xx / non-2xx / malformed / thrown; raw payload off/on). Reuse the SAM test
classes as a pattern.

## 2. Required metadata (all dormant: `Enabled__c=false`, `Active__c=false`, `Status=Draft`)
- `OA_Connector_Registry.Xxx` — `Source_System__c='Xxx'`, `Connector_Class__c='OA_Xxx_Connector'`,
  `Parser_Class__c`, `Mapper_Class__c`, `Named_Credential__c`, `Endpoint_Path__c`, `Category__c`,
  `Version__c='1.0.0'`, `Enabled__c=false`, `Review_Required__c=true`, `Owner_Steward__c`.
- `OA_Enrichment_Source.Xxx` — `Precedence__c`, `Trusted__c`, `Active__c=false`.
- `OA_Enrichment_Pipeline.Xxx_*` — Ingest(`OA_Xxx_Connector`)/Qualify/Write steps, `Enabled__c=false`.
- `OA_Field_Write_Policy.Xxx_*` — one per CRM field, `Active__c=false`.
- `OA_Qualification_Rule.*` — ICP rules for discovery (if used), `Active__c=false`.

## 3. Run it (dispatch is generic — you write no dispatcher code)
```apex
OA_ConnectorRunner.RunOutcome out = new OA_ConnectorRunner().run('Xxx', input, 'Your_ICP_Ruleset');
// out.organizations, out.recordsQualified, out.durationMs, out.runRecord (telemetry) ...
```

## 4. Confidence expectations
Deterministic identifier match (UEI/EIN/NPI/CIK/CAGE) → `HIGH` (the only auto-write-eligible band);
name-only → `MEDIUM`; weak → `LOW`. Don't re-implement banding — set `sourceConfidence` and let the
platform decide.

## 5. Definition of Done
```
[ ] 4 classes written (Request/Parser/Mapper/Connector implements OA_IEnrichmentConnector)
[ ] Canonical mapping; unavailable fields null + documented; confidence set
[ ] Registry + Source + Pipeline + Field-Policy CMDT records (dormant)
[ ] Tests ≥90% (request/parser-contract/mapper/connector)
[ ] Check-only validated; committed; NOT deployed/enabled
[ ] No platform class touched
```
