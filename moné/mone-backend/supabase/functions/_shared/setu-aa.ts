import { createClient } from "npm:@supabase/supabase-js@2";

export type JsonObject = Record<string, unknown>;

export type NormalizedSetuFipStatus = {
  name: string | null;
  fipId: string;
  fiTypes: string[];
  institutionType: string | null;
  status: string | null;
  consentConversionRate: number | null;
  dataFetchSuccessRate: number | null;
  aaWiseSuccessRate?: unknown;
};

export type SetuFipStatusResult = {
  traceId: string | null;
  fips: NormalizedSetuFipStatus[];
};

export const BROAD_SETU_AA_FI_TYPES = [
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

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

export function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name);

  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }

  return value;
}

export function getAnonKey(): string {
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

export function getServiceRoleKey(): string {
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

export function getBearerToken(req: Request): string {
  const authHeader = req.headers.get("Authorization");

  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing Authorization bearer token");
  }

  return authHeader.replace("Bearer ", "");
}

export function createSupabaseAdminClient() {
  return createClient(
    getRequiredEnv("SUPABASE_URL"),
    getServiceRoleKey(),
  );
}

export function createSupabaseUserClient(accessToken: string) {
  return createClient(getRequiredEnv("SUPABASE_URL"), getAnonKey(), {
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
}

export function getSetuBaseUrl(): string {
  return getRequiredEnv("SETU_AA_BASE_URL").replace(/\/+$/, "");
}

export function getProductInstanceId(): string {
  return getRequiredEnv("SETU_AA_PRODUCT_INSTANCE_ID");
}

export function setuHeaders(accessToken: string): HeadersInit {
  return {
    "Authorization": `Bearer ${accessToken}`,
    "x-product-instance-id": getProductInstanceId(),
    "Content-Type": "application/json",
  };
}

export async function fetchSetuFipStatuses(options: {
  accessToken: string;
  fipIds?: string[];
  expanded?: boolean;
}): Promise<NormalizedSetuFipStatus[]> {
  const result = await fetchSetuFipStatusResult(options);
  return result.fips;
}

export async function fetchSetuFipStatusResult(options: {
  accessToken: string;
  fipIds?: string[];
  expanded?: boolean;
}): Promise<SetuFipStatusResult> {
  const fipIds = options.fipIds?.map((id) => id.trim()).filter(Boolean) ?? [];

  if (fipIds.length > 0) {
    const results = await Promise.all(
      fipIds.map((fipId) => fetchSingleSetuFipStatus(options.accessToken, fipId, options.expanded)),
    );

    return {
      traceId: results.find((result) => result.traceId)?.traceId ?? null,
      fips: results.map((result) => result.fip),
    };
  }

  return await fetchAllSetuFipStatuses(options.accessToken, options.expanded);
}

async function fetchAllSetuFipStatuses(
  accessToken: string,
  expanded = false,
): Promise<SetuFipStatusResult> {
  const endpoint = `${getSetuV2BaseUrl()}/fips${expanded ? "?expanded=true" : ""}`;
  const response = await fetch(endpoint, {
    method: "GET",
    headers: setuHeaders(accessToken),
  });
  const text = await response.text();
  const payload = parseJsonValue(text);

  if (!response.ok) {
    console.error("setu_fip_status_list_failed", {
      status: response.status,
      responsePreview: text.slice(0, 300),
    });
    throw new Error("Could not load Setu FIP status");
  }

  return {
    traceId: firstStringAtPath(payload, [["traceId"], ["trace_id"]]) ?? null,
    fips: extractFipList(payload)
      .map((fip) => normalizeSetuFipStatus(fip))
      .filter((fip): fip is NormalizedSetuFipStatus => Boolean(fip)),
  };
}

async function fetchSingleSetuFipStatus(
  accessToken: string,
  fipId: string,
  expanded = false,
): Promise<{ traceId: string | null; fip: NormalizedSetuFipStatus }> {
  const endpoint = `${getSetuV2BaseUrl()}/fips/${encodeURIComponent(fipId)}${expanded ? "?expanded=true" : ""}`;
  const response = await fetch(endpoint, {
    method: "GET",
    headers: setuHeaders(accessToken),
  });
  const text = await response.text();
  const payload = parseJsonValue(text);

  if (!response.ok) {
    console.error("setu_fip_status_lookup_failed", {
      hasFipId: true,
      status: response.status,
      responsePreview: text.slice(0, 300),
    });
    return {
      traceId: firstStringAtPath(payload, [["traceId"], ["trace_id"]]) ?? null,
      fip: {
        fipId,
        status: `HTTP_${response.status}`,
        name: "Not found",
        fiTypes: [],
        institutionType: null,
        consentConversionRate: null,
        dataFetchSuccessRate: null,
        aaWiseSuccessRate: [],
      },
    };
  }

  const matchingFip = extractFipList(payload)
    .find((fip) => fipIdMatches(fip, fipId));
  const normalized = matchingFip ? normalizeSetuFipStatus(matchingFip) : undefined;

  return {
    traceId: firstStringAtPath(payload, [["traceId"], ["trace_id"]]) ?? null,
    fip: normalized ?? {
      fipId,
      name: "Not found",
      status: "NOT_FOUND",
      fiTypes: [],
      institutionType: null,
      consentConversionRate: null,
      dataFetchSuccessRate: null,
      aaWiseSuccessRate: [],
    },
  };
}

function getSetuV2BaseUrl(): string {
  const baseUrl = getSetuBaseUrl();
  return baseUrl.endsWith("/v2") ? baseUrl : `${baseUrl}/v2`;
}

function parseJsonValue(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function extractFipList(payload: unknown): JsonObject[] {
  const candidates = [
    payload,
    valueAtPath(payload, ["fips"]),
    valueAtPath(payload, ["data"]),
    valueAtPath(payload, ["data", "fips"]),
    valueAtPath(payload, ["payload", "fips"]),
  ];

  for (const candidate of candidates) {
    if (Array.isArray(candidate)) {
      return candidate.filter(isJsonObject);
    }
  }

  return [];
}

function normalizeSetuFipStatus(fip: JsonObject): NormalizedSetuFipStatus | undefined {
  const fipId = firstStringAtPath(fip, [["fipId"], ["fipID"], ["id"], ["identifier"]]);

  if (!fipId) {
    return undefined;
  }

  return {
    name: firstStringAtPath(fip, [["name"], ["fipName"], ["institutionName"]]) ?? null,
    fipId,
    fiTypes: stringArrayAtAnyPath(fip, [
      ["fiTypes"],
      ["fi_types"],
      ["supportedFiTypes"],
      ["supportedFITypes"],
    ]),
    institutionType: firstStringAtPath(fip, [["institutionType"], ["institution_type"], ["type"]]) ?? null,
    status: firstStringAtPath(fip, [["status"], ["health"], ["availabilityStatus"]]) ?? null,
    consentConversionRate: numberAtAnyPath(fip, [
      ["consentConversionRate"],
      ["consent_conversion_rate"],
      ["metrics", "consentConversionRate"],
    ]) ?? null,
    dataFetchSuccessRate: numberAtAnyPath(fip, [
      ["dataFetchSuccessRate"],
      ["data_fetch_success_rate"],
      ["metrics", "dataFetchSuccessRate"],
    ]) ?? null,
    aaWiseSuccessRate: valueAtPath(fip, ["aaWiseSuccessRate"]) ??
      valueAtPath(fip, ["aa_wise_success_rate"]) ??
      valueAtPath(fip, ["metrics", "aaWiseSuccessRate"]) ??
      [],
  };
}

function fipIdMatches(fip: JsonObject, requestedFipId: string): boolean {
  const fipId = firstStringAtPath(fip, [["fipId"], ["fipID"], ["id"], ["identifier"]]);
  return fipId === requestedFipId;
}

function stringArrayAtAnyPath(value: unknown, paths: string[][]): string[] {
  for (const path of paths) {
    const candidate = valueAtPath(value, path);

    if (Array.isArray(candidate)) {
      return candidate
        .filter((item): item is string => typeof item === "string" && item.trim().length > 0)
        .map((item) => item.trim());
    }
  }

  return [];
}

function numberAtAnyPath(value: unknown, paths: string[][]): number | undefined {
  for (const path of paths) {
    const candidate = valueAtPath(value, path);

    if (typeof candidate === "number") {
      return candidate;
    }

    if (typeof candidate === "string") {
      const parsed = Number(candidate);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }

  return undefined;
}

function isJsonObject(value: unknown): value is JsonObject {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export async function getSetuAccessToken(): Promise<string> {
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
  const payload = parseJsonObject(text);
  const accessToken =
    payload.access_token ??
    payload.accessToken ??
    payload.token;

  if (!response.ok || typeof accessToken !== "string") {
    console.error("setu_auth_failed", {
      status: response.status,
      responsePreview: text.slice(0, 300),
    });

    throw new Error("Could not authenticate with Setu");
  }

  return accessToken;
}

export function parseJsonObject(text: string): JsonObject {
  try {
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as JsonObject
      : {};
  } catch {
    return {};
  }
}

export async function readJsonResponse(response: Response): Promise<JsonObject> {
  const text = await response.text();
  return parseJsonObject(text);
}

export function valueAtPath(value: unknown, path: string[]): unknown {
  let current = value;

  for (const key of path) {
    if (!current || typeof current !== "object" || Array.isArray(current)) {
      return undefined;
    }

    const object = current as JsonObject;

    if (!(key in object)) {
      return undefined;
    }

    current = object[key];
  }

  return current;
}

export function stringAtPath(value: unknown, path: string[]): string | undefined {
  const candidate = valueAtPath(value, path);

  if (typeof candidate === "string" && candidate.trim()) {
    return candidate.trim();
  }

  if (typeof candidate === "number" || typeof candidate === "boolean") {
    return String(candidate);
  }

  return undefined;
}

export function firstStringAtPath(
  value: unknown,
  paths: string[][],
): string | undefined {
  for (const path of paths) {
    const candidate = stringAtPath(value, path);

    if (candidate) {
      return candidate;
    }
  }

  return undefined;
}

export function extractSetuDataSessionId(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["id"],
    ["dataSessionId"],
    ["data_session_id"],
    ["sessionId"],
    ["data", "id"],
    ["data", "dataSessionId"],
    ["data", "data_session_id"],
    ["data", "sessionId"],
    ["dataSession", "id"],
    ["data_session", "id"],
  ]);
}

export function extractSetuConsentId(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["consentId"],
    ["consent_id"],
    ["ConsentId"],
    ["data", "consentId"],
    ["data", "consent_id"],
    ["data", "ConsentId"],
    ["consent", "id"],
    ["consent", "consentId"],
    ["Consent", "id"],
  ]);
}

export function extractStatus(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["status"],
    ["consentStatus"],
    ["dataSessionStatus"],
    ["data", "status"],
    ["data", "consentStatus"],
    ["data", "dataSessionStatus"],
    ["consent", "status"],
    ["dataSession", "status"],
  ]);
}

