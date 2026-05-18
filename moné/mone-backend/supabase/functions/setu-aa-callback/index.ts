import {
  createSupabaseAdminClient,
  extractDataRange,
  extractRequestedFiTypes,
  extractSetuConsentId,
  extractSetuDataSessionId,
  extractStatus,
  getSetuAccessToken,
  getSetuBaseUrl,
  isBroadSetuConsent,
  isConsentReadyStatus,
  isDataReadyStatus,
  isTerminalSessionStatus,
  JsonObject,
  jsonResponse,
  readJsonResponse,
  setuHeaders,
  sha256Hex,
  valueAtPath,
  firstStringAtPath,
} from "../_shared/setu-aa.ts";

type SupabaseAdminClient = ReturnType<typeof createSupabaseAdminClient>;

const SENSITIVE_HEADER_NAMES = new Set([
  "authorization",
  "cookie",
  "set-cookie",
  "x-api-key",
  "apikey",
  "x-setu-signature",
  "x-signature",
]);

function extractEventType(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["eventType"],
    ["event_type"],
    ["event"],
    ["type"],
    ["data", "eventType"],
    ["data", "event_type"],
    ["data", "event"],
    ["data", "type"],
  ]);
}

function extractFiType(payload: unknown): string | undefined {
  const directValue = firstStringAtPath(payload, [
    ["fiType"],
    ["fi_type"],
    ["data", "fiType"],
    ["data", "fi_type"],
  ]);

  if (directValue) {
    return directValue;
  }

  const fiTypes = valueAtPath(payload, ["fiTypes"]) ?? valueAtPath(payload, [
    "data",
    "fiTypes",
  ]);

  return Array.isArray(fiTypes) && typeof fiTypes[0] === "string"
    ? fiTypes[0]
    : undefined;
}

function extractFipId(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["fipId"],
    ["fip_id"],
    ["data", "fipId"],
    ["data", "fip_id"],
    ["fip", "id"],
    ["data", "fip", "id"],
  ]);
}

function extractSchemaVersion(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["schemaVersion"],
    ["schema_version"],
    ["data", "schemaVersion"],
    ["data", "schema_version"],
  ]);
}

function extractRawFinancialPayload(payload: unknown): unknown | undefined {
  const paths = [
    ["fiData"],
    ["FIData"],
    ["financialInformation"],
    ["accounts"],
    ["data", "fiData"],
    ["data", "FIData"],
    ["data", "financialInformation"],
    ["data", "accounts"],
    ["data", "fips"],
  ];

  for (const path of paths) {
    const candidate = valueAtPath(payload, path);

    if (candidate !== undefined && candidate !== null) {
      return candidate;
    }
  }

  return undefined;
}

function redactHeaders(headers: Headers): JsonObject {
  const safeHeaders: JsonObject = {};

  headers.forEach((value, key) => {
    const normalizedKey = key.toLowerCase();
    safeHeaders[normalizedKey] = SENSITIVE_HEADER_NAMES.has(normalizedKey)
      ? "[redacted]"
      : value;
  });

  return safeHeaders;
}

function consentStatusPatch(status: string | undefined): JsonObject {
  if (!status) {
    return {};
  }

  const normalized = status.toUpperCase();
  const now = new Date().toISOString();

  if (isConsentReadyStatus(status)) {
    return { approved_at: now };
  }

  if (
    normalized.includes("REJECT") ||
    normalized.includes("DENIED") ||
    normalized.includes("FAILED") ||
    normalized.includes("CANCEL")
  ) {
    return { rejected_at: now };
  }

  if (normalized.includes("REVOK")) {
    return { revoked_at: now };
  }

  return {};
}

