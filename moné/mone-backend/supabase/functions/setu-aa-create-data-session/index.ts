import {
  createSupabaseAdminClient,
  createSupabaseUserClient,
  extractDataRange,
  extractRequestedFiTypes,
  extractSetuConsentId,
  extractSetuDataSessionId,
  extractStatus,
  getBearerToken,
  getSetuAccessToken,
  getSetuBaseUrl,
  isConsentReadyStatus,
  isBroadSetuConsent,
  isTerminalSessionStatus,
  JsonObject,
  jsonResponse,
  readJsonResponse,
  setuHeaders,
} from "../_shared/setu-aa.ts";

type CreateDataSessionRequest = {
  consentId?: string;
  allowNarrowConsentForDebug?: boolean;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const userAccessToken = getBearerToken(req);
    const userClient = createSupabaseUserClient(userAccessToken);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Invalid or expired session" }, 401);
    }

    const requestBody = await req.json().catch(() => ({})) as CreateDataSessionRequest;
    const consentId = requestBody.consentId?.trim();
    const allowNarrowConsentForDebug = requestBody.allowNarrowConsentForDebug === true;

    if (!consentId) {
      return jsonResponse({ error: "Missing consentId" }, 400);
    }

    const supabaseAdmin = createSupabaseAdminClient();
    const { data: consent, error: consentError } = await supabaseAdmin
      .from("aa_consents")
      .select(
        "user_id,setu_consent_id,status,last_webhook_status,requested_fi_types,request_payload,response_payload",
      )
      .eq("setu_consent_id", consentId)
      .maybeSingle();

    if (consentError) {
      console.error("setu_create_data_session_consent_lookup_failed", {
        hasConsentId: true,
        message: consentError.message,
      });

      return jsonResponse({ error: "Could not verify consent" }, 500);
    }

    if (!consent || consent.user_id !== user.id) {
      return jsonResponse({ error: "Consent not found" }, 404);
    }

    const consentStatus = consent.last_webhook_status ?? consent.status;

    if (!isConsentReadyStatus(consentStatus)) {
      return jsonResponse(
        { error: "Complete the latest Setu consent before fetching financial data." },
        409,
      );
    }

    if (!allowNarrowConsentForDebug && !isBroadSetuConsent(consent as JsonObject)) {
      console.error("setu_create_data_session_narrow_consent_blocked", {
        hasConsentId: true,
        requestedFiTypeCount: extractRequestedFiTypes(consent as JsonObject).length,
      });

      return jsonResponse(
        {
          error: "Selected consent is narrow. Complete the latest Setu consent before fetching financial data.",
        },
        409,
      );
    }

    const { data: existingSessions, error: existingSessionError } = await supabaseAdmin
      .from("aa_data_sessions")
      .select("setu_data_session_id,status,setu_consent_id")
      .eq("setu_consent_id", consentId)
      .order("created_at", { ascending: false })
      .limit(1);

    if (existingSessionError) {
      console.error("setu_create_data_session_existing_lookup_failed", {
        hasConsentId: true,
        message: existingSessionError.message,
      });
    }

    const existingSession = existingSessions?.[0];
    if (
      existingSession?.setu_data_session_id &&
      !isTerminalSessionStatus(existingSession.status)
    ) {
      return jsonResponse({
        dataSessionId: existingSession.setu_data_session_id,
        status: existingSession.status,
        consentId: existingSession.setu_consent_id,
      });
    }

    const requestPayload = {
      consentId,
      dataRange: extractDataRange(consent as JsonObject),
      format: "json",
    };

    const setuAccessToken = await getSetuAccessToken();
    const endpoint = `${getSetuBaseUrl()}/sessions`;
    const setuResponse = await fetch(endpoint, {
      method: "POST",
      headers: setuHeaders(setuAccessToken),
      body: JSON.stringify(requestPayload),
    });
    const setuPayload = await readJsonResponse(setuResponse);

    if (!setuResponse.ok) {
      console.error("setu_create_data_session_failed", {
        endpoint,
        status: setuResponse.status,
        responsePreview: JSON.stringify(setuPayload).slice(0, 500),
      });

      return jsonResponse(
        { error: "Could not create Account Aggregator data session" },
        502,
      );
    }

    const dataSessionId = extractSetuDataSessionId(setuPayload);
    const responseConsentId = extractSetuConsentId(setuPayload) ?? consentId;
    const status = extractStatus(setuPayload) ?? "CREATED";

    if (!dataSessionId) {
      console.error("setu_create_data_session_missing_id", {
        endpoint,
        status: setuResponse.status,
        responsePreview: JSON.stringify(setuPayload).slice(0, 500),
      });

      return jsonResponse(
        { error: "Setu response did not include a data session id" },
        502,
      );
    }

    const { error: upsertError } = await supabaseAdmin
      .from("aa_data_sessions")
      .upsert({
        user_id: user.id,
        setu_consent_id: responseConsentId,
        setu_data_session_id: dataSessionId,
        status,
        request_payload: requestPayload,
        response_payload: setuPayload,
      }, {
        onConflict: "setu_data_session_id",
      });

    if (upsertError) {
      console.error("setu_create_data_session_upsert_failed", {
        hasConsentId: true,
        hasDataSessionId: true,
        message: upsertError.message,
      });

      return jsonResponse(
        { error: "Data session was created but could not be saved" },
        500,
      );
    }

    console.log("setu_data_session_created", {
      hasConsentId: true,
      hasDataSessionId: true,
      status,
    });

    return jsonResponse({
      dataSessionId,
      status,
      consentId: responseConsentId,
    });
  } catch (error) {
    console.error("setu_create_data_session_unhandled_error", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse({ error: "Unexpected server error" }, 500);
  }
});
