/**
 * OA_ConnectorRow — one normalized result row.
 *
 * Part of the Connector SDK foundation (Sprint 1B). A source-agnostic key/value
 * holder with typed accessors, produced by a parser and consumed by a mapper.
 * Keeps the framework decoupled from any source-specific DTO.
 */
public class OA_ConnectorRow {

    private final Map<String, Object> values;

    public OA_ConnectorRow() {
        this.values = new Map<String, Object>();
    }

    public OA_ConnectorRow(Map<String, Object> values) {
        this.values = values != null ? values : new Map<String, Object>();
    }

    /** Fluent setter. */
    public OA_ConnectorRow put(String key, Object value) {
        values.put(key, value);
        return this;
    }

    public Boolean has(String key) {
        return values.containsKey(key);
    }

    public Object get(String key) {
        return values.get(key);
    }

    public String getString(String key) {
        Object v = values.get(key);
        return v == null ? null : String.valueOf(v);
    }

    public Decimal getDecimal(String key) {
        Object v = values.get(key);
        return v == null ? null : Decimal.valueOf(String.valueOf(v));
    }

    /** Read-only view of the underlying values. */
    public Map<String, Object> asMap() {
        return new Map<String, Object>(values);
    }
}