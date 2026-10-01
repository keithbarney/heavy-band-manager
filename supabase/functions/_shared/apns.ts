type APNsEnvironment = "sandbox" | "production";

type APNsDevice = {
  token: string;
  bundle_id: string;
  environment: APNsEnvironment;
};

type APNsPayload = {
  title: string;
  body: string;
  data: Record<string, unknown>;
  id: string;
  expiresAt: number;
};

const base64url = (bytes: Uint8Array) => {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
};

const utf8 = (value: string) => new TextEncoder().encode(value);

const pemBytes = (pem: string) => {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
};

const signatureBytes = (value: ArrayBuffer) => {
  const bytes = new Uint8Array(value);
  if (bytes.length === 64) return bytes;
  // WebCrypto implementations may return an ASN.1 DER ECDSA signature.
  // APNs JWTs require the fixed-width r || s form.
  if (bytes[0] !== 0x30) throw new Error("unexpected APNs signature format");
  let index = 2;
  if (bytes[1] & 0x80) index += bytes[1] & 0x7f;
  if (bytes[index++] !== 0x02) throw new Error("invalid APNs signature r");
  const rLength = bytes[index++];
  const r = bytes.slice(index, index + rLength);
  index += rLength;
  if (bytes[index++] !== 0x02) throw new Error("invalid APNs signature s");
  const sLength = bytes[index++];
  const s = bytes.slice(index, index + sLength);
  const result = new Uint8Array(64);
  result.set(r.slice(-32), 32 - Math.min(32, r.length));
  result.set(s.slice(-32), 64 - Math.min(32, s.length));
  return result;
};

let cachedProviderToken: { value: Promise<string>; expires: number } | undefined;
const createProviderToken = async () => {
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  if (!keyID || !teamID || !privateKey) throw new Error("APNs provider credentials are not configured");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64url(utf8(JSON.stringify({ alg: "ES256", kid: keyID })));
  const claims = base64url(utf8(JSON.stringify({ iss: teamID, iat: Math.floor(Date.now() / 1000) })));
  const signingInput = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    utf8(signingInput),
  );
  return `${signingInput}.${base64url(signatureBytes(signature))}`;
};

const providerToken = () => {
  if (!cachedProviderToken || Date.now() >= cachedProviderToken.expires) {
    const value = createProviderToken();
    cachedProviderToken = { value, expires: Date.now() + 50 * 60 * 1000 };
    value.catch(() => { cachedProviderToken = undefined; });
  }
  return cachedProviderToken.value;
};

export const sendAPNsNotification = async (device: APNsDevice, payload: APNsPayload) => {
  const token = await providerToken();
  const host = device.environment === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${device.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${token}`,
      "apns-topic": device.bundle_id,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-id": payload.id,
      "apns-collapse-id": payload.id,
      "apns-expiration": String(payload.expiresAt),
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title: payload.title, body: Array.from(payload.body).slice(0, 300).join("") },
        sound: "default",
        "content-available": 1,
      },
      ...payload.data,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  const responseBody = await response.text();
  return { ok: response.ok, status: response.status, reason: responseBody };
};
