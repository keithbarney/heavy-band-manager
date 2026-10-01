import assert from "node:assert/strict";
import test from "node:test";

const env = { SUPABASE_URL: "https://project.test", SUPABASE_SERVICE_ROLE_KEY: "service",
  PRACTICE_PUSH_WORKER_SECRET: "worker-secret", APNS_KEY_ID: "key", APNS_TEAM_ID: "team" };
const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
env.APNS_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(await crypto.subtle.exportKey("pkcs8", pair.privateKey)).toString("base64")}\n-----END PRIVATE KEY-----`;
globalThis.Deno = { env: { get: key => env[key] }, serve: () => {} };
const { handlePracticePush } = await import("./index.ts");
const request = (secret = "worker-secret") => new Request("https://project.test/functions/v1/practice-push", {
  method: "POST", headers: { "x-practice-push-secret": secret },
});
const job = { id: "10000000-0000-4000-8000-000000000001", lease_id: "lease",
  installation_id: "device", user_id: "user", band_id: "band", token: "a".repeat(64),
  bundle_id: "com.keithbarney.heavybandmanager.local", environment: "sandbox",
  payload: { title: "Practice Location Changed", body: "The practice location was changed.",
    notification_type: "practice_location_changed", practice_id: "practice" } };
const reply = value => new Response(JSON.stringify(value));

test("rejects unauthenticated calls and leaves queued jobs untouched without APNs credentials", async () => {
  globalThis.fetch = () => { throw Error("Must not contact backend"); };
  assert.equal((await handlePracticePush(request("wrong"))).status, 401);
  const key = env.APNS_KEY_ID;
  delete env.APNS_KEY_ID;
  assert.equal((await handlePracticePush(request())).status, 503);
  env.APNS_KEY_ID = key;
});

test("location alert requests background refresh and preserves navigation identifiers", async () => {
  let push, finish;
  globalThis.fetch = async (url, options) => {
    if (url.includes("claim_practice")) return reply([job]);
    if (url.includes("band_members?")) return reply([{ id: "member" }]);
    if (url.includes("practice_push_devices?")) return reply([{ installation_id: "device" }]);
    if (url.includes("push.apple.com")) { push = options; return new Response(null); }
    if (url.includes("finish_practice")) { finish = JSON.parse(options.body); return new Response(null); }
    throw Error("Unexpected endpoint");
  };
  const result = await handlePracticePush(request());
  assert.equal((await result.json()).accepted, 1);
  const payload = JSON.parse(push.body);
  assert.equal(payload.aps.alert.title, "Practice Location Changed");
  assert.equal(payload.aps["content-available"], 1);
  assert.equal(payload.practice_id, "practice");
  assert.equal(push.headers["apns-topic"], job.bundle_id);
  assert.equal(push.headers["apns-push-type"], "alert");
  assert.equal(finish.p_terminal, true);
});

test("membership removal and account replacement suppress a queued private alert", async () => {
  for (const missing of ["band_members?", "practice_push_devices?"]) {
    let sent = false;
    globalThis.fetch = async url => {
      if (url.includes("claim_practice")) return reply([job]);
      if (url.includes(missing)) return reply([]);
      if (url.includes("band_members?") || url.includes("practice_push_devices?")) return reply([{}]);
      if (url.includes("finish_practice")) return new Response(null);
      sent = true;
      throw Error("Should not send");
    };
    assert.equal((await (await handlePracticePush(request())).json()).skipped, 1);
    assert.equal(sent, false);
  }
});

test("transient APNs failure retries; invalid tokens are removed; provider-auth failures preserve tokens", async () => {
  for (const [status, reason, shouldDelete, terminal] of [[503, "ServiceUnavailable", false, false],
    [410, "Unregistered", true, true], [400, "BadDeviceToken", true, true], [403, "InvalidProviderToken", false, false]]) {
    let deleted = false, finished;
    globalThis.fetch = async (url, options) => {
      if (url.includes("claim_practice")) return reply([job]);
      if (url.includes("band_members?")) return reply([{}]);
      if (url.includes("practice_push_devices?")) {
        if (options.method === "DELETE") { deleted = true; return new Response(null); }
        return reply([{}]);
      }
      if (url.includes("push.apple.com")) return new Response(JSON.stringify({ reason }), { status });
      if (url.includes("finish_practice")) { finished = JSON.parse(options.body); return new Response(null); }
      throw Error("Unexpected endpoint");
    };
    assert.equal((await handlePracticePush(request())).status, 200);
    assert.equal(deleted, shouldDelete);
    if (!shouldDelete) assert.equal(finished.p_terminal, terminal);
  }
});

test("modern Supabase secret keys never become Bearer JWTs", async () => {
  env.SUPABASE_SECRET_KEYS = '{"default":"sb_secret_test"}';
  globalThis.fetch = async (_url, options) => {
    assert.equal(options.headers.apikey, "sb_secret_test");
    assert.equal(options.headers.Authorization, undefined);
    return reply([]);
  };
  assert.equal((await handlePracticePush(request())).status, 200);
  delete env.SUPABASE_SECRET_KEYS;
});