async function insertRawArtifact(
  supabaseAdmin: SupabaseAdminClient,
  input: {
    userId: string | null;
    consentId?: string | null;
    dataSessionId?: string | null;
    artifactKind: string;
    payload: unknown;
    sourcePayload?: unknown;
  },
): Promise<string | undefined> {
  const payloadHash = await sha256Hex(input.payload);
  let existingQuery = supabaseAdmin
    .from("financial_data_artifacts")
    .select("id")
    .eq("source", "SETU_AA")
    .eq("artifact_kind", input.artifactKind)
    .eq("payload_hash", payloadHash);

  existingQuery = input.dataSessionId
    ? existingQuery.eq("setu_data_session_id", input.dataSessionId)
    : existingQuery.is("setu_data_session_id", null);

  const { data: existingArtifact, error: existingArtifactError } =
    await existingQuery.maybeSingle();

  if (existingArtifactError) {
    console.error("setu_aa_callback_artifact_lookup_failed", {
      hasDataSessionId: Boolean(input.dataSessionId),
      artifactKind: input.artifactKind,
      message: existingArtifactError.message,
    });
  }

  if (typeof existingArtifact?.id === "string") {
    return existingArtifact.id;
  }

  const { data: artifact, error: artifactInsertError } = await supabaseAdmin
    .from("financial_data_artifacts")
    .insert({
      user_id: input.userId,
      source: "SETU_AA",
      setu_consent_id: input.consentId,
      setu_data_session_id: input.dataSessionId,
      fi_type: extractFiType(input.sourcePayload ?? input.payload),
      fip_id: extractFipId(input.sourcePayload ?? input.payload),
      artifact_kind: input.artifactKind,
      schema_version: extractSchemaVersion(input.sourcePayload ?? input.payload),
      payload: input.payload,
      payload_hash: payloadHash,
      received_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (artifactInsertError) {
    if (artifactInsertError.code === "23505") {
      return undefined;
    }

    console.error("setu_aa_callback_artifact_insert_failed", {
      hasDataSessionId: Boolean(input.dataSessionId),
      artifactKind: input.artifactKind,
      message: artifactInsertError.message,
    });
    return undefined;
  }

  return artifact.id;
}

async function createDataSessionForConsent(
  supabaseAdmin: SupabaseAdminClient,
  consent: JsonObject,
): Promise<{ dataSessionId: string; status: string } | null> {
  const consentId = typeof consent.setu_consent_id === "string"
    ? consent.setu_consent_id
    : undefined;

  if (!consentId) {
    return null;
  }

  if (!isBroadSetuConsent(consent)) {
    console.error("setu_aa_callback_narrow_consent_auto_create_skipped", {
      hasConsentId: true,
      requestedFiTypeCount: extractRequestedFiTypes(consent).length,
    });
    return null;
  }

  const { data: existingSessions, error: existingSessionError } = await supabaseAdmin
    .from("aa_data_sessions")
    .select("setu_data_session_id,status")
    .eq("setu_consent_id", consentId)
    .order("created_at", { ascending: false })
    .limit(1);

  if (existingSessionError) {
    console.error("setu_aa_callback_existing_session_lookup_failed", {
      hasConsentId: true,
      message: existingSessionError.message,
    });
  }

  const existingSession = existingSessions?.[0];
  if (
    existingSession?.setu_data_session_id &&
    !isTerminalSessionStatus(existingSession.status)
  ) {
    return {
      dataSessionId: existingSession.setu_data_session_id,
      status: existingSession.status ?? "CREATED",
    };
  }

  const requestPayload = {
    consentId,
    dataRange: extractDataRange(consent),
    format: "json",
  };

  const endpoint = `${getSetuBaseUrl()}/sessions`;
  const setuAccessToken = await getSetuAccessToken();
  const setuResponse = await fetch(endpoint, {
    method: "POST",
    headers: setuHeaders(setuAccessToken),
    body: JSON.stringify(requestPayload),
  });
  const setuPayload = await readJsonResponse(setuResponse);

  if (!setuResponse.ok) {
    console.error("setu_aa_callback_create_data_session_failed", {
      endpoint,
      status: setuResponse.status,
      responsePreview: JSON.stringify(setuPayload).slice(0, 500),
    });
    return null;
  }

  const dataSessionId = extractSetuDataSessionId(setuPayload);
  const status = extractStatus(setuPayload) ?? "CREATED";

  if (!dataSessionId) {
    console.error("setu_aa_callback_create_data_session_missing_id", {
      endpoint,
      status: setuResponse.status,
      responsePreview: JSON.stringify(setuPayload).slice(0, 500),
    });
    return null;
  }

  const dataSessionRecord: JsonObject = {
    setu_consent_id: consentId,
    setu_data_session_id: dataSessionId,
    status,
    request_payload: requestPayload,
    response_payload: setuPayload,
  };

  if (typeof consent.user_id === "string") {
    dataSessionRecord.user_id = consent.user_id;
  }

  const { error: upsertError } = await supabaseAdmin
    .from("aa_data_sessions")
    .upsert(dataSessionRecord, {
      onConflict: "setu_data_session_id",
    });

  if (upsertError) {
    console.error("setu_aa_callback_create_data_session_upsert_failed", {
      hasConsentId: true,
      hasDataSessionId: true,
      message: upsertError.message,
    });
    return null;
  }

  return { dataSessionId, status };
}

async function fetchFiDataForSession(
  supabaseAdmin: SupabaseAdminClient,
  input: {
    userId: string | null;
    consentId?: string | null;
    dataSessionId: string;
  },
): Promise<void> {
  if (input.consentId) {
    const { data: consent, error: consentError } = await supabaseAdmin
      .from("aa_consents")
      .select("setu_consent_id,requested_fi_types,request_payload")
      .eq("setu_consent_id", input.consentId)
      .maybeSingle();

    if (consentError) {
      console.error("setu_aa_callback_fetch_consent_lookup_failed", {
        hasConsentId: true,
        hasDataSessionId: true,
        message: consentError.message,
      });
      return;
    }

    if (consent && !isBroadSetuConsent(consent as JsonObject)) {
      console.error("setu_aa_callback_narrow_consent_fetch_skipped", {
        hasConsentId: true,
        hasDataSessionId: true,
        requestedFiTypeCount: extractRequestedFiTypes(consent as JsonObject).length,
      });
      return;
    }
  }

  const endpoint = `${getSetuBaseUrl()}/sessions/${encodeURIComponent(input.dataSessionId)}`;
  const setuAccessToken = await getSetuAccessToken();
  const setuResponse = await fetch(endpoint, {
    method: "GET",
    headers: setuHeaders(setuAccessToken),
  });
  const setuPayload = await readJsonResponse(setuResponse);

  if (!setuResponse.ok) {
    console.error("setu_aa_callback_fetch_fi_failed", {
      endpoint,
      status: setuResponse.status,
      responsePreview: JSON.stringify(setuPayload).slice(0, 500),
    });

    await supabaseAdmin
      .from("aa_data_sessions")
      .update({ error_payload: setuPayload })
      .eq("setu_data_session_id", input.dataSessionId);
    return;
  }

  const status = extractStatus(setuPayload) ?? "FETCHED";

  await supabaseAdmin
    .from("aa_data_sessions")
    .update({
      status,
      response_payload: setuPayload,
    })
    .eq("setu_data_session_id", input.dataSessionId);

  await insertRawArtifact(supabaseAdmin, {
    userId: input.userId,
    consentId: input.consentId,
    dataSessionId: input.dataSessionId,
    artifactKind: "FI_DATA_FETCH_RESPONSE",
    payload: setuPayload,
    sourcePayload: setuPayload,
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let payload: unknown;

  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON payload" }, 400);
  }

  let consentId = extractSetuConsentId(payload);
  const dataSessionId = extractSetuDataSessionId(payload);
  const eventType = extractEventType(payload) ?? "setu_callback";
  const status = extractStatus(payload);
  const statusSignal = status ?? eventType;
  const rawFinancialPayload = extractRawFinancialPayload(payload);

  try {
    const supabaseAdmin = createSupabaseAdminClient();

    let userId: string | null = null;
    let consent: JsonObject | null = null;

    if (consentId) {
      const { data: consentRow, error: consentLookupError } = await supabaseAdmin
        .from("aa_consents")
        .select(
          "user_id,setu_consent_id,status,last_webhook_status,request_payload,response_payload",
        )
        .eq("setu_consent_id", consentId)
        .maybeSingle();

      if (consentLookupError) {
        console.error("setu_aa_callback_consent_lookup_failed", {
          hasConsentId: true,
          message: consentLookupError.message,
        });
      } else if (consentRow) {
        consent = consentRow as JsonObject;
        userId = typeof consentRow.user_id === "string" ? consentRow.user_id : null;
      }
    }

    if (!userId && dataSessionId) {
      const { data: sessionRow, error: sessionLookupError } = await supabaseAdmin
        .from("aa_data_sessions")
        .select("user_id,setu_consent_id,setu_data_session_id,status")
        .eq("setu_data_session_id", dataSessionId)
        .maybeSingle();

      if (sessionLookupError) {
        console.error("setu_aa_callback_session_lookup_failed", {
          hasDataSessionId: true,
          message: sessionLookupError.message,
        });
      } else if (sessionRow) {
        userId = typeof sessionRow.user_id === "string" ? sessionRow.user_id : null;
        if (!consentId && typeof sessionRow.setu_consent_id === "string") {
          consentId = sessionRow.setu_consent_id;
        }
      }
    }

    const { error: webhookInsertError } = await supabaseAdmin
      .from("aa_webhook_events")
      .insert({
        user_id: userId,
        setu_consent_id: consentId,
        setu_data_session_id: dataSessionId,
        event_type: eventType,
        status,
        payload,
        headers: redactHeaders(req.headers),
        received_at: new Date().toISOString(),
      });

    if (webhookInsertError) {
      console.error("setu_aa_callback_webhook_insert_failed", {
        eventType,
        status,
        hasConsentId: Boolean(consentId),
        hasDataSessionId: Boolean(dataSessionId),
        message: webhookInsertError.message,
      });

      return jsonResponse({ error: "Could not store webhook event" }, 500);
    }

    if (consentId) {
      const { error: consentUpdateError } = await supabaseAdmin
        .from("aa_consents")
        .update({
          last_webhook_status: statusSignal,
          status: statusSignal,
          ...consentStatusPatch(statusSignal),
        })
        .eq("setu_consent_id", consentId);

      if (consentUpdateError) {
        console.error("setu_aa_callback_consent_update_failed", {
          eventType,
          status,
          hasConsentId: true,
          message: consentUpdateError.message,
        });
      }
    }

    if (dataSessionId) {
      const dataSessionRecord: JsonObject = {
        setu_data_session_id: dataSessionId,
        status: statusSignal,
        response_payload: payload,
      };

      if (consentId) {
        dataSessionRecord.setu_consent_id = consentId;
      }

      if (userId) {
        dataSessionRecord.user_id = userId;
      }

      const { error: dataSessionError } = await supabaseAdmin
        .from("aa_data_sessions")
        .upsert(dataSessionRecord, {
          onConflict: "setu_data_session_id",
        });

      if (dataSessionError) {
        console.error("setu_aa_callback_data_session_upsert_failed", {
          eventType,
          status,
          hasConsentId: Boolean(consentId),
          hasDataSessionId: true,
          message: dataSessionError.message,
        });
      }
    }

    if (rawFinancialPayload !== undefined) {
      await insertRawArtifact(supabaseAdmin, {
        userId,
        consentId,
        dataSessionId,
        artifactKind: "SETU_AA_WEBHOOK_FI_DATA",
        payload: rawFinancialPayload,
        sourcePayload: payload,
      });
    } else if (dataSessionId && isDataReadyStatus(statusSignal)) {
      await fetchFiDataForSession(supabaseAdmin, {
        userId,
        consentId,
        dataSessionId,
      });
    } else if (consent && isConsentReadyStatus(statusSignal)) {
      const createdSession = await createDataSessionForConsent(supabaseAdmin, consent);

      if (createdSession && isDataReadyStatus(createdSession.status)) {
        await fetchFiDataForSession(supabaseAdmin, {
          userId,
          consentId,
          dataSessionId: createdSession.dataSessionId,
        });
      }
    }

    console.log("setu_aa_callback_stored", {
      eventType,
      status,
      hasConsentId: Boolean(consentId),
      hasDataSessionId: Boolean(dataSessionId),
      hasRawFinancialPayload: rawFinancialPayload !== undefined,
    });

    return jsonResponse({ received: true }, 200);
  } catch (error) {
    console.error("setu_aa_callback_unhandled_error", {
      eventType,
      status,
      hasConsentId: Boolean(consentId),
      hasDataSessionId: Boolean(dataSessionId),
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse({ error: "Could not process callback" }, 500);
  }
});
