# State Business Registry Connector Guide

_Status: **framework + guide** · 2026-07-06. A reusable pattern for Secretary-of-State / business-
registry connectors. No specific state connector is implemented live (see §3)._

## Why a template, not one connector
U.S. state business registries have **no uniform public API**. Formats, authentication, rate limits,
and even availability differ by Secretary of State. Many expose only a search **UI** (no API), some
require paid bulk subscriptions, and field names/semantics vary. A single hardcoded connector cannot
serve all states — so the platform provides a **reusable template** that each state connector extends.

## The pattern (no platform change)
- **`OA_StateRegistry_Request`** — generic request builder; the state-specific Named Credential +
  endpoint path come from `OA_Connector_Registry__mdt` (never hardcoded).
- **`OA_StateRegistry_Template`** — a `virtual` connector implementing the frozen
  `OA_IEnrichmentConnector`. The shared fetch flow (request → send → parse → canonical) lives here; a
  state connector overrides only `parseBody(body)` with that state's response shape. The default
  `parseBody` handles a generic `{results:[{name, entityNumber, status, formationDate, registeredAgent,
  state}]}` shape so the template is directly usable.
- **`OA_StateRegistry_Mapper`** — canonical → Lead state-registry fields (entity number, status,
  formation date, registered agent, state). Reused by every state.

Add a state in ~half a day: `public class OA_StateRegistry_VA extends OA_StateRegistry_Template {
OA_StateRegistry_VA(){ this.stateKey='StateRegistry_VA'; } protected override List<OA_CanonicalOrg>
parseBody(String body){ /* VA SCC shape */ } }` + a registry record. No platform code changes.

## Per-state differences to capture (in the registry / Notes)
| Concern | Varies by state — examples |
|---|---|
| Interface | JSON API (few), CSV/bulk, or search-UI-only (no API) |
| Auth | none / API key / account login / paid subscription |
| Identifiers | state entity number (state-scoped — NOT a canonical identifier → MEDIUM confidence) |
| Fields | entity name/number, status, type, formation date, registered agent, principal address |
| Rate limits | often unpublished; be conservative |
| Terms | some prohibit automated access / redistribution — check ToS before enabling |

Examples of state interfaces (verify current status before building): VA SCC (Clerk's Information
System), DE Division of Corporations, CA SoS (bizfile), TX SoSDirect, FL Sunbiz, NY DOS. Availability
and API stability change — confirm a **stable public interface** before implementing a live connector.

## Confidence & entity resolution
State entity numbers are **state-scoped**, not a cross-source canonical identifier, so state-registry
records resolve at **MEDIUM** (name + state), never as a deterministic identity source. They enrich an
existing org (matched by name+state) with formation/status data; identity comes from SAM/USASpending/
IRS/SEC.

## Status
Template + generic request/mapper **built and validated (dormant)**; a state-specific override is
demonstrated by a test subclass. **No live state connector is implemented** until a state with a stable
public interface + acceptable ToS is selected.
