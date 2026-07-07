# Social Credential Setup — LinkedIn & Meta (Louis: click-by-click)

**Org:** `00Dbn00000plgUfEAI` (oauser@pboedition.com) · **My Domain:** `onealgorithmllc.my.salesforce.com`
**Runtime user:** `oauser@pboedition.com` · **Rule:** never paste a secret into chat, a file, or Git — only into the Salesforce Setup fields named below.

> Status: no secrets are stored yet. Follow the steps for each platform, then tell Claude "secrets entered" to run the read-only smoke test.

---

## LinkedIn (OAuth 2.0 — 3-legged; needs an Auth Provider)

LinkedIn requires a Client Secret **in an Auth Provider**, which then generates the callback URL. This is a UI step only you can do.

### Step 1 — Create the Auth Provider
Setup → **Identity → Auth. Providers → New**
- **Provider Type:** `LinkedIn`
- **Name:** `OA LinkedIn`  ·  **URL Suffix:** `OA_LinkedIn`
- **Consumer Key:** ← enter your **LinkedIn Client ID**
- **Consumer Secret:** ← enter your **LinkedIn Client Secret** *(secret — never share)*
- **Default Scopes:** start minimal `openid profile email` (add approved-product scopes later, space-separated)
- **Save.** Then copy the **Callback URL** Salesforce shows — it will look like:
  `https://onealgorithmllc.my.salesforce.com/services/authcallback/OA_LinkedIn`

### Step 2 — Register the callback in LinkedIn
LinkedIn Developer Portal → your app → **Auth** tab → **Authorized redirect URLs** → paste the exact Callback URL from Step 1 → Save.

### Step 3 — Create the External Credential
Setup → **Security → Named Credentials → External Credentials tab → New**
- **Label:** `OA LinkedIn`  ·  **Name:** `OA_LinkedIn`
- **Authentication Protocol:** `OAuth 2.0`
- **Authentication Flow Type:** `Browser Flow`
- **Identity Provider (Auth Provider):** `OA_LinkedIn`
- **Scope:** same as Step 1
- Under **Principals → New:** Name `OA_LinkedIn_Principal`, Sequence `1` → Save
- On the principal, click **Authenticate** → a browser opens → sign in as the **company LinkedIn admin** → **Allow**.

### Step 4 — Named Credential (metadata already prepared)
`OA_LinkedIn` (endpoint `https://api.linkedin.com`, references the EC). Claude deploys it after the EC exists, or create it in UI: Named Credentials tab → New → URL `https://api.linkedin.com`, External Credential `OA_LinkedIn`, Type `SecuredEndpoint`.

### Step 5 — Grant the runtime user
Setup → **Permission Sets → `OA_LinkedIn_Connector`** → **External Credential Principal Access** → add `OA_LinkedIn - OA_LinkedIn_Principal` → then **Manage Assignments → Add** `oauser@pboedition.com`.

**LinkedIn test URL (read-only, after setup):** `callout:OA_LinkedIn/v2/userinfo` (returns the authenticated member; status + top-level shape only).

**Fields where you enter secrets:** Auth Provider → *Consumer Key* (Client ID), *Consumer Secret* (Client Secret). Nowhere else.

---

## Meta / Facebook (System User token — no Auth Provider, no redirect URI)

Meta uses a **non-expiring Business System User token** stored in a **Custom** External Credential. No OAuth browser flow, no callback URL.

### Step 1 — Get the token in Meta (Business Manager)
Meta Business Settings → **System Users** → your System User → **assign assets** (the ad account) → **Generate New Token** → select app `OA BPO Connector Hub`, permission **`ads_read`**, expiration **Never** → copy the token *(secret)*.

### Step 2 — Create the External Credential
Setup → **Security → Named Credentials → External Credentials tab → New**
- **Label:** `OA Meta`  ·  **Name:** `OA_Meta`
- **Authentication Protocol:** `Custom`
- Under **Principals → New:** Name `OA_Meta_Principal`, Sequence `1`
  - **Authentication Parameter →** Name: `AccessToken`, Value: ← paste the **System User token** *(secret — never share)*
- Under **Custom Headers → New:** Name: `Authorization`, Value: `Bearer {!$Credential.OA_Meta.AccessToken}`
- **Save.**

### Step 3 — Named Credential (metadata prepared on branch `feature/meta-connector-int011`)
`OA_Meta` → endpoint `https://graph.facebook.com`, External Credential `OA_Meta`, `generateAuthorizationHeader = false` (the custom header carries the token).

### Step 4 — Grant the runtime user
Setup → **Permission Sets → `OA_Meta_Connector`** → **External Credential Principal Access** → add `OA_Meta - OA_Meta_Principal` → **Manage Assignments → Add** `oauser@pboedition.com`.

**Meta test URL (read-only, after setup):** `callout:OA_Meta/v21.0/me` (returns the System User id/name; status + top-level shape only).

**Field where you enter the secret:** External Credential principal → Authentication Parameter *AccessToken*. Nowhere else.

---

## What Claude will NOT do
Enter/observe your secrets · scrape profiles/pages · write Leads/Campaigns · run enrichment/ads changes. After you enter the secrets and say "done", Claude runs one read-only status-code smoke test per platform and reports only the HTTP status + top-level JSON shape.
