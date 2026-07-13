// Self-check — runs with `node test/smoke.mjs`, no network, no real keys.
// Fails loudly if request-building or key-redaction regresses.
import assert from 'node:assert/strict';
import { buildEntityUrl, buildOpportunitiesUrl, redact } from '../src/sam.js';

const KEY = 'TESTKEY123';

// Entity: valid search encodes the filter and the key.
const eUrl = buildEntityUrl({ legalBusinessName: 'Medianow' }, KEY);
assert.match(eUrl, /entity-information\/v3\/entities/);
assert.match(eUrl, /legalBusinessName=Medianow/);
assert.match(eUrl, /api_key=TESTKEY123/);

// Entity: no filter is rejected (don't pull the whole registry).
assert.throws(() => buildEntityUrl({}, KEY), /legalBusinessName or ueiSAM/);
// Entity: missing key is rejected.
assert.throws(() => buildEntityUrl({ ueiSAM: 'X' }), /not configured/);

// Opportunities: valid window builds; required dates enforced; format checked.
const oUrl = buildOpportunitiesUrl(
  { title: 'janitorial', postedFrom: '01/01/2026', postedTo: '06/30/2026', typeOfSetAside: 'EDWOSB' },
  KEY,
);
assert.match(oUrl, /opportunities\/v2\/search/);
assert.match(oUrl, /typeOfSetAside=EDWOSB/);
assert.throws(() => buildOpportunitiesUrl({ postedFrom: '2026-01-01', postedTo: '2026-06-30' }, KEY), /MM\/dd\/yyyy/);
assert.throws(() => buildOpportunitiesUrl({ postedFrom: '01/01/2026' }, KEY), /MM\/dd\/yyyy/);
assert.throws(() => buildOpportunitiesUrl({ postedFrom: '01/01/2020', postedTo: '01/01/2026' }, KEY), /<= 1 year/);
assert.throws(() => buildOpportunitiesUrl({ postedFrom: '06/30/2026', postedTo: '01/01/2026' }, KEY), /on or after/);

// Redaction: the key must never survive into a loggable/returnable string.
assert.equal(redact(eUrl).includes(KEY), false, 'api_key leaked past redact()');
assert.match(redact(oUrl), /api_key=\*\*\*/);

console.log('sam-gov smoke: OK');
