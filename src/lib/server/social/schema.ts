import { ensureAppSchema } from '@/lib/server/appDb';

let socialSchemaReady: Promise<void> | null = null;

export async function ensureSocialSchema() {
  if (!socialSchemaReady) {
    socialSchemaReady = ensureAppSchema();
  }
  return socialSchemaReady;
}
