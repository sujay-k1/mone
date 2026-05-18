import {
  createSupabaseAdminClient,
  createSupabaseUserClient,
  getBearerToken,
  jsonResponse,
} from "../_shared/setu-aa.ts";
import {
  parseSetuFiPayload,
  type ParsedSetuAccount,
} from "../_shared/setu-fi-parser.ts";

type ParseArtifactRequest = {
  artifactId?: string;
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

    const requestBody = await req.json().catch(() => ({})) as ParseArtifactRequest;
    const artifactId = requestBody.artifactId?.trim();

    if (!artifactId) {
      return jsonResponse({ error: "Missing artifactId" }, 400);
    }

    const supabaseAdmin = createSupabaseAdminClient();
    const { data: artifact, error: artifactError } = await supabaseAdmin
      .from("financial_data_artifacts")
      .select("id,user_id,setu_consent_id,setu_data_session_id,payload")
      .eq("id", artifactId)
      .maybeSingle();

    if (artifactError) {
      console.error("parse_setu_fi_artifact_lookup_failed", {
        hasArtifactId: true,
        message: artifactError.message,
      });
      return jsonResponse({ error: "Could not load financial data artifact" }, 500);
    }

    if (!artifact || artifact.user_id !== user.id) {
      return jsonResponse({ error: "Artifact not found" }, 404);
    }

    const parsed = await parseSetuFiPayload(artifact.payload);
    let insertedTransactionCount = 0;

    for (const account of parsed.accounts) {
      const financialAccountId = await upsertFinancialAccount(
        supabaseAdmin,
        user.id,
        artifact.setu_consent_id,
        artifact.setu_data_session_id,
        account,
      );

      insertedTransactionCount += await upsertTransactions(
        supabaseAdmin,
        user.id,
        financialAccountId,
        artifact.setu_consent_id,
        artifact.setu_data_session_id,
        account,
      );
    }

    console.log("parse_setu_fi_artifact_completed", {
      hasArtifactId: true,
      fipCount: parsed.fipCount,
      accountCount: parsed.accountCount,
      transactionCount: parsed.transactionCount,
      fiTypes: parsed.fiTypes,
    });

    return jsonResponse({
      accountCount: parsed.accountCount,
      transactionCount: parsed.transactionCount,
      insertedTransactionCount,
      fiTypes: parsed.fiTypes,
    });
  } catch (error) {
    console.error("parse_setu_fi_artifact_unhandled_error", {
      message: error instanceof Error ? error.message : String(error),
    });

    return jsonResponse({ error: "Unexpected server error" }, 500);
  }
});

async function upsertFinancialAccount(
  supabaseAdmin: ReturnType<typeof createSupabaseAdminClient>,
  userId: string,
  consentId: string | null,
  dataSessionId: string | null,
  account: ParsedSetuAccount,
): Promise<string> {
  const accountPayload = {
    user_id: userId,
    source: "SETU_AA",
    setu_consent_id: consentId,
    setu_data_session_id: dataSessionId,
    fip_id: account.fipId,
    fi_type: account.fiType,
    link_ref_number: account.linkRefNumber,
    masked_account_number: account.maskedAccountNumber,
    account_type: account.accountType,
    account_status: account.accountStatus,
    currency: account.currency,
    current_balance: account.currentBalance,
    balance_datetime: account.balanceDateTime,
    raw_profile: account.rawProfile,
    raw_summary: account.rawSummary,
    raw_account: account.rawAccount,
  };

  if (account.linkRefNumber) {
    const { data, error } = await supabaseAdmin
      .from("financial_accounts")
      .upsert(accountPayload, {
        onConflict: "user_id,source,link_ref_number",
      })
      .select("id")
      .single();

    if (error) {
      throw new Error(`Could not upsert financial account: ${error.message}`);
    }

    return data.id;
  }

  const { data: existing } = await supabaseAdmin
    .from("financial_accounts")
    .select("id")
    .eq("user_id", userId)
    .eq("source", "SETU_AA")
    .eq("setu_data_session_id", dataSessionId)
    .eq("fip_id", account.fipId)
    .eq("fi_type", account.fiType)
    .eq("masked_account_number", account.maskedAccountNumber)
    .maybeSingle();

  if (existing?.id) {
    const { error } = await supabaseAdmin
      .from("financial_accounts")
      .update(accountPayload)
      .eq("id", existing.id);

    if (error) {
      throw new Error(`Could not update financial account: ${error.message}`);
    }

    return existing.id;
  }

  const { data, error } = await supabaseAdmin
    .from("financial_accounts")
    .insert(accountPayload)
    .select("id")
    .single();

  if (error) {
    throw new Error(`Could not insert financial account: ${error.message}`);
  }

  return data.id;
}