export function isConsentReadyStatus(status: string | null | undefined): boolean {
  if (!status) {
    return false;
  }

  const normalized = status.toUpperCase();
  return normalized.includes("APPROVED") ||
    normalized.includes("ACTIVE") ||
    normalized.includes("READY") ||
    normalized.includes("GRANTED") ||
    normalized.includes("SUCCESS");
}

export function isDataReadyStatus(status: string | null | undefined): boolean {
  if (!status) {
    return false;
  }

  const normalized = status.toUpperCase();
  return normalized.includes("PARTIAL") ||
    normalized.includes("COMPLETED") ||
    normalized.includes("READY");
}

export function isTerminalSessionStatus(status: string | null | undefined): boolean {
  if (!status) {
    return false;
  }

  const normalized = status.toUpperCase();
  return normalized.includes("COMPLETED") ||
    normalized.includes("FAILED") ||
    normalized.includes("EXPIRED") ||
    normalized.includes("REJECT") ||
    normalized.includes("CANCEL");
}

export function extractRequestedFiTypes(consent: JsonObject): string[] {
  const requestedFiTypes = consent.requested_fi_types;
  const requestPayloadFiTypes = valueAtPath(consent.request_payload, ["fiTypes"]);

  const source = Array.isArray(requestedFiTypes)
    ? requestedFiTypes
    : Array.isArray(requestPayloadFiTypes)
    ? requestPayloadFiTypes
    : [];

  return source
    .filter((value): value is string => typeof value === "string")
    .map((value) => value.trim().toUpperCase())
    .filter(Boolean);
}

