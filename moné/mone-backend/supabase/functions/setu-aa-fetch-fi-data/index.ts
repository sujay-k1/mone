import {
  countAccounts,
  countFips,
  createSupabaseAdminClient,
  createSupabaseUserClient,
  extractRequestedFiTypes,
  extractStatus,
  firstStringAtPath,
  getBearerToken,
  getSetuAccessToken,
  getSetuBaseUrl,
  isBroadSetuConsent,
  JsonObject,
  jsonResponse,
  readJsonResponse,
  setuHeaders,
  sha256Hex,
} from "../_shared/setu-aa.ts";

type FetchFiDataRequest = {
  dataSessionId?: string;
  allowNarrowConsentForDebug?: boolean;
};

function extractSchemaVersion(payload: unknown): string | undefined {
  return firstStringAtPath(payload, [
    ["schemaVersion"],
    ["schema_version"],
    ["data", "schemaVersion"],
    ["data", "schema_version"],
  ]);
}

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

    const requestBody = await req.json().catch(() => ({})) as FetchFiDataRequest;
    const dataSessionId = requestBody.dataSessionId?.trim();
    const allowNarrowConsentForDebug = requestBody.allowNarrowConsentForDebug === true;

    if (!dataSessionId) {
      return jsonResponse({ error: "Missing dataSessionId" }, 400);
    }

    const supabaseAdmin = createSupabaseAdminClient();
    const { data: dataSession, error: dataSessionError } = await supabaseAdmin
      .from("aa_data_sessions")
      .select("user_id,setu_consent_id,setu_data_session_id,status")
      .eq("setu_data_session_id", dataSessionId)
      .maybeSingle();

    if (dataSessionError) {
      console.error("setu_fetch_fi_data_session_lookup_failed", {
        hasDataSessionId: true,
        message: dataSessionError.message,
      });

      return jsonResponse({ error: "Could not verify data session" }, 500);
    }

    if (!dataSession || dataSession.user_id !== user.id) {
      return jsonResponse({ error: "Data session not found" }, 404);
    }

    if (dataSession.setu_consent_id) {
      const { data: consent, error: consentError } = await supabaseAdmin
        .from("aa_consents")
        .select("user_id,setu_consent_id,requested_fi_types,request_payload")
        .eq("setu_consent_id", dataSession.setu_consent_id)
        .maybeSingle();

      if (consentError) {
        console.error("setu_fetch_fi_consent_lookup_failed", {
          hasDataSessionId: true,
          hasConsentId: true,
          message: consentError.message,
        });

        return jsonResponse({ error: "Could not verify consent scope" }, 500);
      }

      if (!allowNarrowConsentForDebug && consent && !isBroadSetuConsent(consent as JsonObject)) {
        console.error("setu_fetch_fi_narrow_consent_blocked", {
          hasDataSessionId: true,
          hasConsentId: true,
          requestedFiTypeCount: extractRequestedFiTypes(consent as JsonObject).length,
        });

        return jsonResponse(
          {
            error: "Selected data session belongs to a narrow consent. Complete the latest Setu consent before fetching financial data.",
          },
          409,
        );
      }
    } else if (!allowNarrowConsentForDebug) {
      return jsonResponse(
        {
          error: "Data session is missing consent metadata. Complete the latest Setu consent before fetching financial data.",
        },
        409,
      );
    }

    const setuAccessToken = await getSetuAccessToken();
    const endpoint = `${getSetuBaseUrl()}/sessions/${encodeURIComponent(dataSessionId)}`;
    const setuResponse = await fetch(endpoint, {
      method: "GET",
      headers: setuHeaders(setuAccessToken),
    });
    const setuPayload = await readJsonResponse(setuResponse);

    if (!setuResponse.ok) {
      console.error("setu_fetch_fi_data_failed", {
        endpoint,
        status: setuResponse.status,
        responsePreview: JSON.stringify(setuPayload).slice(0, 500),
      });

      await supabaseAdmin
        .from("aa_data_sessions")
        .update({
          error_payload: setuPayload,
        })
        .eq("setu_data_session_id", dataSessionId);

      return jsonResponse({ error: "Could not fetch financial data" }, 502);
    }

    const status = extractStatus(setuPayload) ?? dataSession.status;
    const payloadHash = await sha256Hex(setuPayload);

    await supabaseAdmin
      .from("aa_data_sessions")
      .update({
        status,
        response_payload: setuPayload,
      })
      .eq("setu_data_session_id", dataSessionId);

    const { data: existingArtifact, error: existingArtifactError } = await supabaseAdmin
      .from("financial_data_artifacts")
      .select("id")
      .eq("source", "SETU_AA")
      .eq("setu_data_session_id", dataSessionId)
      .eq("artifact_kind", "FI_DATA_FETCH_RESPONSE")
      .eq("payload_hash", payloadHash)
      .maybeSingle();

    if (existingArtifactError) {
      console.error("setu_fetch_fi_existing_artifact_lookup_failed", {
        hasDataSessionId: true,
        message: existingArtifactError.message,
      });
    }

    let artifactId = existingArtifact?.id as string | undefined;

    if (!artifactId) {
      const { data: artifact, error: artifactError } = await supabaseAdmin
        .from("financial_data_artifacts")
        .insert({
          user_id: user.id,
          source: "SETU_AA",
          setu_consent_id: dataSession.setu_consent_id,
          setu_data_session_id: dataSessionId,
          artifact_kind: "FI_DATA_FETCH_RESPONSE",
          schema_version: extractSchemaVersion(setuPayload),
          payload: setuPayload,
          payload_hash: payloadHash,
          received_at: new Date().toISOString(),
        })
        .select("id")
        .single();

      if (artifactError) {
        console.error("setu_fetch_fi_artifact_insert_failed", {
          hasDataSessionId: true,
          message: artifactError.message,
        });

        return jsonResponse({ error: "Financial data was fetched but could not be saved" }, 500);
      }

      artifactId = artifact.id;
    }

    console.log("setu_fi_data_fetched", {
      hasDataSessionId: true,
      status,
      fipCount: countFips(setuPayload),
      accountCount: countAccounts(setuPayload),
      reusedArtifact: Boolean(existingArtifact?.id),
    });

    return jsonResponse({
      dataSessionId,
      status,
      artifactId,
      fipCount: countFips(setuPayload),
      accountCount: countAccounts(setuPayload),
    });
  } catch (error) {
    console.error("setu_fetch_fi_data_unhandled_error", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse({ error: "Unexpected server error" }, 500);
  }
});
