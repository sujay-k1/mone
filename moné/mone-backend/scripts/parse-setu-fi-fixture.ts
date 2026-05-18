import { parseSetuFiPayload } from "../supabase/functions/_shared/setu-fi-parser.ts";

const fixturePath = new URL("../fixtures/setu/broad-fi-sandbox-redacted.json", import.meta.url);

try {
  const fileInfo = await Deno.stat(fixturePath);

  if (fileInfo.size === 0) {
    throw new Error("Fixture file is empty. Restore the redacted broad FI fixture before running parser checks.");
  }

  const payload = JSON.parse(await Deno.readTextFile(fixturePath));
  const parsed = await parseSetuFiPayload(payload);

  console.log(JSON.stringify({
    fipCount: parsed.fipCount,
    accountCount: parsed.accountCount,
    fiTypes: parsed.fiTypes,
    transactionCount: parsed.transactionCount,
  }, null, 2));
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  Deno.exit(1);
}
