/**
 * OA_ConnectorTestBase — shared test scaffolding for the Connector SDK.
 *
 * Part of the Connector SDK foundation (Sprint 1B). Provides a generic, source-
 * agnostic FAKE connector used to exercise the engine WITHOUT any real source
 * (USASpending is untouched) and WITHOUT any custom object: the fake mapper
 * builds an in-memory Account (never inserted — the SDK does no DML).
 *
 * Test-only (@isTest) — not shipped as production code.
 *
 * Fake response contract (JSON): {"results":[{"name":"...","score": <number>}, ...]}
 * Sentinels for negative paths:
 *   - a body of 'FORCE_PARSE_ERROR' makes the parser throw (parse-error path).
 *   - a row whose name is 'BOOM' makes the mapper throw (map-error path).
 */
@isTest
public class OA_ConnectorTestBase {

    /** Build a run context with a deterministic run id. */
    public static OA_ConnectorContext newContext() {
        return new OA_ConnectorContext('TEST-RUN-0001');
    }

    /** A ready-to-use fake connector. */
    public static OA_IConnector fakeConnector() {
        return new FakeConnector();
    }

    /** Convenience: a JSON body with N simple result rows. */
    public static String resultsJson(Integer count) {
        List<Object> rows = new List<Object>();
        for (Integer i = 0; i < count; i++) {
            rows.add(new Map<String, Object>{ 'name' => 'Row ' + i, 'score' => 10 + i });
        }
        return JSON.serialize(new Map<String, Object>{ 'results' => rows });
    }

    // ---- Fake connector implementation (generic; no source-specific coupling) ----

    public class FakeConnector implements OA_IConnector {
        public String sourceKey() { return 'FAKE'; }
        public String namedCredential() { return 'callout:OA_Fake'; }
        public Schema.SObjectType stagingType() { return Account.SObjectType; }
        public OA_IConnectorRequest requestBuilder() { return new FakeRequest(); }
        public OA_IConnectorParser parser() { return new FakeParser(); }
        public OA_IConnectorMapper mapper() { return new FakeMapper(); }
    }

    public class FakeRequest implements OA_IConnectorRequest {
        public HttpRequest build(OA_ConnectorContext ctx, Object input) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:OA_Fake/search');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{ 'q' => String.valueOf(input) }));
            return req;
        }
    }

    public class FakeParser implements OA_IConnectorParser {
        public List<OA_ConnectorRow> parse(String body) {
            if (body == 'FORCE_PARSE_ERROR') {
                throw new OA_ConnectorException('Forced parse error (test sentinel).');
            }
            List<OA_ConnectorRow> out = new List<OA_ConnectorRow>();
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> rows = (List<Object>) parsed.get('results');
            if (rows == null) {
                return out;
            }
            for (Object o : rows) {
                Map<String, Object> m = (Map<String, Object>) o;
                out.add(new OA_ConnectorRow(m));
            }
            return out;
        }
    }

    public class FakeMapper implements OA_IConnectorMapper {
        public SObject toStaging(OA_ConnectorRow row, OA_ConnectorContext ctx) {
            String name = row.getString('name');
            if (name == 'BOOM') {
                throw new OA_ConnectorException('Forced map error (test sentinel).');
            }
            // In-memory only — NEVER inserted by the SDK foundation.
            return new Account(
                Name = name,
                Description = 'run=' + ctx.runId + '; endpoint=' + ctx.lastEndpoint
            );
        }
    }
}