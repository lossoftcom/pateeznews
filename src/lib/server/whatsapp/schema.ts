import { ensureAppSchema } from '@/lib/server/appDb';

let whatsappSchemaReady: Promise<void> | null = null;

export async function ensureWhatsappSchema() {
  if (!whatsappSchemaReady) {
    whatsappSchemaReady = ensureAppSchema();
  }
  return whatsappSchemaReady;
}
