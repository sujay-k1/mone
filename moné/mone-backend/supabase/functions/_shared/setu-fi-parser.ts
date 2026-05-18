export type JsonObject = Record<string, unknown>;

export type ParsedSetuAccount = {
  fipId?: string;
  fiType: string;
  linkRefNumber?: string;
  maskedAccountNumber?: string;
  accountType?: string;
  accountStatus?: string;
  currency?: string;
  currentBalance?: number;
  balanceDateTime?: string;
  rawProfile?: unknown;
  rawSummary?: unknown;
  rawAccount: unknown;
  transactions: ParsedSetuTransaction[];
};

export type ParsedSetuTransaction = {
  txnId?: string;
  transactionType?: string;
  direction?: string;
  mode?: string;
  amount?: number;
  narration?: string;
  reference?: string;
  valueDate?: string;
  transactionTimestamp?: string;
  balanceAfterTransaction?: number;
  rawTransaction: unknown;
  rawTransactionHash: string;
};

export type ParsedSetuPayload = {
  fipCount: number;
  accountCount: number;
  transactionCount: number;
  fiTypes: string[];
  accounts: ParsedSetuAccount[];
};

export async function parseSetuFiPayload(payload: unknown): Promise<ParsedSetuPayload> {
  const fips = extractFips(payload);
  const accounts: ParsedSetuAccount[] = [];
  const fiTypes = new Set<string>();
  let transactionCount = 0;

  for (const fip of fips) {
    const fipId = stringAtAnyPath(fip, [
      ["fipID"],
      ["fipId"],
      ["fip_id"],
      ["id"],
    ]);
    const dataItems = arrayAtAnyPath(fip, [["data"], ["Data"]]);

    for (const dataItem of dataItems) {
      const decryptedFI = objectAtAnyPath(dataItem, [
        ["decryptedFI"],
        ["decryptedFi"],
        ["decrypted_fi"],
      ]);
      const fiType = normalizeFiType(
        stringAtAnyPath(decryptedFI ?? dataItem, [["type"], ["fiType"], ["fi_type"]]) ??
          "unknown",
      );
      const account = valueAtPath(decryptedFI ?? dataItem, ["account"]) ??
        valueAtPath(dataItem, ["account"]);

      if (!account || typeof account !== "object") {
        continue;
      }

      fiTypes.add(fiType);

      const parsedTransactions = await parseTransactions(account);
      transactionCount += parsedTransactions.length;

      accounts.push({
        fipId,
        fiType,
        linkRefNumber: stringAtAnyPath(account, [
          ["linkRefNumber"],
          ["link_ref_number"],
          ["linkReferenceNumber"],
          ["Profile", "Holders", "Holder", "linkRefNumber"],
        ]),
        maskedAccountNumber: stringAtAnyPath(account, [
          ["maskedAccNumber"],
          ["maskedAccountNumber"],
          ["masked_account_number"],
          ["Profile", "Holders", "Holder", "maskedAccNumber"],
          ["profile", "holders", "holder", "maskedAccNumber"],
        ]),
        accountType: stringAtAnyPath(account, [
          ["type"],
          ["accountType"],
          ["account_type"],
          ["Summary", "type"],
          ["summary", "type"],
        ]),
        accountStatus: stringAtAnyPath(account, [
          ["status"],
          ["accountStatus"],
          ["account_status"],
          ["Summary", "status"],
          ["summary", "status"],
        ]),
        currency: stringAtAnyPath(account, [
          ["currency"],
          ["Summary", "currency"],
          ["summary", "currency"],
        ]),
        currentBalance: numberAtAnyPath(account, [
          ["currentBalance"],
          ["current_balance"],
          ["Summary", "currentBalance"],
          ["summary", "currentBalance"],
          ["Summary", "balance"],
          ["summary", "balance"],
        ]),
        balanceDateTime: stringAtAnyPath(account, [
          ["balanceDateTime"],
          ["balance_datetime"],
          ["Summary", "balanceDateTime"],
          ["summary", "balanceDateTime"],
          ["Summary", "dateTime"],
          ["summary", "dateTime"],
        ]),
        rawProfile: valueAtPath(account, ["profile"]) ?? valueAtPath(account, ["Profile"]),
        rawSummary: valueAtPath(account, ["summary"]) ?? valueAtPath(account, ["Summary"]),
        rawAccount: account,
        transactions: parsedTransactions,
      });
    }
  }

  return {
    fipCount: fips.length,
    accountCount: accounts.length,
    transactionCount,
    fiTypes: Array.from(fiTypes).sort(),
    accounts,
  };
}