async function upsertTransactions(
  supabaseAdmin: ReturnType<typeof createSupabaseAdminClient>,
  userId: string,
  financialAccountId: string,
  consentId: string | null,
  dataSessionId: string | null,
  account: ParsedSetuAccount,
): Promise<number> {
  const payloads = account.transactions.map((transaction) => ({
    user_id: userId,
    financial_account_id: financialAccountId,
    source: "SETU_AA",
    setu_consent_id: consentId,
    setu_data_session_id: dataSessionId,
    fip_id: account.fipId,
    fi_type: account.fiType,
    link_ref_number: account.linkRefNumber,
    masked_account_number: account.maskedAccountNumber,
    txn_id: transaction.txnId,
    transaction_type: transaction.transactionType,
    direction: transaction.direction,
    mode: transaction.mode,
    amount: transaction.amount,
    narration: transaction.narration,
    reference: transaction.reference,
    value_date: transaction.valueDate,
    transaction_timestamp: transaction.transactionTimestamp,
    balance_after_transaction: transaction.balanceAfterTransaction,
    raw_transaction: transaction.rawTransaction,
    raw_transaction_hash: transaction.rawTransactionHash,
  }));

  if (payloads.length === 0) {
    return 0;
  }

  const txnIdPayloads = payloads.filter((payload) => payload.txn_id && payload.link_ref_number);
  const hashPayloads = payloads.filter((payload) => !payload.txn_id || !payload.link_ref_number);

  if (txnIdPayloads.length > 0) {
    const { error } = await supabaseAdmin
      .from("financial_transactions")
      .upsert(txnIdPayloads, {
        onConflict: "user_id,source,fip_id,link_ref_number,txn_id",
        ignoreDuplicates: true,
      });

    if (error) {
      throw new Error(`Could not batch upsert financial transactions: ${error.message}`);
    }
  }

  if (hashPayloads.length > 0) {
    const hashes = Array.from(
      new Set(hashPayloads.map((payload) => payload.raw_transaction_hash).filter(Boolean)),
    );
    const existingHashes = new Set<string>();

    if (hashes.length > 0) {
      let existingQuery = supabaseAdmin
        .from("financial_transactions")
        .select("raw_transaction_hash")
        .eq("user_id", userId)
        .eq("source", "SETU_AA")
        .eq("fip_id", account.fipId)
        .in("raw_transaction_hash", hashes);

      if (account.linkRefNumber) {
        existingQuery = existingQuery.eq("link_ref_number", account.linkRefNumber);
      } else {
        existingQuery = existingQuery.is("link_ref_number", null);
      }

      const { data: existingRows, error: existingError } = await existingQuery;

      if (existingError) {
        throw new Error(`Could not check existing hash financial transactions: ${existingError.message}`);
      }

      for (const row of existingRows ?? []) {
        if (row.raw_transaction_hash) {
          existingHashes.add(row.raw_transaction_hash);
        }
      }
    }

    const missingHashPayloads = hashPayloads.filter(
      (payload) => !payload.raw_transaction_hash || !existingHashes.has(payload.raw_transaction_hash),
    );

    if (missingHashPayloads.length > 0) {
      const { error } = await supabaseAdmin
        .from("financial_transactions")
        .insert(missingHashPayloads);

      if (error) {
        throw new Error(`Could not batch insert hash financial transactions: ${error.message}`);
      }
    }
  }

  return payloads.length;
}
