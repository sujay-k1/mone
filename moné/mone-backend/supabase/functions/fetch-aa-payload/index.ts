import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RequestBody = {
  mobile: string;
  pan?: string | null;
  consentId?: string | null;
};

const MOBILE_TO_FIXTURE: Record<string, { personaId: string; filePath: string }> = {
  "8828290489": {
    personaId: "aarav",
    filePath: "raw_payload_aarav.json",
  },
  "7304893952": {
    personaId: "priya",
    filePath: "raw_payload_priya.json",
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return jsonResponse({ ok: true }, 200);
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body = (await req.json()) as RequestBody;

    const mobile = normalizeMobile(body.mobile);
    const fixture = MOBILE_TO_FIXTURE[mobile];

    if (!fixture) {
      return jsonResponse(
        {
          error: "No synthetic AA fixture mapped for this mobile number",
          mobile,
        },
        404,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        {
          error: "Missing Supabase environment variables",
        },
        500,
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data, error } = await supabase.storage
      .from("aa-fixtures")
      .download(fixture.filePath);

    if (error || !data) {
      return jsonResponse(
        {
          error: "Could not download fixture",
          details: error?.message,
        },
        500,
      );
    }

    const payloadText = await data.text();
    const payload = JSON.parse(payloadText);

    return jsonResponse(
      {
        personaId: fixture.personaId,
        source: "mock_account_aggregator",
        consentId: body.consentId ?? null,
        fetchedAt: new Date().toISOString(),
        payload,
      },
      200,
    );
  } catch (error) {
    return jsonResponse(
      {
        error: "Unexpected error",
        details: String(error),
      },
      500,
    );
  }
});

function normalizeMobile(value: string): string {
  return value.replace(/\D/g, "").slice(-10);
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}