export function extractFips(payload: unknown): JsonObject[] {
  const candidates = [
    payload,
    valueAtPath(payload, ["fips"]),
    valueAtPath(payload, ["data", "fips"]),
    valueAtPath(payload, ["payload", "fips"]),
  ];

  for (const candidate of candidates) {
    if (Array.isArray(candidate)) {
      return candidate.filter(isJsonObject);
    }
  }

  return [];
}

async function parseTransactions(account: unknown): Promise<ParsedSetuTransaction[]> {
  const transactions = arrayAtAnyPath(account, [
    ["transactions"],
    ["Transactions"],
    ["transactions", "transaction"],
    ["Transactions", "Transaction"],
  ]);
  const flattened = transactions.flatMap((item) => Array.isArray(item) ? item : [item]);
  const parsed: ParsedSetuTransaction[] = [];

  for (const transaction of flattened) {
    if (!transaction || typeof transaction !== "object") {
      continue;
    }

    parsed.push({
      txnId: stringAtAnyPath(transaction, [
        ["txnId"],
        ["txnid"],
        ["transactionId"],
        ["transaction_id"],
        ["id"],
      ]),
      transactionType: stringAtAnyPath(transaction, [
        ["type"],
        ["transactionType"],
        ["transaction_type"],
      ]),
      direction: directionFromTransaction(transaction),
      mode: stringAtAnyPath(transaction, [["mode"], ["transactionMode"]]),
      amount: numberAtAnyPath(transaction, [["amount"], ["txnAmount"]]),
      narration: stringAtAnyPath(transaction, [["narration"], ["description"], ["memo"]]),
      reference: stringAtAnyPath(transaction, [["reference"], ["ref"], ["referenceNumber"]]),
      valueDate: dateOnlyString(stringAtAnyPath(transaction, [["valueDate"], ["value_date"]])),
      transactionTimestamp: stringAtAnyPath(transaction, [
        ["transactionTimestamp"],
        ["transaction_timestamp"],
        ["transactionDateTime"],
        ["dateTime"],
        ["date"],
      ]),
      balanceAfterTransaction: numberAtAnyPath(transaction, [
        ["balance"],
        ["currentBalance"],
        ["balanceAfterTransaction"],
      ]),
      rawTransaction: transaction,
      rawTransactionHash: await sha256Hex(transaction),
    });
  }

  return parsed;
}

function directionFromTransaction(transaction: unknown): string | undefined {
  const explicitDirection = stringAtAnyPath(transaction, [["direction"], ["txnDirection"]]);

  if (explicitDirection) {
    return explicitDirection.toUpperCase();
  }

  const type = stringAtAnyPath(transaction, [["type"], ["transactionType"]])?.toUpperCase();

  if (type?.includes("DEBIT") || type === "DR") {
    return "DEBIT";
  }

  if (type?.includes("CREDIT") || type === "CR") {
    return "CREDIT";
  }

  return undefined;
}

function normalizeFiType(value: string): string {
  return value.trim().toLowerCase();
}

function dateOnlyString(value: string | undefined): string | undefined {
  return value?.slice(0, 10);
}

function arrayAtAnyPath(value: unknown, paths: string[][]): unknown[] {
  for (const path of paths) {
    const candidate = valueAtPath(value, path);

    if (Array.isArray(candidate)) {
      return candidate;
    }
  }

  return [];
}

function objectAtAnyPath(value: unknown, paths: string[][]): JsonObject | undefined {
  for (const path of paths) {
    const candidate = valueAtPath(value, path);

    if (isJsonObject(candidate)) {
      return candidate;
    }
  }

  return undefined;
}

function stringAtAnyPath(value: unknown, paths: string[][]): string | undefined {
  for (const path of paths) {
    const candidate = valueAtPath(value, path);

    if (typeof candidate === "string" && candidate.trim()) {
      return candidate.trim();
    }

    if (typeof candidate === "number" || typeof candidate === "boolean") {
      return String(candidate);
    }
  }

  return undefined;
}

function numberAtAnyPath(value: unknown, paths: string[][]): number | undefined {
  for (const path of paths) {
    const candidate = valueAtPath(value, path);

    if (typeof candidate === "number" && Number.isFinite(candidate)) {
      return candidate;
    }

    if (typeof candidate === "string") {
      const normalized = candidate.replace(/,/g, "").trim();
      const parsed = Number(normalized);

      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }

  return undefined;
}

function valueAtPath(value: unknown, path: string[]): unknown {
  let current = value;

  for (const key of path) {
    if (!isJsonObject(current)) {
      return undefined;
    }

    current = current[key];
  }

  return current;
}

function isJsonObject(value: unknown): value is JsonObject {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

async function sha256Hex(value: unknown): Promise<string> {
  const encoded = new TextEncoder().encode(JSON.stringify(value));
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
