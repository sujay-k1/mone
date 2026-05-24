const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ---------------------------------------------------------------------------
// Paytm checksum: SHA-256 + AES-128-CBC + random salt
// IV is fixed: '@@@@&&&&####$$$$'
// ---------------------------------------------------------------------------

const IV = "@@@@&&&&####$$$$";

// Salt: 4 random bytes → base64 (matches Node.js crypto.randomBytes(3).toString('base64'))
function randomSalt(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(3));
  return btoa(String.fromCharCode(...bytes));
}

async function sha256Hex(input: string): Promise<string> {
  const encoded = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// AES-128-CBC with binary (latin1) input encoding — matches Node.js cipher.update(input, 'binary', 'base64')
async function aes128CbcEncrypt(data: string, key: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(key).slice(0, 16);
  const ivBytes = new TextEncoder().encode(IV);

  // Encode as latin1 (binary) — one byte per char
  const dataBytes = new Uint8Array(data.length);
  for (let i = 0; i < data.length; i++) {
    dataBytes[i] = data.charCodeAt(i) & 0xff;
  }

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-CBC" },
    false,
    ["encrypt"],
  );

  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv: ivBytes },
    cryptoKey,
    dataBytes,
  );

  return btoa(String.fromCharCode(...new Uint8Array(encrypted)));
}

async function generateChecksum(body: string, merchantKey: string): Promise<string> {
  const salt = randomSalt();
  const hashHex = await sha256Hex(`${body}|${salt}`);
  // hashString = sha256hex + salt — this is what gets AES encrypted
  const hashString = hashHex + salt;
  return await aes128CbcEncrypt(hashString, merchantKey);
}

// ---------------------------------------------------------------------------
// Step 1: Initiate transaction to get a txnToken
// ---------------------------------------------------------------------------

async function fetchTxnToken(
  mid: string,
  merchantKey: string,
  orderId: string,
): Promise<string> {
  const requestTimestamp = Math.floor(Date.now() / 1000);

  const bodyPayload = {
    requestType: "Payment",
    mid,
    websiteName: "WEBSTAGING",
    orderId,
    callbackUrl: `https://securestage.paytmpayments.com/theia/paytmCallback?ORDER_ID=${orderId}`,
    txnAmount: { value: "1.00", currency: "INR" },
    userInfo: { custId: "CUST_001" },
  };

  const bodyString = JSON.stringify(bodyPayload);
  const checksum = await generateChecksum(bodyString, merchantKey);

  const response = await fetch(
    `https://securestage.paytmpayments.com/theia/api/v1/initiateTransaction?mid=${mid}&orderId=${orderId}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        body: bodyPayload,
        head: {
          version: "v1",
          requestTimestamp,
          requestId: String(requestTimestamp),
          signature: checksum,
        },
      }),
    },
  );

  const data = await response.json();
  const token = data?.body?.txnToken;

  if (!token) {
    throw new Error(`Failed to get txnToken: ${JSON.stringify(data?.body ?? data)}`);
  }

  return token;
}

// ---------------------------------------------------------------------------
// Step 2: Validate VPA
// ---------------------------------------------------------------------------

async function validateVPA(
  vpa: string,
  mid: string,
  txnToken: string,
  orderId: string,
): Promise<{ valid: boolean; name?: string }> {
  const requestTimestamp = Math.floor(Date.now() / 1000);

  const response = await fetch(
    `https://securestage.paytmpayments.com/theia/api/v1/vpa/validate?mid=${mid}&orderId=${orderId}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        body: { vpa, mid },
        head: {
          version: "v1",
          requestTimestamp,
          requestId: String(requestTimestamp),
          tokenType: "TXN_TOKEN",
          txnToken,
        },
      }),
    },
  );

  const data = await response.json();
  const resultStatus = data?.body?.resultInfo?.resultStatus;
  const name = data?.body?.payerAccountDetails?.payerName ?? undefined;

  return {
    valid: resultStatus === "S",
    name,
    rawResponse: data,
  };
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return jsonResponse({ ok: true }, 200);
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  try {
    const mid = Deno.env.get("PAYTM_MERCHANT_ID");
    const merchantKey = Deno.env.get("PAYTM_MERCHANT_KEY");

    if (!mid || !merchantKey) {
      return jsonResponse({ error: "Missing Paytm credentials" }, 500);
    }

    const { vpa } = await req.json();

    if (!vpa || typeof vpa !== "string" || !vpa.includes("@")) {
      return jsonResponse({ error: "Invalid VPA format" }, 400);
    }

    const orderId = `VPA_${Date.now()}`;
    const txnToken = await fetchTxnToken(mid, merchantKey, orderId);
    const result = await validateVPA(vpa, mid, txnToken, orderId);

    return jsonResponse({ valid: result.valid, name: result.name ?? null, vpa, rawResponse: result.rawResponse }, 200);
  } catch (error) {
    return jsonResponse({ error: "Unexpected error", details: String(error) }, 500);
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
