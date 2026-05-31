import crypto from 'crypto';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

const SECRET_PREFIX = 'enc:v1:';

function secretSource() {
  return (
    readRuntimeEnv('MAIL_SECRET_KEY') ||
    'pateeznews-mail-dev-secret'
  );
}

function key() {
  return crypto.createHash('sha256').update(secretSource()).digest();
}

export function encryptSecret(value?: unknown) {
  const text = String(value || '').trim();
  if (!text || text.startsWith(SECRET_PREFIX)) return text || null;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key(), iv);
  const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${SECRET_PREFIX}${iv.toString('base64url')}.${tag.toString('base64url')}.${encrypted.toString('base64url')}`;
}

export function decryptSecret(value?: unknown) {
  const text = String(value || '').trim();
  if (!text) return '';
  if (!text.startsWith(SECRET_PREFIX)) return text;

  const payload = text.slice(SECRET_PREFIX.length);
  const [ivRaw, tagRaw, encryptedRaw] = payload.split('.');
  if (!ivRaw || !tagRaw || !encryptedRaw) return '';

  const decipher = crypto.createDecipheriv('aes-256-gcm', key(), Buffer.from(ivRaw, 'base64url'));
  decipher.setAuthTag(Buffer.from(tagRaw, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(encryptedRaw, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}

export function hasSecret(value?: unknown) {
  return Boolean(String(value || '').trim());
}
