// ============================================================================
// AA Payload Builder — wraps generated transactions into Setu AA format
// ============================================================================

import type {
  PersonaConfig,
  GeneratedTransaction,
  AAPayload,
  AATransaction,
} from "./types.ts";
import { formatAmount } from "./random.ts";

export function buildAAPayload(
  config: PersonaConfig,
  transactions: GeneratedTransaction[],
  linkedAccRef: string,
  maskedAccNumber: string,
): AAPayload[] {
  const deposit = config.accounts.deposit;
  if (!deposit) throw new Error("No deposit account configured");

  const lastTxn = transactions[transactions.length - 1];
  const closingBalance = lastTxn?.balance_after ?? deposit.opening_balance;
  const lastTimestamp = lastTxn?.timestamp ?? `${config.period.end}T23:59:59+05:30`;

  const aaTransactions: AATransaction[] = transactions.map((txn) => ({
    txnId: txn.txn_id,
    type: txn.direction,
    mode: txn.mode,
    amount: formatAmount(txn.amount),
    narration: txn.narration,
    reference: txn.reference,
    valueDate: txn.date,
    currentBalance: formatAmount(txn.balance_after),
    transactionTimestamp: txn.timestamp,
  }));

  const payload: AAPayload = {
    fipID: `FIP-${deposit.bank.toUpperCase()}-001`,
    data: [
      {
        decryptedFI: {
          type: "deposit",
          account: {
            type: "deposit",
            version: "2.0.0",
            linkedAccRef,
            profile: {
              holders: {
                type: "SINGLE",
                holder: [
                  {
                    dob: config.persona.dob,
                    pan: config.persona.pan,
                    name: config.persona.name,
                    email: config.persona.email,
                    mobile: config.persona.mobile,
                    address: config.persona.address,
                    nominee: "REGISTERED",
                    ckycCompliance: "true",
                  },
                ],
              },
            },
            summary: {
              type: deposit.type,
              branch: deposit.branch,
              status: "ACTIVE",
              currency: "INR",
              facility: "OD",
              ifscCode: deposit.ifsc,
              micrCode: deposit.ifsc.replace("HDFC", "560").slice(0, 9),
              openingDate: `${config.period.start}T00:00:00+05:30`,
              currentBalance: formatAmount(closingBalance),
              balanceDateTime: lastTimestamp,
            },
            transactions: {
              startDate: config.period.start,
              endDate: config.period.end,
              transaction: aaTransactions,
            },
          },
        },
      },
    ],
  };

  return [payload];
}
