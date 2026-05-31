import { ensureAppSchema } from '@/lib/server/appDb';

let mailSchemaReady: Promise<void> | null = null;

export async function ensureMailSchema() {
  if (!mailSchemaReady) {
    mailSchemaReady = ensureAppSchema();
  }
  return mailSchemaReady;
}
