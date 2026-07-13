# SAM.gov → Claude custom connector (remote MCP on Cloudflare)

Wraps the two SAM.gov APIs this platform already uses — **Entity Management**
(`OA_SAM`) and **Contract Opportunities** (`OA_SAM_Opportunities`) — as a remote
MCP server so Claude can query them. Claude talks MCP to this Worker; the Worker
calls SAM.gov with your two API keys, held as **Worker secrets** (never in this
repo, never pasted into the Claude dialog).

> **Why not paste the SAM.gov key into Claude's "Add custom connector" box?**
> That box wants the URL of a *running MCP server*, not an API key. SAM.gov has
> no MCP server — this is it. After you deploy, the URL you paste is
> `https://sam-gov-mcp.<your-subdomain>.workers.dev/mcp`.

## Tools exposed
| Tool | SAM.gov API | Key (Worker secret) |
|---|---|---|
| `sam_entity_search` | Entity Management v3 | `SAM_ENTITY_API_KEY` |
| `sam_opportunities_search` | Opportunities v2 | `SAM_OPPORTUNITIES_API_KEY` |

## Prerequisites
- Node.js + npm, and a Cloudflare account (`npx wrangler login`).
- Your two SAM.gov keys (from SAM.gov account → *System Accounts* / API key).
  Keep them out of chat, commits, and screenshots.

## Deploy (the ASAP path)
Run from `mcp-servers/sam-gov/`:

```sh
npm install
npm test                       # self-check: request building + key redaction

wrangler secret put SAM_ENTITY_API_KEY          # paste key 1 when prompted
wrangler secret put SAM_OPPORTUNITIES_API_KEY   # paste key 2 when prompted
wrangler deploy                                 # -> sam-gov-mcp.<sub>.workers.dev
```

Smoke-test the deployed server before wiring Claude: open
<https://playground.ai.cloudflare.com/>, add the `/mcp` URL, and confirm the two
tools list. (Or use the MCP Inspector.)

## Add it to Claude
Claude → **Settings → Connectors → Add custom connector**:
- **Remote MCP server URL:** `https://sam-gov-mcp.<your-subdomain>.workers.dev/mcp`
- Leave **OAuth Client ID/Secret** blank for the first test.

## ⚠️ Before real use: gate the endpoint (do not skip)
As written, the default export is an **authless** Streamable-HTTP server — anyone
who learns the URL can spend your SAM.gov quota. Put auth in front before you
rely on it. Two supported options:

1. **Cloudflare Access (recommended, matches Claude's OAuth fields).** Scaffold
   the OAuth wiring from Cloudflare's template and drop `src/index.ts`'s two
   tools into it:
   ```sh
   npm create cloudflare@latest -- sam-gov-mcp \
     --template=cloudflare/ai/demos/remote-mcp-cf-access
   ```
   Then create an **Access for SaaS** app, store its client ID/secret as Worker
   secrets, and Claude will complete the OAuth login on connect. Ref:
   <https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/secure-mcp-servers/>
2. **Cloudflare Access self-hosted app** over the Worker route — network-layer
   gate, no code change.

## Notes / limits
- Transport is **Streamable HTTP at `/mcp`** (SSE is deprecated).
- SAM.gov sends the key as an `api_key=` query param; `redact()` masks it in
  every error/log path so it can't leak back to Claude.
- Opportunities requires `postedFrom`/`postedTo` as `MM/dd/yyyy`, span ≤ 1 year.
- Entity search requires `legalBusinessName` or `ueiSAM` (no bare "list all").
- This directory is **not part of the Salesforce deploy** — it's a standalone
  Node/Workers project. Nothing here touches the production org.
```
