import { createClient } from "npm:@supabase/supabase-js@2";

type CreateConsentRequest = {
  mobileNumber?: string;
};

const DEFAULT_SANDBOX_MOBILE_NUMBER = "8828290489";

const DEFAULT_SETU_AA_FI_TYPES = [
  "DEPOSIT",
  "TERM_DEPOSIT",
  "RECURRING_DEPOSIT",
  "MUTUAL_FUNDS",
  "ETF",
  "EQUITIES",
  "NPS",
  "INSURANCE_POLICIES",
  "GSTR1_3B",
];

const DEFAULT_SETU_AA_CONSENT_TYPES = [
  "PROFILE",
  "SUMMARY",
  "TRANSACTIONS",
];

type SetuConsentContextItem = {
  key: string;
  value: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name);

  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }

  return value;
}

function getAnonKey(): string {
  const legacyAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (legacyAnonKey) {
    return legacyAnonKey;
  }

  const publishableKeysRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");

  if (publishableKeysRaw) {
    const publishableKeys = JSON.parse(publishableKeysRaw);
    if (publishableKeys.default) {
      return publishableKeys.default;
    }
  }

  throw new Error("Missing Supabase anon / publishable key");
}

function getServiceRoleKey(): string {
  const legacyServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (legacyServiceRoleKey) {
    return legacyServiceRoleKey;
  }

  const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS");

  if (secretKeysRaw) {
    const secretKeys = JSON.parse(secretKeysRaw);
    if (secretKeys.default) {
      return secretKeys.default;
    }
  }

  throw new Error("Missing Supabase service role / secret key");
}

function getBearerToken(req: Request): string {
  const authHeader = req.headers.get("Authorization");

  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing Authorization bearer token");
  }

  return authHeader.replace("Bearer ", "");
}

function normalizeIndianMobileNumber(input: string): string {
  const digits = input.replace(/\D/g, "");

  if (digits.length === 10) {
    return digits;
  }

  if (digits.length === 12 && digits.startsWith("91")) {
    return digits.slice(2);
  }

  throw new Error("Invalid mobile number. Expected a 10-digit Indian mobile number.");
}

function getIsoDateMonthsAgo(monthsAgo: number): string {
  const date = new Date();
  date.setMonth(date.getMonth() - monthsAgo);
  return date.toISOString();
}

function getSetuConsentEndpoint(): string {
  const explicitEndpoint = Deno.env.get("SETU_AA_CONSENT_ENDPOINT")?.trim();

  if (explicitEndpoint) {
    return explicitEndpoint.replace(/\/+$/, "");
  }

  const configuredBaseUrl = getRequiredEnv("SETU_AA_BASE_URL").replace(/\/+$/, "");
  const baseWithoutVersion = configuredBaseUrl.replace(/\/v2$/, "");
  return `${baseWithoutVersion}/v2/consents`;
}

function getSetuConsentFallbackEndpoint(): string | null {
  return null;
}

function getStringAtPath(value: unknown, path: string[]): string | undefined {
  let current = value;

  for (const key of path) {
    if (!current || typeof current !== "object" || !(key in current)) {
      return undefined;
    }

    current = (current as Record<string, unknown>)[key];
  }

  return typeof current === "string" ? current : undefined;
}

function getSetuDebugMessage(payload: unknown): string | undefined {
  return (
    getStringAtPath(payload, ["message"]) ??
    getStringAtPath(payload, ["error"]) ??
    getStringAtPath(payload, ["error", "message"]) ??
    getStringAtPath(payload, ["details", "message"]) ??
    getStringAtPath(payload, ["detail", "message"]) ??
    getStringAtPath(payload, ["title"])
  );
}

function getSetuTraceId(payload: unknown): string | undefined {
  return (
    getStringAtPath(payload, ["traceId"]) ??
    getStringAtPath(payload, ["trace_id"]) ??
    getStringAtPath(payload, ["error", "traceId"])
  );
}

function buildVua(mobileDigits: string): string {
  const configuredHandle = Deno.env.get("SETU_AA_VUA_HANDLE")
    ?.trim()
    .replace(/^@/, "");

  if (!configuredHandle) {
    return mobileDigits;
  }

  return `${mobileDigits}@${configuredHandle}`;
}

function getRequestedFiTypes(): string[] {
  const configuredFiTypes = Deno.env.get("SETU_AA_FI_TYPES")
    ?.split(",")
    .map((fiType) => fiType.trim().toUpperCase())
    .filter(Boolean);

  if (configuredFiTypes?.length) {
    return Array.from(new Set(configuredFiTypes));
  }

  return DEFAULT_SETU_AA_FI_TYPES;
}

