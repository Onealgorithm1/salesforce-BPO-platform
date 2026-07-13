// SAM.gov remote MCP server for Cloudflare Workers.
// Exposes two tools to Claude: entity lookup + contract-opportunity search.
// Keys are Worker secrets (SAM_ENTITY_API_KEY, SAM_OPPORTUNITIES_API_KEY) —
// never in code, logs, or the repo. Transport is Streamable HTTP at /mcp
// (SSE is deprecated). Gate the /mcp route with Cloudflare Access before
// exposing publicly — see README.md.
import { McpAgent } from 'agents/mcp';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { buildEntityUrl, buildOpportunitiesUrl, redact } from './sam.js';

interface Env {
  SAM_ENTITY_API_KEY: string;
  SAM_OPPORTUNITIES_API_KEY: string;
}

async function samGet(url: string) {
  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  const body = await res.text();
  if (!res.ok) {
    // redact() strips the api_key so the key never reaches Claude or a log.
    throw new Error(`SAM.gov ${res.status} for ${redact(url)} :: ${body.slice(0, 500)}`);
  }
  return body; // already JSON text; hand back verbatim for Claude to read
}

export class SamMcp extends McpAgent<Env> {
  server = new McpServer({ name: 'sam-gov', version: '1.0.0' });

  async init() {
    const env = this.env;

    this.server.tool(
      'sam_entity_search',
      'Look up a federal entity in SAM.gov (UEI/CAGE, registration status, ' +
        'socioeconomic flags). Provide legalBusinessName or ueiSAM.',
      {
        legalBusinessName: z.string().optional(),
        ueiSAM: z.string().optional(),
        registrationStatus: z.string().optional().describe("e.g. 'A' for active"),
        samRegistered: z.enum(['Yes', 'No']).optional(),
        includeSections: z.string().optional().describe('e.g. entityRegistration,coreData'),
        size: z.number().int().min(1).max(100).optional(),
      },
      async (params) => {
        const url = buildEntityUrl(params, env.SAM_ENTITY_API_KEY);
        return { content: [{ type: 'text', text: await samGet(url) }] };
      },
    );

    this.server.tool(
      'sam_opportunities_search',
      'Search federal contract opportunities on SAM.gov. postedFrom and ' +
        'postedTo are required (MM/dd/yyyy, <= 1 year apart).',
      {
        title: z.string().optional(),
        postedFrom: z.string().describe('MM/dd/yyyy'),
        postedTo: z.string().describe('MM/dd/yyyy'),
        naicsCode: z.string().optional(),
        typeOfSetAside: z.string().optional().describe("e.g. EDWOSB, WOSB, SBA"),
        ptype: z.string().optional().describe("e.g. 'o' solicitation, 'k' combined"),
        state: z.string().optional(),
        limit: z.number().int().min(1).max(1000).optional(),
        offset: z.number().int().min(0).optional(),
      },
      async (params) => {
        const url = buildOpportunitiesUrl(params, env.SAM_OPPORTUNITIES_API_KEY);
        return { content: [{ type: 'text', text: await samGet(url) }] };
      },
    );
  }
}

// Streamable HTTP transport. For production, replace this default export with
// the Cloudflare Access / OAuth wrapper from the remote-mcp-cf-access template
// (README.md, step 5) so the SAM-key-backed server is not publicly callable.
export default SamMcp.serve('/mcp');
