import { sendAPNsNotification } from "../_shared/apns.ts";

type Job = {
  id: string; lease_id: string; installation_id: string; user_id: string; band_id: string;
  token: string; bundle_id: string; environment: "sandbox" | "production";
  payload: { title: string; body: string; notification_type: string; practice_id: string; band_id: string };
};

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), {
  status, headers: { "content-type": "application/json", "cache-control": "no-store" },
});

// A dedicated worker secret authenticates database webhooks/Cron, not user JWTs.
// Use modern Supabase secret keys when configured, with legacy service-role fallback.
const serviceKey = () => {
  const named = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (named) {
    try { return JSON.parse(named).default as string; } catch { return undefined; }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
};

export async function handlePracticePush(request: Request): Promise<Response> {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const secret = Deno.env.get("PRACTICE_PUSH_WORKER_SECRET");
  if (!secret || request.headers.get("x-practice-push-secret") !== secret) return json({ error: "unauthorized" }, 401);
  const project = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  if (!project || !key || !Deno.env.get("APNS_KEY_ID") || !Deno.env.get("APNS_TEAM_ID") || !Deno.env.get("APNS_PRIVATE_KEY")) {
    return json({ error: "push_not_configured" }, 503); // Do not claim jobs until credentials exist.
  }
  const headers = {
    apikey: key, ...(key.startsWith("sb_secret_") ? {} : { Authorization: `Bearer ${key}` }),
    "content-type": "application/json", "cache-control": "no-store",
  };
  const api = (path: string, options: RequestInit = {}) => fetch(`${project}/rest/v1/${path}`, {
    ...options, headers, signal: AbortSignal.timeout(10_000),
  });
  const finish = async (job: Job, error: string | null, terminal: boolean) => {
    const result = await api("rpc/finish_practice_push_job", { method: "POST", body: JSON.stringify({
      p_id: job.id, p_lease_id: job.lease_id, p_error: error, p_terminal: terminal,
    }) });
    if (!result.ok) throw new Error("finish_failed");
  };
  try {
    const claimed = await api("rpc/claim_practice_push_jobs", { method: "POST", body: "{}" });
    if (!claimed.ok) return json({ error: "claim_failed" }, 503);
    const jobs = await claimed.json() as Job[];
    // Five concurrent sends keep the batch bounded without serial APNs latency.
    let accepted = 0, skipped = 0, retrying = 0;
    for (let offset = 0; offset < jobs.length; offset += 5) {
      await Promise.all(jobs.slice(offset, offset + 5).map(async (job) => {
        try {
          // Revalidate account/device ownership and membership just before sending.
          // Never send to someone who left a band or changed accounts after enqueue.
          const [membership, device] = await Promise.all([
            api(`band_members?band_id=eq.${job.band_id}&user_id=eq.${job.user_id}&select=id`),
            api(`practice_push_devices?installation_id=eq.${job.installation_id}&user_id=eq.${job.user_id}&token=eq.${job.token}&select=installation_id`),
          ]);
          if (!membership.ok || !device.ok) throw new Error("recipient_lookup_failed");
          if (!(await membership.json()).length || !(await device.json()).length) {
            await finish(job, "recipient_unavailable", true); skipped++; return;
          }
          const result = await sendAPNsNotification(job, {
            title: job.payload.title, body: job.payload.body, id: job.id,
            expiresAt: Math.floor(Date.now() / 1000) + 3600,
            data: { notification_type: job.payload.notification_type, band_id: job.band_id,
              practice_id: job.payload.practice_id, notification_id: job.id },
          });
          let reason = "unknown";
          try { reason = JSON.parse(result.reason).reason ?? reason; } catch { /* No response body on success. */ }
          if (result.ok) { await finish(job, null, true); accepted++; return; }
          if (result.status === 410 || ["BadDeviceToken", "DeviceTokenNotForTopic"].includes(reason)) {
            // Conditional delete cannot remove a freshly rotated token.
            const removed = await api(`practice_push_devices?installation_id=eq.${job.installation_id}&token=eq.${job.token}`, { method: "DELETE" });
            if (!removed.ok) throw new Error("token_cleanup_failed");
            skipped++; return;
          }
          const terminal = result.status === 400 || result.status === 413;
          await finish(job, `APNs ${result.status}: ${reason}`, terminal);
          if (terminal) skipped++; else retrying++;
        } catch {
          await finish(job, "delivery_unavailable", false);
          retrying++;
        }
      }));
    }
    // "Accepted" is APNs acceptance, not confirmed device or calendar delivery.
    return json({ claimed: jobs.length, accepted, skipped, retrying });
  } catch {
    return json({ error: "worker_unavailable" }, 503);
  }
}

Deno.serve(handlePracticePush);
