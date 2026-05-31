import { ensureAppSchema } from '@/lib/server/appDb';

let smsSchemaReady: Promise<void> | null = null;

export async function ensureSmsSchema() {
  if (!smsSchemaReady) {
    smsSchemaReady = ensureAppSchema();
  }
  return smsSchemaReady;
}
