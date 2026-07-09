/**
 * OA_IRS_ResponseParser — parses IRS Exempt Organizations Business Master File (EO BMF) rows.
 *
 * INGESTION MODEL: IRS Tax-Exempt data is published as BULK files (the EO BMF, refreshed monthly),
 * NOT a per-record REST API. This parser is therefore the reusable core of a BULK connector: it
 * accepts CSV content (a header row + data rows) and produces canonical organizations keyed by EIN
 * (a deterministic identifier -> HIGH confidence). Additive columns are tolerated (mapped by header
 * name); a schema change that drops the EIN column fails gracefully with a typed ParseException.
 *
 * The actual file retrieval/chunking (download the monthly EO BMF and feed chunks through this
 * connector via OA_ConnectorRunner) is an OPERATIONAL step — not built here (no scheduled jobs).
 */
public with sharing class OA_IRS_ResponseParser {

    public class ParseException extends Exception {}

    public List<OA_CanonicalOrg> parse(String csv) {
        List<OA_CanonicalOrg> out = new List<OA_CanonicalOrg>();
        if (String.isBlank(csv)) {
            return out;
        }
        List<String> lines = csv.replace('\r\n', '\n').replace('\r', '\n').split('\n');
        if (lines.size() < 2) {
            return out; // need header + at least one data row
        }
        Map<String, Integer> idx = header(lines[0]);
        if (!idx.containsKey('EIN')) {
            throw new ParseException('IRS: unexpected schema — EIN column not found in header.');
        }
        for (Integer i = 1; i < lines.size(); i++) {
            if (String.isBlank(lines[i])) { continue; }
            List<String> cols = lines[i].split(',');
            OA_CanonicalOrg org = new OA_CanonicalOrg();
            org.sourceSystem = 'IRS';
            org.ein = cell(cols, idx, 'EIN');
            org.organizationName = cell(cols, idx, 'NAME');
            org.normalizedName = OA_NameNormalizer.normalize(org.organizationName);
            org.address = cell(cols, idx, 'STREET');
            org.city = cell(cols, idx, 'CITY');
            org.state = cell(cols, idx, 'STATE');
            org.postalCode = cell(cols, idx, 'ZIP');
            putIf(org, 'Exempt_Status', cell(cols, idx, 'STATUS'));
            putIf(org, 'Subsection', cell(cols, idx, 'SUBSECTION'));
            putIf(org, 'Deductibility', cell(cols, idx, 'DEDUCTIBILITY'));
            putIf(org, 'Foundation_Type', cell(cols, idx, 'FOUNDATION'));
            putIf(org, 'Ruling_Date', cell(cols, idx, 'RULING'));
            putIf(org, 'NTEE_Code', cell(cols, idx, 'NTEE_CD'));
            org.sourceConfidence = org.hasDeterministicId()
                ? OA_ConfidenceEvaluator.HIGH
                : (String.isNotBlank(org.organizationName) ? OA_ConfidenceEvaluator.MEDIUM : OA_ConfidenceEvaluator.LOW);
            org.sourcePayloadHash = org.payloadHash();
            out.add(org);
        }
        return out;
    }

    private static Map<String, Integer> header(String line) {
        Map<String, Integer> idx = new Map<String, Integer>();
        List<String> cols = line.split(',');
        for (Integer i = 0; i < cols.size(); i++) {
            idx.put(cols[i].trim().toUpperCase(), i);
        }
        return idx;
    }
    private static String cell(List<String> cols, Map<String, Integer> idx, String col) {
        Integer i = idx.get(col);
        if (i == null || i >= cols.size()) { return null; }
        String v = cols[i] == null ? null : cols[i].trim();
        return String.isBlank(v) ? null : v;
    }
    private static void putIf(OA_CanonicalOrg org, String key, String value) {
        if (String.isNotBlank(value)) { org.attributes.put(key, value); }
    }
}