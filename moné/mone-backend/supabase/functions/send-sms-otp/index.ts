import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

type SendSmsHookPayload = {
  user?: {
    id?: string;
    phone?: string;
  };
  sms?: {
    otp?: string;
  };
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

function normalizeIndianPhoneNumber(phone: string): string {
  // Supabase should send E.164 format, for example +919876543210.
  // 2Factor endpoint commonly expects digits only, for example 919876543210.
  const digits = phone.replace(/\D/g, "");

  if (!digits.startsWith("91") || digits.length !== 12) {
    throw new Error("Invalid Indian phone number. Expected format: +91XXXXXXXXXX");
  }

  return digits;
}

async function sendOtpWith2Factor(phoneDigits: string, otp: string) {
  const apiKey = getRequiredEnv("TWOFACTOR_API_KEY");

  // Simpler 2Factor SMS OTP endpoint:
  // https://2factor.in/API/V1/{apiKey}/SMS/{phone}/{otp}
  const url =
    `https://2factor.in/API/V1/${encodeURIComponent(apiKey)}` +
    `/SMS/${encodeURIComponent(phoneDigits)}` +
    `/${encodeURIComponent(otp)}`;

  const response = await fetch(url, {
    method: "POST",
  });

  const responseText = await response.text();

  console.log("twofactor_response", {
    status: response.status,
    ok: response.ok,
    responsePreview: responseText.slice(0, 300),
  });

  if (!response.ok || !responseText.toLowerCase().includes("success")) {
    console.error("2Factor SMS send failed", {
      status: response.status,
      responseText,
      phoneEnding: phoneDigits.slice(-4),
    });

    throw new Error("SMS provider failed to send OTP");
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(
      {
        error: {
          http_code: 405,
          message: "Method not allowed",
        },
      },
      405,
    );
  }

  try {
    const rawHookSecret = getRequiredEnv("AUTH_HOOK_SECRET");

    // Supabase stores hook secrets like: v1,whsec_<base64_secret>
    // standardwebhooks expects only the actual secret portion.
    const hookSecret = rawHookSecret.replace("v1,whsec_", "");

    const rawPayload = await req.text();
    const headers = Object.fromEntries(req.headers);

    const webhook = new Webhook(hookSecret);
    const payload = webhook.verify(rawPayload, headers) as SendSmsHookPayload;

    const phone = payload.user?.phone;
    const otp = payload.sms?.otp;

    console.log("sms_hook_received", {
      hasPhone: Boolean(phone),
      phoneEnding: phone ? phone.slice(-4) : null,
      hasOtp: Boolean(otp),
      otpLength: otp?.length ?? 0,
    });

    if (!phone || !otp) {
      return jsonResponse(
        {
          error: {
            http_code: 400,
            message: "Missing phone or OTP in Supabase hook payload",
          },
        },
        400,
      );
    }

    if (!/^\d{6}$/.test(otp)) {
      return jsonResponse(
        {
          error: {
            http_code: 400,
            message: "Invalid OTP format",
          },
        },
        400,
      );
    }

    const phoneDigits = normalizeIndianPhoneNumber(phone);

    await sendOtpWith2Factor(phoneDigits, otp);

    // Supabase treats a 200 response as success.
    return new Response(JSON.stringify({}), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    console.error("send-sms-otp hook failed", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse(
      {
        error: {
          http_code: 500,
          message: error instanceof Error ? error.message : "Unknown server error",
        },
      },
      500,
    );
  }
});