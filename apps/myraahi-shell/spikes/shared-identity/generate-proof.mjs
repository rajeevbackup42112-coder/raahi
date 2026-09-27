import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const required = ["SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "EXPECTED_SUBJECT_SHA256"];
for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

const outputDir = resolve(".generated-shared-identity-proof");
await mkdir(outputDir, { recursive: true });

const config = {
  supabaseUrl: process.env.SUPABASE_URL,
  publishableKey: process.env.SUPABASE_PUBLISHABLE_KEY,
  expectedSubjectSha256: process.env.EXPECTED_SUBJECT_SHA256.toLowerCase(),
};

const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>MyRaahi Shared Identity Proof</title>
  <style>
    body{font-family:system-ui,sans-serif;max-width:720px;margin:40px auto;padding:0 20px;line-height:1.5}
    button{padding:12px 16px;margin-right:8px}
    pre{white-space:pre-wrap;background:#f6f7f6;padding:16px;border-radius:12px}
    .warn{padding:12px 14px;background:#fff7df;border-radius:10px}
  </style>
</head>
<body>
  <h1>MyRaahi Shared Identity Proof</h1>
  <p class="warn"><strong>TEST ONLY.</strong> This proves identity continuity. It does not change Raahi roles, trust, or product data.</p>
  <p>Use the same designated Google test identity already authenticated in Raahi Learn.</p>
  <button id="google">Continue with Google</button>
  <button id="signout">Sign out proof session</button>
  <pre id="result">Checking session…</pre>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.116.0/dist/umd/supabase.min.js"></script>
  <script>
  (() => {
    "use strict";
    const config = ${JSON.stringify(config)};
    const result = document.getElementById("result");
    const client = window.supabase.createClient(
      config.supabaseUrl,
      config.publishableKey,
      { auth: { persistSession: true, detectSessionInUrl: true, autoRefreshToken: true } }
    );

    async function sha256(value) {
      const bytes = new TextEncoder().encode(value);
      const hash = await crypto.subtle.digest("SHA-256", bytes);
      return [...new Uint8Array(hash)].map(b => b.toString(16).padStart(2, "0")).join("");
    }

    async function render() {
      const { data: sessionData, error: sessionError } = await client.auth.getSession();
      if (sessionError) throw sessionError;
      if (!sessionData.session) {
        result.textContent = JSON.stringify({
          session_present: false,
          same_raahi_subject: null
        }, null, 2);
        return;
      }

      const { data: userData, error: userError } = await client.auth.getUser();
      if (userError) throw userError;
      if (!userData.user) throw new Error("Authenticated session has no user.");

      const actualHash = await sha256(userData.user.id);
      result.textContent = JSON.stringify({
        session_present: true,
        same_raahi_subject: actualHash === config.expectedSubjectSha256,
        provider: userData.user.app_metadata?.provider ?? null,
        issuer: config.supabaseUrl + "/auth/v1"
      }, null, 2);
    }

    document.getElementById("google").onclick = async () => {
      const redirectTo = location.origin + location.pathname;
      const { error } = await client.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo }
      });
      if (error) result.textContent = JSON.stringify({ error: error.message }, null, 2);
    };

    document.getElementById("signout").onclick = async () => {
      const { error } = await client.auth.signOut({ scope: "local" });
      if (error) {
        result.textContent = JSON.stringify({ error: error.message }, null, 2);
        return;
      }
      await render();
    };

    render().catch(error => {
      result.textContent = JSON.stringify({ error: error.message }, null, 2);
    });
  })();
  </script>
</body>
</html>`;

await writeFile(resolve(outputDir, "index.html"), html, "utf8");
console.log(resolve(outputDir, "index.html"));
