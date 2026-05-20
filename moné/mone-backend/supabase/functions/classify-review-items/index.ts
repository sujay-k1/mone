const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ReviewItem = {
  transactionId: string;
  narration: string;
  amount: number;
  type: string;
  mode: string;
  timestamp?: string | null;
  parsedCounterparty?: string | null;
  tokens: string[];
  amountBand: string;
  timeBand?: string | null;
  dayOfMonth?: number | null;
  isPaymentProcessorOnly: boolean;
  isPersonLikeCounterparty: boolean;
  hasLocalShopSignal: boolean;
  hasBillSignal: boolean;
  hasTransferSignal: boolean;
  allowedRoles: string[];
  allowedCategoryFamilies: string[];
};

type RequestBody = {
  personaId: "aarav" | "priya";
  month: string;
  items: ReviewItem[];
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const openAIKey = Deno.env.get("OPENAI_API_KEY");
    const model = Deno.env.get("OPENAI_MODEL");

    if (!openAIKey) {
      return jsonResponse({ error: "Missing OPENAI_API_KEY secret" }, 500);
    }

    if (!model) {
      return jsonResponse({ error: "Missing OPENAI_MODEL secret" }, 500);
    }

    const body = (await req.json()) as RequestBody;

    if (!body.items || !Array.isArray(body.items)) {
      return jsonResponse({ error: "Missing items array" }, 400);
    }

    if (body.items.length === 0) {
      return jsonResponse({ suggestions: [] }, 200);
    }

    const prompt = buildPrompt(body);

    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: systemPrompt(),
              },
            ],
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: prompt,
              },
            ],
          },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "mone_review_classification",
            strict: true,
            schema: responseSchema(),
          },
        },
      }),
    });

    if (!openAIResponse.ok) {
      const errorText = await openAIResponse.text();
      return jsonResponse(
        {
          error: "OpenAI request failed",
          details: errorText,
        },
        500,
      );
    }

    const result = await openAIResponse.json();
    const outputText = extractOutputText(result);

    if (!outputText) {
      return jsonResponse(
        {
          error: "No structured output text returned",
          raw: result,
        },
        500,
      );
    }

    const parsed = JSON.parse(outputText);

    return jsonResponse(parsed, 200);
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

function systemPrompt(): string {
  return `
You classify ambiguous Indian personal-finance transactions for Moné.

Your goal is not perfect merchant tagging. Your goal is to place each transaction into the safest useful financial bucket.

Rules:
- Choose only from the allowed roles and category families.
- Prefer broad categories over over-specific guesses.
- If a transaction clearly indicates travel, tax, medical, shopping, family support, cash, or utility, use that category family.
- Do not treat payment processors like PaytmQR, PhonePeQR, BharatPe, Razorpay, BillDesk, or Cashfree as the final merchant.
- If the narration only exposes a payment processor, classify it as local_upi unless there is clear merchant context.
- High-impact person transfers should usually need review unless the purpose is obvious.
- Self transfers and asset transfers should not be treated as spend.
- Tax payments should use categoryFamily tax.
- Flights, hotels, MakeMyTrip, Goibibo, Indigo, Air India, IRCTC, redBus should use categoryFamily travel.
- Output JSON only.
`;
}

function buildPrompt(body: RequestBody): string {
  return JSON.stringify(
    {
      personaId: body.personaId,
      month: body.month,
      task:
        "Classify these remaining review transactions. These are already filtered by an on-device classifier. Return one suggestion per transaction.",
      items: body.items,
    },
    null,
    2,
  );
}

function responseSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["suggestions"],
    properties: {
      suggestions: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "transactionId",
            "role",
            "categoryFamily",
            "category",
            "confidence",
            "needsReview",
            "reviewQuestion",
            "evidence",
          ],
          properties: {
            transactionId: { type: "string" },
            role: {
              type: "string",
              enum: [
                "income",
                "committed_outflow",
                "everyday_spend",
                "fund_building",
                "liability_payment",
                "self_transfer",
                "cash_withdrawal",
                "reimbursement_or_refund",
                "asset_transfer",
                "unknown",
              ],
            },
            categoryFamily: {
              type: "string",
              enum: [
                "income",
                "housing",
                "utilities",
                "subscriptions",
                "insurance",
                "investments",
                "debt",
                "tax",
                "family_support",
                "household_help",
                "food_snacks",
                "groceries",
                "transport",
                "travel",
                "medical",
                "shopping",
                "education",
                "personal_care",
                "lifestyle_entertainment",
                "gifts_donations",
                "local_service",
                "local_upi",
                "cash",
                "transfers",
                "reimbursements_refunds",
                "fees_charges",
                "business_work",
                "asset_transfer",
                "other",
                "unknown",
              ],
            },
            category: { type: "string" },
            confidence: {
              type: "integer",
              minimum: 0,
              maximum: 100,
            },
            needsReview: { type: "boolean" },
            reviewQuestion: {
              type: ["string", "null"],
            },
            evidence: {
              type: "array",
              items: { type: "string" },
            },
          },
        },
      },
    },
  };
}

function extractOutputText(result: any): string | null {
  if (typeof result.output_text === "string") {
    return result.output_text;
  }

  const parts: string[] = [];

  for (const output of result.output ?? []) {
    for (const content of output.content ?? []) {
      if (typeof content.text === "string") {
        parts.push(content.text);
      }
    }
  }

  return parts.length > 0 ? parts.join("") : null;
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