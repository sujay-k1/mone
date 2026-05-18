import {
  createSupabaseUserClient,
  fetchSetuFipStatusResult,
  getBearerToken,
  getSetuAccessToken,
  jsonResponse,
} from "../_shared/setu-aa.ts";

type FipStatusRequest = {
  fipIds?: string[];
  expanded?: boolean;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const accessToken = getBearerToken(req);
    const userClient = createSupabaseUserClient(accessToken);
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Invalid or expired session" }, 401);
    }

    const requestBody = await req.json().catch(() => ({})) as FipStatusRequest;
    const fipIds = Array.isArray(requestBody.fipIds)
      ? requestBody.fipIds
        .filter((value): value is string => typeof value === "string")
        .map((value) => value.trim())
        .filter(Boolean)
      : undefined;
    const expanded = requestBody.expanded === true;

    const setuAccessToken = await getSetuAccessToken();
    const result = await fetchSetuFipStatusResult({
      accessToken: setuAccessToken,
      fipIds,
      expanded,
    });

    console.log("setu_fip_status_completed", {
      hasUser: true,
      requestedFipCount: fipIds?.length ?? 0,
      returnedFipCount: result.fips.length,
      expanded,
    });

    return jsonResponse({
      traceId: result.traceId,
      fips: result.fips,
      count: result.fips.length,
    });
  } catch (error) {
    console.error("setu_fip_status_error", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse(
      { error: "Could not load Setu FIP status" },
      500,
    );
  }
});
