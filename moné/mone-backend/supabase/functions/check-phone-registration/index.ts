import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RequestBody = {
  phone?: string | null;
  email?: string | null;
  identifier?: string | null;
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

    const rawIdentifier = body.identifier ?? body.phone ?? body.email ?? "";
    const email = normalizeEmail(body.email ?? rawIdentifier);
    const phone = normalizePhone(body.phone ?? rawIdentifier);

    const isEmailLookup = email.includes("@");
    const isPhoneLookup = phone.length === 10 && !isEmailLookup;

    if (!isEmailLookup && !isPhoneLookup) {
      return jsonResponse(
        {
          registered: false,
          reason: "invalid_identifier",
        },
        400,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");

    // Support both names because your existing repo uses SERVICE_ROLE_KEY,
    // while many Supabase projects use SUPABASE_SERVICE_ROLE_KEY.
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        {
          error: "Missing Supabase environment variables",
          hasSupabaseUrl: Boolean(supabaseUrl),
          hasServiceRoleKey: Boolean(serviceRoleKey),
        },
        500,
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const query = supabase
      .from("profiles")
      .select("id, phone, email, onboarding_completed");

    const { data, error } = isEmailLookup
      ? await query.eq("email", email).maybeSingle()
      : await query.eq("phone", phone).maybeSingle();

    if (error) {
      return jsonResponse(
        {
          error: "Profile lookup failed",
          details: error.message,
        },
        500,
      );
    }

    if (!data) {
      return jsonResponse(
        {
          registered: false,
          lookupType: isEmailLookup ? "email" : "phone",
          phone: isPhoneLookup ? phone : null,
          email: isEmailLookup ? email : null,
        },
        200,
      );
    }

    return jsonResponse(
      {
        registered: true,
        lookupType: isEmailLookup ? "email" : "phone",
        phone: data.phone ?? null,
        email: data.email ?? null,
        onboardingCompleted: data.onboarding_completed === true,
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

function normalizePhone(value: string): string {
  return value.replace(/\D/g, "").slice(-10);
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
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