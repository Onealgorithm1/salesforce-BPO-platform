/**
 * OA_ConnectorException — the framework's error type.
 *
 * Part of the Connector SDK foundation (Sprint 1B). Thrown for framework-level
 * failures (e.g. a null connector or an unparseable body). Note: a non-2xx HTTP
 * response is NOT thrown — the engine records it as an outcome for diagnosis.
 */
public virtual class OA_ConnectorException extends Exception {}
