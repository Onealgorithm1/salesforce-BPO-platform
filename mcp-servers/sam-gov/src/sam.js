// Pure SAM.gov request builders — no network, no secrets baked in.
// Imported by the Worker (src/index.ts) and exercised by test/smoke.mjs.
// SAM.gov auth model: the API key travels as an `api_key=` query param
// (per docs/SAM_CONNECTOR_RUNBOOK.md). Never log a raw URL — use redact().

const ENTITY_BASE = 'https://api.sam.gov/entity-information/v3/entities';
const OPPS_BASE = 'https://api.sam.gov/opportunities/v2/search';

/** MM/dd/yyyy — the only date format the Opportunities API accepts. */
const DATE_RE = /^(0[1-9]|1[0-2])\/(0[1-9]|[12]\d|3[01])\/\d{4}$/;

function put(sp, key, val) {
  if (val !== undefined && val !== null && String(val).trim() !== '') {
    sp.set(key, String(val).trim());
  }
}

/**
 * Entity Management API (v3). Requires at least one identifying filter so we
 * never pull the whole registry. Throws on missing key / no filter.
 */
export function buildEntityUrl(params = {}, apiKey) {
  if (!apiKey) throw new Error('SAM_ENTITY_API_KEY is not configured');
  const { legalBusinessName, ueiSAM, registrationStatus, samRegistered, includeSections, page, size } = params;
  if (!legalBusinessName && !ueiSAM) {
    throw new Error('Provide legalBusinessName or ueiSAM to search entities');
  }
  const sp = new URLSearchParams();
  put(sp, 'api_key', apiKey);
  put(sp, 'legalBusinessName', legalBusinessName);
  put(sp, 'ueiSAM', ueiSAM);
  put(sp, 'registrationStatus', registrationStatus); // e.g. 'A' (active)
  put(sp, 'samRegistered', samRegistered);           // 'Yes' | 'No'
  put(sp, 'includeSections', includeSections);       // e.g. 'entityRegistration,coreData'
  put(sp, 'page', page ?? 0);
  put(sp, 'size', size ?? 10);
  return `${ENTITY_BASE}?${sp.toString()}`;
}

/**
 * Contract Opportunities API (v2). postedFrom/postedTo are required and must
 * be MM/dd/yyyy with a span of <= 1 year. Throws otherwise.
 */
export function buildOpportunitiesUrl(params = {}, apiKey) {
  if (!apiKey) throw new Error('SAM_OPPORTUNITIES_API_KEY is not configured');
  const { title, postedFrom, postedTo, ptype, naicsCode, typeOfSetAside, state, limit, offset } = params;
  if (!DATE_RE.test(postedFrom || '') || !DATE_RE.test(postedTo || '')) {
    throw new Error('postedFrom and postedTo are required as MM/dd/yyyy');
  }
  const span = (new Date(postedTo) - new Date(postedFrom));
  if (span < 0) throw new Error('postedTo must be on or after postedFrom');
  if (span > 366 * 864e5) throw new Error('postedFrom..postedTo must span <= 1 year');
  const sp = new URLSearchParams();
  put(sp, 'api_key', apiKey);
  put(sp, 'title', title);
  put(sp, 'postedFrom', postedFrom);
  put(sp, 'postedTo', postedTo);
  put(sp, 'ptype', ptype);                 // e.g. 'o' solicitation, 'k' combined
  put(sp, 'ncode', naicsCode);
  put(sp, 'typeOfSetAside', typeOfSetAside); // e.g. 'EDWOSB','WOSB','SBA'
  put(sp, 'state', state);
  put(sp, 'limit', Math.min(Number(limit) || 10, 1000));
  put(sp, 'offset', Number(offset) || 0);
  return `${OPPS_BASE}?${sp.toString()}`;
}

/** Mask the api_key so a URL is safe to log or return in an error. */
export function redact(url) {
  return String(url).replace(/(\bapi_key=)[^&]+/gi, '$1***');
}
