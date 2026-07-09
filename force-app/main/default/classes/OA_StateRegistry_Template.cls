/**
 * OA_StateRegistry_Template — reusable base connector for state business registries (no hardcoded
 * state). Implements the frozen OA_IEnrichmentConnector; a concrete state connector EXTENDS this and
 * overrides parseBody() with that state's response shape. The generic fetch/request flow is shared.
 *
 * Why a template (not a live connector): U.S. state business registries have NO uniform public API —
 * formats, auth, and rate limits differ per Secretary of State, and many have no stable free JSON
 * interface at all (see CONNECTOR_STATE_GUIDE.md). This template lets a state connector be added by
 * writing only a parseBody override + metadata, with zero platform change. The default parseBody
 * handles a generic { "results":[ {name, entityNumber, status, formationDate, registeredAgent, state} ] }
 * shape so the template is directly usable/testable.
 *
 * State-registry records have no canonical identifier (entity numbers are state-scoped) -> MEDIUM
 * confidence (name-based); they enrich by name + state, never as a deterministic identity source.
 */
public virtual with sharing class OA_StateRegistry_Template implements OA_IEnrichmentConnector {

    protected String stateKey = 'StateRegistry';

    @TestVisible
    private static Boolean debugStoreRawPayload = false;

    public virtual String sourceKey() { return stateKey; }

    public OA_ConnectorResult fetch(String input, OA_Connector_Registry__mdt cfg) {
        OA_ConnectorResult res = new OA_ConnectorResult(sourceKey());
        res.requested = 1;
        HttpRequest req = new OA_StateRegistry_Request().build(input, cfg);
        try {
            HttpResponse http = new Http().send(req);
            res.lastStatus = http.getStatusCode();
            if (debugStoreRawPayload) { res.rawPayload = http.getBody(); }
            if (res.lastStatus < 200 || res.lastStatus >= 300) {
                res.httpErrors++;
                res.messages.add('HTTP ' + res.lastStatus + ' from state registry ' + sourceKey() + '.');
                return res;
            }
            res.organizations = parseBody(http.getBody());
            res.parsed = res.organizations.size();
        } catch (Exception e) {
            res.httpErrors++;
            res.messages.add(e.getTypeName() + ': ' + e.getMessage());
        }
        return res;
    }

    /** Override per state. Default handles the generic search-results shape. */
    protected virtual List<OA_CanonicalOrg> parseBody(String body) {
        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();
        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(body);
        } catch (Exception e) {
            return out; // tolerate; a state override can enforce stricter parsing
        }
        if (!(parsed instanceof Map<String, Object>)) { return out; }
        Object results = ((Map<String, Object>) parsed).get('results');
        if (!(results instanceof List<Object>)) { return out; }

        for (Object o : (List<Object>) results) {
            if (!(o instanceof Map<String, Object>)) { continue; }
            Map<String, Object> rec = (Map<String, Object>) o;
            OA_CanonicalOrg org = new OA_CanonicalOrg();
            org.sourceSystem = sourceKey();
            org.organizationName = str(rec.get('name'));
            org.normalizedName = OA_NameNormalizer.normalize(org.organizationName);
            org.state = str(rec.get('state'));
            putIf(org, 'State_Entity_Number', str(rec.get('entityNumber')));
            putIf(org, 'State_Registration_Status', str(rec.get('status')));
            putIf(org, 'State_Formation_Date', str(rec.get('formationDate')));
            putIf(org, 'Registered_Agent', str(rec.get('registeredAgent')));
            org.sourceConfidence = String.isNotBlank(org.organizationName)
                ? OA_ConfidenceEvaluator.MEDIUM : OA_ConfidenceEvaluator.LOW;
            org.sourcePayloadHash = org.payloadHash();
            out.add(org);
        }
        return out;
    }

    private static void putIf(OA_CanonicalOrg org, String key, String value) {
        if (String.isNotBlank(value)) { org.attributes.put(key, value); }
    }
    private static String str(Object o) { return o == null ? null : String.valueOf(o); }
}