function getConsentContext(): SetuConsentContextItem[] {
  const context: SetuConsentContextItem[] = [];
  const configuredFipIds = Deno.env.get("SETU_AA_CONTEXT_FIP_IDS")?.trim();
  const configuredExcludeFipIds = Deno.env.get("SETU_AA_CONTEXT_EXCLUDE_FIP_IDS")?.trim();
  const configuredAccountSelectionMode = Deno.env.get("SETU_AA_ACCOUNT_SELECTION_MODE")?.trim();

  if (configuredFipIds) {
    context.push({
      key: "fipId",
      value: configuredFipIds,
    });
  }

  if (configuredExcludeFipIds) {
    context.push({
      key: "excludeFipIds",
      value: configuredExcludeFipIds,
    });
  }

  if (configuredAccountSelectionMode) {
    context.push({
      key: "accountSelectionMode",
      value: configuredAccountSelectionMode,
    });
  }

  return context;
}

async function createSetuConsent(
  endpoint: string,
  accessToken: string,
  productInstanceId: string,
  consentPayload: unknown,
) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "x-product-instance-id": productInstanceId,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(consentPayload),
  });

  const responseText = await response.text();

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(responseText);
  } catch {
    console.error("setu_create_consent_non_json", {
      endpoint,
      status: response.status,
      responsePreview: responseText.slice(0, 500),
    });

    throw new Error("Setu returned a non-JSON response");
  }

  return {
    endpoint,
    response,
    payload,
  };
}

async function getSetuAccessToken(): Promise<string> {
  const accountServiceUrl = Deno.env.get("SETU_ACCOUNT_SERVICE_URL") ??
    "https://accountservice.setu.co";

  const clientID = getRequiredEnv("SETU_AA_CLIENT_ID");
  const secret = getRequiredEnv("SETU_AA_CLIENT_SECRET");

  const response = await fetch(`${accountServiceUrl}/v1/users/login`, {
    method: "POST",
    headers: {
      "client": "bridge",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      clientID,
      secret,
      grant_type: "client_credentials",
    }),
  });

  const text = await response.text();

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(text);
  } catch {
    throw new Error(`Setu auth returned non-JSON response: ${text.slice(0, 200)}`);
  }

  const accessToken =
    payload.access_token ??
    payload.accessToken ??
    payload.token;

  if (!response.ok || typeof accessToken !== "string") {
    console.error("setu_auth_failed", {
      status: response.status,
      responsePreview: text.slice(0, 500),
    });

    throw new Error("Could not authenticate with Setu");
  }

  return accessToken;
}