export function isBroadSetuConsent(consent: JsonObject): boolean {
  const requestedFiTypes = new Set(extractRequestedFiTypes(consent));
  return BROAD_SETU_AA_FI_TYPES.every((fiType) => requestedFiTypes.has(fiType));
}

export function extractDataRange(consent: JsonObject): JsonObject {
  const requestPayload = consent.request_payload;
  const responsePayload = consent.response_payload;
  const rangeFromRequest = valueAtPath(requestPayload, ["dataRange"]);
  const rangeFromResponse = valueAtPath(responsePayload, ["dataRange"]);

  if (isValidDataRange(rangeFromRequest)) {
    return rangeFromRequest;
  }

  if (isValidDataRange(rangeFromResponse)) {
    return rangeFromResponse;
  }

  const to = new Date();
  const from = new Date();
  from.setMonth(from.getMonth() - 1);

  return {
    from: from.toISOString(),
    to: to.toISOString(),
  };
}

function isValidDataRange(value: unknown): value is JsonObject {
  return Boolean(
    value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      typeof (value as JsonObject).from === "string" &&
      typeof (value as JsonObject).to === "string",
  );
}

export async function sha256Hex(value: unknown): Promise<string> {
  const encoded = new TextEncoder().encode(JSON.stringify(value));
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function countFips(payload: unknown): number {
  const fips = valueAtPath(payload, ["fips"]) ?? valueAtPath(payload, ["data", "fips"]);
  return Array.isArray(fips) ? fips.length : 0;
}

export function countAccounts(payload: unknown): number {
  const directAccounts = valueAtPath(payload, ["accounts"]) ??
    valueAtPath(payload, ["data", "accounts"]);

  if (Array.isArray(directAccounts)) {
    return directAccounts.length;
  }

  const fips = valueAtPath(payload, ["fips"]) ?? valueAtPath(payload, ["data", "fips"]);

  if (!Array.isArray(fips)) {
    return 0;
  }

  return fips.reduce((count, fip) => {
    const accounts = valueAtPath(fip, ["accounts"]) ??
      valueAtPath(fip, ["Accounts"]) ??
      valueAtPath(fip, ["data", "accounts"]);
    return count + (Array.isArray(accounts) ? accounts.length : 0);
  }, 0);
}
