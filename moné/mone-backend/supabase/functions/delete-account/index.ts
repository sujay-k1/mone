import { createClient } from "npm:@supabase/supabase-js@2";

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

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(
      { error: "Method not allowed" },
      405,
    );
  }

  try {
    const authHeader = req.headers.get("Authorization");

    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse(
        { error: "Missing Authorization header" },
        401,
      );
    }

    const accessToken = authHeader.replace("Bearer ", "");

    const supabaseUrl = getRequiredEnv("SUPABASE_URL");
    const anonKey =
      Deno.env.get("SUPABASE_ANON_KEY") ??
      JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}").default;

    if (!anonKey) {
      throw new Error("Missing Supabase anon / publishable key");
    }

    const supabaseUserClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await supabaseUserClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse(
        { error: "Invalid or expired session" },
        401,
      );
    }

    const supabaseAdmin = createClient(
      supabaseUrl,
      getServiceRoleKey(),
    );

    const { error: profileDeleteError } = await supabaseAdmin
      .from("profiles")
      .delete()
      .eq("id", user.id);

    if (profileDeleteError) {
      console.error("delete_account_profile_delete_failed", {
        userId: user.id,
        message: profileDeleteError.message,
      });

      return jsonResponse(
        { error: "Could not delete account" },
        500,
      );
    }

    const { error: deleteError } =
      await supabaseAdmin.auth.admin.deleteUser(user.id);

    if (deleteError) {
      console.error("delete_account_failed", {
        userId: user.id,
        message: deleteError.message,
      });

      return jsonResponse(
        { error: "Could not delete account" },
        500,
      );
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error("delete_account_unhandled_error", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse(
      { error: "Unexpected server error" },
      500,
    );
  }
});
