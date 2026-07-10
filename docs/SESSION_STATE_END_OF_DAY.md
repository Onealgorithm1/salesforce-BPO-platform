# Session State — End of Day

## EMAIL AUTH — CLOSED (2026-07-10)

**`onealgorithm.com` email authentication is fully configured. No fix needed — do not re-investigate.**

Verified via read-only DNS lookups:
- **SPF** — `v=spf1 include:spf.protection.outlook.com include:_spf.salesforce.com ~all` → authorizes **Microsoft 365** and **Salesforce**.
- **M365 DKIM** — `selector1` / `selector2` `_domainkey` CNAMEs resolve to `…dkim.mail.microsoft`.
- **Salesforce DKIM** — `salesforce1` / `salesforce2` `_domainkey` CNAMEs **live in Cloudflare (DNS-only / unproxied)**, resolving to `…custdkim.salesforce.com`.
- **DMARC** — `v=DMARC1; p=quarantine; adkim=r; aspf=r; rua=mailto:dmarc_rua@onsecureserver.net;` → policy **`p=quarantine`**.

**Note — separate outreach stack:** `mycrm.onealgorithm.com` runs an independent stack (**Mailgun + GoHighLevel**) with **DMARC `p=none`**. Distinct from the primary domain above; not part of this closure.