function buildSetuConsentPayload(mobileDigits: string) {
  const supabaseUrl = getRequiredEnv("SUPABASE_URL");

  const redirectUrl =
    Deno.env.get("SETU_AA_REDIRECT_URL") ??
    `${supabaseUrl}/functions/v1/setu-aa-redirect`;

  const consentTypes = DEFAULT_SETU_AA_CONSENT_TYPES;
  const fiTypes = getRequestedFiTypes();
  const context = getConsentContext();

  const payload: Record<string, unknown> = {
    consentDuration: {
      unit: "MONTH",
      value: "1",
    },

    // Setu accepts mobile number or mobile@handle. Configure SETU_AA_VUA_HANDLE
    // when the product instance requires a specific AA sandbox handle.
    vua: buildVua(mobileDigits),

    consentMode: "STORE",
    fetchType: "ONETIME",

    consentTypes,

    fiTypes,

    purpose: {
      code: "102",
      text: "Customer spending patterns, budget or other reportings",
      refUri: "https://api.rebit.org.in/aa/purpose/102.xml",
      category: {
        type: "string",
      },
    },

    dataRange: {
      from: getIsoDateMonthsAgo(6),
      to: new Date().toISOString(),
    },

    dataLife: {
      unit: "MONTH",
      value: 1,
    },

    frequency: {
      unit: "MONTH",
      value: 1,
    },

    redirectUrl,
  };

  if (context.length > 0) {
    payload.context = context;
  }

  return payload;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const accessToken = getBearerToken(req);

    const supabaseUrl = getRequiredEnv("SUPABASE_URL");

    const userClient = createClient(supabaseUrl, getAnonKey(), {
      global: {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Invalid or expired session" }, 401);
    }

    const requestBody = await req.json().catch(() => ({})) as CreateConsentRequest;

    const mobileSource =
      requestBody.mobileNumber ??
      user.phone ??
      DEFAULT_SANDBOX_MOBILE_NUMBER;
    const mobileSourceKind = requestBody.mobileNumber
      ? "request_body"
      : user.phone
      ? "session_phone"
      : "fallback";

    const mobileDigits = normalizeIndianMobileNumber(mobileSource);
    const setuAccessToken = await getSetuAccessToken();

    const productInstanceId = getRequiredEnv("SETU_AA_PRODUCT_INSTANCE_ID");

    const consentPayload = buildSetuConsentPayload(mobileDigits);
    const requestedFiTypes = Array.isArray(consentPayload.fiTypes)
      ? consentPayload.fiTypes
      : [];
    const requestedConsentTypes = Array.isArray(consentPayload.consentTypes)
      ? consentPayload.consentTypes
      : [];
    const consentContext = Array.isArray(consentPayload.context)
      ? consentPayload.context as SetuConsentContextItem[]
      : [];
    const consentContextKeys = consentContext
      .map((item) => item.key)
      .filter(Boolean);

    console.log("setu_create_consent_requesting_scope", {
      requestedFiTypeCount: requestedFiTypes.length,
      requestedConsentTypes,
      hasContext: consentContextKeys.length > 0,
      contextKeys: consentContextKeys,
      mobileSourceKind,
    });

    const primaryEndpoint = getSetuConsentEndpoint();
    let setuResult = await createSetuConsent(
      primaryEndpoint,
      setuAccessToken,
      productInstanceId,
      consentPayload,
    );

    const fallbackEndpoint = getSetuConsentFallbackEndpoint();
    if (!setuResult.response.ok && fallbackEndpoint && fallbackEndpoint !== primaryEndpoint) {
      console.error("setu_create_consent_primary_failed_retrying", {
        endpoint: primaryEndpoint,
        status: setuResult.response.status,
        responsePreview: JSON.stringify(setuResult.payload).slice(0, 500),
      });

      setuResult = await createSetuConsent(
        fallbackEndpoint,
        setuAccessToken,
        productInstanceId,
        consentPayload,
      );
    }

    const setuResponse = setuResult.response;
    const setuPayload = setuResult.payload;

    if (!setuResponse.ok) {
      console.error("setu_create_consent_failed", {
        endpoint: setuResult.endpoint,
        status: setuResponse.status,
        responsePreview: JSON.stringify(setuPayload).slice(0, 500),
        requestedFiTypeCount: requestedFiTypes.length,
        requestedConsentTypes,
        hasContext: consentContextKeys.length > 0,
        contextKeys: consentContextKeys,
      });

      return jsonResponse(
        {
          error: "Setu rejected the Account Aggregator consent request",
          debugMessage: getSetuDebugMessage(setuPayload),
          setuStatus: setuResponse.status,
          traceId: getSetuTraceId(setuPayload),
        },
        502,
      );
    }

    const consentId = setuPayload.id;
    const consentUrl = setuPayload.url;
    const status = setuPayload.status ?? "PENDING";

    if (typeof consentId !== "string" || typeof consentUrl !== "string") {
      console.error("setu_create_consent_missing_fields", {
        responsePreview: JSON.stringify(setuPayload).slice(0, 500),
      });

      return jsonResponse(
        { error: "Setu response did not include consent id or url" },
        502,
      );
    }

    const adminClient = createClient(
      supabaseUrl,
      getServiceRoleKey(),
    );

    const { error: insertError } = await adminClient
      .from("aa_consents")
      .insert({
        user_id: user.id,
        setu_consent_id: consentId,
        setu_consent_url: consentUrl,
        status,
        vua: mobileDigits,
        mobile_number: mobileDigits,
        requested_fi_types: requestedFiTypes,
        requested_consent_types: requestedConsentTypes,
        request_payload: consentPayload,
        response_payload: setuPayload,
      });

    if (insertError) {
      console.error("aa_consent_insert_failed", {
        message: insertError.message,
        code: insertError.code,
      });

      return jsonResponse(
        { error: "Consent was created but could not be saved" },
        500,
      );
    }

    console.log("setu_consent_created", {
      hasUser: true,
      hasConsentId: true,
      status,
      requestedFiTypeCount: requestedFiTypes.length,
      requestedConsentTypes,
      hasContext: consentContextKeys.length > 0,
      contextKeys: consentContextKeys,
    });

    return jsonResponse({
      consentId,
      consentUrl,
      status,
      requestedFiTypeCount: requestedFiTypes.length,
    });
  } catch (error) {
    console.error("setu_aa_create_consent_error", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Unexpected server error",
      },
      500,
    );
  }
});
