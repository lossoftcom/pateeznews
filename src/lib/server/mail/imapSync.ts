import net from 'node:net';
import tls from 'node:tls';
import { TextDecoder } from 'node:util';
import { dbQuery } from '@/lib/server/supabaseDb';
import { decryptSecret } from './secrets';

const DEFAULT_SYNC_LIMIT = 30;
const CONNECT_TIMEOUT_MS = 8_000;
const COMMAND_TIMEOUT_MS = 10_000;
const FETCH_TIMEOUT_MS = 12_000;

type MailAccountRow = {
  id: string;
  account_name: string | null;
  sender_email: string | null;
  imap_host: string | null;
  imap_port: number | null;
  imap_username: string | null;
  imap_password_encrypted: string | null;
  smtp_password_encrypted: string | null;
};

type SyncOptions = {
  accountId?: string;
  maxMessages?: number;
};

type SyncResult = {
  attempted: number;
  imported: number;
  errors: string[];
};

type ParsedMessage = {
  messageId: string;
  senderEmail: string;
  senderName: string;
  recipientEmail: string;
  subject: string;
  text: string;
  html: string;
  attachments: AttachmentMeta[];
  images: AttachmentMeta[];
  date: string | null;
};

type AttachmentMeta = {
  filename: string;
  content_type: string;
  size: number;
  inline: boolean;
};

type MimeSink = {
  text: string;
  html: string;
  attachments: AttachmentMeta[];
  images: AttachmentMeta[];
};

type ParsedHeaders = Record<string, string>;

type ContentHeader = {
  value: string;
  params: Record<string, string>;
};

type FetchPayload = {
  uid: number;
  flags: string;
  raw: Buffer;
};

class ImapConnection {
  private socket: net.Socket | tls.TLSSocket | null = null;
  private tagCounter = 0;

  constructor(
    private readonly host: string,
    private readonly port: number,
  ) {}

  async connect() {
    const secure = this.port !== 143;
    this.socket = await new Promise<net.Socket | tls.TLSSocket>(
      (resolve, reject) => {
        const onError = (error: Error) => {
          cleanup();
          reject(error);
        };
        const onTimeout = () => {
          cleanup();
          socket.destroy();
          reject(new Error('IMAP connection timed out'));
        };
        const onConnect = () => {
          cleanup();
          resolve(socket);
        };
        const socket = secure
          ? tls.connect({
              host: this.host,
              port: this.port,
              servername: this.host,
              timeout: CONNECT_TIMEOUT_MS,
            })
          : net.connect({
              host: this.host,
              port: this.port,
              timeout: CONNECT_TIMEOUT_MS,
            });
        const cleanup = () => {
          socket.off('error', onError);
          socket.off('timeout', onTimeout);
          socket.off(secure ? 'secureConnect' : 'connect', onConnect);
        };
        socket.once('error', onError);
        socket.once('timeout', onTimeout);
        socket.once(secure ? 'secureConnect' : 'connect', onConnect);
      },
    );
    this.socket.setTimeout(0);
  }

  async login(username: string, password: string) {
    await this.command(`LOGIN ${imapString(username)} ${imapString(password)}`);
  }

  async examineInbox() {
    await this.command('EXAMINE "INBOX"');
  }

  async uidSearchAll() {
    const response = await this.command('UID SEARCH ALL');
    const match = response.toString('latin1').match(/\* SEARCH\s+([0-9\s]*)/i);
    if (!match) return <number[]>[];
    return match[1]
      .split(/\s+/)
      .map((item) => Number(item))
      .filter((item) => Number.isFinite(item) && item > 0);
  }

  async fetchMessage(uid: number) {
    const response = await this.command(
      `UID FETCH ${uid} (UID FLAGS BODY.PEEK[])`,
      FETCH_TIMEOUT_MS,
    );
    return parseFetchPayload(response, uid);
  }

  async logout() {
    try {
      await this.command('LOGOUT', 2_000);
    } catch {
      // Socket teardown below is enough if the server already closed the session.
    }
    this.socket?.destroy();
    this.socket = null;
  }

  private async command(command: string, timeoutMs = COMMAND_TIMEOUT_MS) {
    const socket = this.socket;
    if (!socket) throw new Error('IMAP connection is not open');
    const tag = `A${String(++this.tagCounter).padStart(4, '0')}`;
    const chunks: Buffer[] = [];
    return new Promise<Buffer>((resolve, reject) => {
      const finish = (error?: Error) => {
        clearTimeout(timer);
        socket.off('data', onData);
        socket.off('error', onError);
        if (error) reject(error);
        else resolve(Buffer.concat(chunks));
      };
      const onError = (error: Error) => finish(error);
      const timer = setTimeout(
        () => finish(new Error(`IMAP command timed out: ${command}`)),
        timeoutMs,
      );
      const onData = (chunk: Buffer) => {
        chunks.push(chunk);
        const text = Buffer.concat(chunks).toString('latin1');
        const tagged = new RegExp(`(?:^|\\r\\n)${tag} (OK|NO|BAD)`, 'i').exec(
          text,
        );
        if (!tagged) return;
        if (tagged[1].toUpperCase() === 'OK') {
          finish();
          return;
        }
        finish(new Error(lastResponseLine(text, tag)));
      };
      socket.on('data', onData);
      socket.once('error', onError);
      socket.write(`${tag} ${command}\r\n`, 'utf8');
    });
  }
}

export async function syncMailInboxFromImap(
  options: SyncOptions = {},
): Promise<SyncResult> {
  const maxMessages = Math.max(
    1,
    Math.min(options.maxMessages || DEFAULT_SYNC_LIMIT, 100),
  );
  const values: unknown[] = [];
  const where = [
    'aktif_mi IS TRUE',
    "NULLIF(TRIM(COALESCE(imap_sunucu, '')), '') IS NOT NULL",
  ];
  if (options.accountId) {
    values.push(options.accountId);
    where.push(`id = $${values.length}::bigint`);
  }
  const accounts = await dbQuery<MailAccountRow>(
    `SELECT
       id::text AS id,
       hesap_adi AS account_name,
       gonderen_eposta AS sender_email,
       imap_sunucu AS imap_host,
       imap_port,
       imap_kullanici AS imap_username,
       imap_sifre AS imap_password_encrypted,
       smtp_sifre AS smtp_password_encrypted
     FROM public.mail_accounts
     WHERE ${where.join(' AND ')}
     ORDER BY aktif_mi DESC, olusturma_tarihi DESC`,
    values,
  );

  const result: SyncResult = {
    attempted: accounts.rows.length,
    imported: 0,
    errors: [],
  };
  for (const account of accounts.rows) {
    try {
      result.imported += await syncAccount(account, maxMessages);
    } catch (error: any) {
      const accountLabel =
        account.account_name || account.sender_email || account.id;
      result.errors.push(
        `${accountLabel}: ${error?.message || 'IMAP sync failed'}`,
      );
    }
  }
  return result;
}

async function syncAccount(account: MailAccountRow, maxMessages: number) {
  const host = String(account.imap_host || '').trim();
  const port = Number(account.imap_port || 993) || 993;
  const username = String(
    account.imap_username || account.sender_email || '',
  ).trim();
  const password =
    decryptSecret(account.imap_password_encrypted) ||
    decryptSecret(account.smtp_password_encrypted);
  if (!host || !username || !password) return 0;

  const client = new ImapConnection(host, port);
  await client.connect();
  try {
    await client.login(username, password);
    await client.examineInbox();
    const uids = await client.uidSearchAll();
    const latest = uids.slice(-maxMessages);
    let imported = 0;
    for (const uid of latest) {
      const payload = await client.fetchMessage(uid);
      if (!payload) continue;
      const parsed = parseMessage(payload.raw);
      await upsertInboxMessage(account, payload, parsed);
      imported++;
    }
    return imported;
  } finally {
    await client.logout();
  }
}

async function upsertInboxMessage(
  account: MailAccountRow,
  payload: FetchPayload,
  parsed: ParsedMessage,
) {
  const read = /\\Seen/i.test(payload.flags);
  const messageId = parsed.messageId || `imap:${payload.uid}`;
  const senderEmail =
    parsed.senderEmail || String(account.sender_email || '').trim();
  const recipientEmail =
    parsed.recipientEmail || String(account.sender_email || '').trim();
  await dbQuery(
    `INSERT INTO public.mail_inbox (
       hesap_id, message_id, gonderen_eposta, gonderen_adi, alici_eposta,
       konu, icerik_text, icerik_html, ek_dosyalar_json, resimler_json,
       okundu, okunma_tarihi, etiketler_json, klasor, mail_tarihi
     )
     VALUES (
       $1::bigint, $2, $3, $4, $5,
       $6, $7, $8, $9, $10,
       $11, CASE WHEN $11 THEN now() ELSE NULL END, '[]', 'inbox', $12::timestamptz
     )
     ON CONFLICT (hesap_id, message_id) WHERE message_id IS NOT NULL
     DO UPDATE SET
       gonderen_eposta = EXCLUDED.gonderen_eposta,
       gonderen_adi = EXCLUDED.gonderen_adi,
       alici_eposta = EXCLUDED.alici_eposta,
       konu = EXCLUDED.konu,
       icerik_text = EXCLUDED.icerik_text,
       icerik_html = EXCLUDED.icerik_html,
       ek_dosyalar_json = EXCLUDED.ek_dosyalar_json,
       resimler_json = EXCLUDED.resimler_json,
       okundu = EXCLUDED.okundu,
       okunma_tarihi = CASE WHEN EXCLUDED.okundu THEN COALESCE(public.mail_inbox.okunma_tarihi, now()) ELSE NULL END,
       mail_tarihi = COALESCE(EXCLUDED.mail_tarihi, public.mail_inbox.mail_tarihi)`,
    [
      account.id,
      messageId,
      senderEmail || 'unknown@local',
      parsed.senderName,
      recipientEmail,
      parsed.subject,
      parsed.text,
      parsed.html,
      JSON.stringify(parsed.attachments),
      JSON.stringify(parsed.images),
      read,
      parsed.date,
    ],
  );
}

function parseFetchPayload(
  response: Buffer,
  requestedUid: number,
): FetchPayload | null {
  const text = response.toString('latin1');
  const literal = /BODY(?:\.PEEK)?\[\][^{]*\{(\d+)\}\r\n/i.exec(text);
  if (!literal) return null;
  const start = literal.index + literal[0].length;
  const length = Number(literal[1]);
  if (
    !Number.isFinite(length) ||
    length <= 0 ||
    start + length > response.length
  )
    return null;
  const prefix = text.slice(0, literal.index);
  const uid = Number(prefix.match(/\bUID\s+(\d+)/i)?.[1] || requestedUid);
  const flags = prefix.match(/\bFLAGS\s+\(([^)]*)\)/i)?.[1] || '';
  return {
    uid,
    flags,
    raw: response.subarray(start, start + length),
  };
}

function parseMessage(raw: Buffer): ParsedMessage {
  const { headers, body } = splitHeadersAndBody(raw);
  const sink: MimeSink = { text: '', html: '', attachments: [], images: [] };
  parseMimeEntity(headers, body, sink);
  const from = parseAddress(headers.from || '');
  const to = parseAddress(headers.to || '');
  const date = parseDateHeader(headers.date || '');
  return {
    messageId: normalizeMessageId(headers['message-id'] || ''),
    senderEmail: from.email,
    senderName: from.name,
    recipientEmail: to.email,
    subject: decodeMimeWords(headers.subject || '').trim(),
    text: sink.text || stripHtml(sink.html),
    html: sink.html,
    attachments: sink.attachments,
    images: sink.images,
    date,
  };
}

function parseMimeEntity(headers: ParsedHeaders, body: Buffer, sink: MimeSink) {
  const contentType = parseContentHeader(
    headers['content-type'] || 'text/plain; charset=utf-8',
  );
  const disposition = parseContentHeader(headers['content-disposition'] || '');
  const encoding = String(headers['content-transfer-encoding'] || '')
    .trim()
    .toLowerCase();

  if (contentType.value.startsWith('multipart/')) {
    const boundary = contentType.params.boundary;
    if (!boundary) return;
    for (const part of splitMultipart(body, boundary)) {
      const parsed = splitHeadersAndBody(part);
      parseMimeEntity(parsed.headers, parsed.body, sink);
    }
    return;
  }

  const decoded = decodeTransferBody(body, encoding);
  const charset = contentType.params.charset || 'utf-8';
  const filename = disposition.params.filename || contentType.params.name || '';
  const inline = disposition.value === 'inline';
  const attachment =
    Boolean(filename) ||
    disposition.value === 'attachment' ||
    (inline && contentType.value.startsWith('image/'));

  if (attachment) {
    const meta: AttachmentMeta = {
      filename: filename || 'dosya',
      content_type: contentType.value || 'application/octet-stream',
      size: decoded.length,
      inline,
    };
    sink.attachments.push(meta);
    if (meta.content_type.startsWith('image/')) sink.images.push(meta);
    return;
  }

  if (contentType.value === 'text/html') {
    sink.html ||= decodeBuffer(decoded, charset).trim();
    return;
  }

  if (contentType.value === 'text/plain') {
    sink.text ||= decodeBuffer(decoded, charset).trim();
  }
}

function splitHeadersAndBody(raw: Buffer) {
  let index = raw.indexOf('\r\n\r\n');
  let separatorLength = 4;
  if (index < 0) {
    index = raw.indexOf('\n\n');
    separatorLength = 2;
  }
  if (index < 0)
    return {
      headers: parseHeaders(raw.toString('latin1')),
      body: Buffer.alloc(0),
    };
  return {
    headers: parseHeaders(raw.subarray(0, index).toString('latin1')),
    body: raw.subarray(index + separatorLength),
  };
}

function parseHeaders(headerText: string): ParsedHeaders {
  const lines = headerText.replace(/\r?\n[ \t]+/g, ' ').split(/\r?\n/);
  const headers: ParsedHeaders = {};
  for (const line of lines) {
    const index = line.indexOf(':');
    if (index <= 0) continue;
    const key = line.slice(0, index).trim().toLowerCase();
    const value = decodeMimeWords(line.slice(index + 1).trim());
    headers[key] = headers[key] ? `${headers[key]}, ${value}` : value;
  }
  return headers;
}

function parseContentHeader(value: string): ContentHeader {
  const parts = splitHeaderParams(value);
  const params: Record<string, string> = {};
  for (const part of parts.slice(1)) {
    const index = part.indexOf('=');
    if (index <= 0) continue;
    const key = part.slice(0, index).trim().toLowerCase();
    params[key.replace(/\*$/, '')] = decodeParameter(
      part.slice(index + 1).trim(),
    );
  }
  return {
    value: (parts[0] || '').trim().toLowerCase(),
    params,
  };
}

function splitHeaderParams(value: string) {
  const parts: string[] = [];
  let current = '';
  let quoted = false;
  for (const char of value) {
    if (char === '"') quoted = !quoted;
    if (char === ';' && !quoted) {
      parts.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  parts.push(current);
  return parts;
}

function splitMultipart(body: Buffer, boundary: string) {
  const delimiter = `--${boundary}`;
  const sections = body.toString('latin1').split(delimiter).slice(1);
  const parts: Buffer[] = [];
  for (const section of sections) {
    if (section.startsWith('--')) break;
    const cleaned = section.replace(/^\r?\n/, '').replace(/\r?\n$/, '');
    if (cleaned.trim()) parts.push(Buffer.from(cleaned, 'latin1'));
  }
  return parts;
}

function decodeTransferBody(body: Buffer, encoding: string) {
  if (encoding === 'base64') {
    return Buffer.from(body.toString('ascii').replace(/\s+/g, ''), 'base64');
  }
  if (encoding === 'quoted-printable') {
    return decodeQuotedPrintable(body.toString('latin1'));
  }
  return body;
}

function decodeQuotedPrintable(value: string) {
  const text = value.replace(/=\r?\n/g, '');
  const bytes: number[] = [];
  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    if (
      char === '=' &&
      /^[0-9A-Fa-f]{2}$/.test(text.slice(index + 1, index + 3))
    ) {
      bytes.push(Number.parseInt(text.slice(index + 1, index + 3), 16));
      index += 2;
    } else {
      bytes.push(char.charCodeAt(0) & 0xff);
    }
  }
  return Buffer.from(bytes);
}

function decodeMimeWords(value: string) {
  return value.replace(
    /=\?([^?]+)\?([bqBQ])\?([^?]*)\?=/g,
    (_match, charset, mode, data) => {
      const buffer =
        mode.toLowerCase() === 'b'
          ? Buffer.from(String(data).replace(/\s+/g, ''), 'base64')
          : decodeQuotedPrintable(String(data).replace(/_/g, ' '));
      return decodeBuffer(buffer, charset);
    },
  );
}

function decodeParameter(value: string) {
  const unquoted = value.replace(/^"|"$/g, '');
  const rfc2231 = /^([^']*)''(.+)$/.exec(unquoted);
  if (rfc2231) {
    try {
      return decodeBuffer(
        Buffer.from(decodeURIComponent(rfc2231[2]), 'utf8'),
        rfc2231[1] || 'utf-8',
      );
    } catch {
      return decodeMimeWords(rfc2231[2]);
    }
  }
  return decodeMimeWords(unquoted);
}

function decodeBuffer(buffer: Buffer, charset: string) {
  const normalized = String(charset || 'utf-8')
    .trim()
    .toLowerCase();
  try {
    return new TextDecoder(normalized).decode(buffer);
  } catch {
    return buffer.toString('utf8');
  }
}

function parseAddress(value: string) {
  const decoded = decodeMimeWords(value).trim();
  const bracket = decoded.match(/^(.*?)<([^>]+)>/);
  if (bracket) {
    return {
      name: bracket[1].replace(/^"|"$/g, '').trim(),
      email: bracket[2].trim().toLowerCase(),
    };
  }
  const email =
    decoded.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0] || '';
  return {
    name: email
      ? decoded.replace(email, '').replace(/^"|"$/g, '').trim()
      : decoded,
    email: email.toLowerCase(),
  };
}

function normalizeMessageId(value: string) {
  return String(value || '')
    .trim()
    .replace(/^<|>$/g, '');
}

function parseDateHeader(value: string) {
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : null;
}

function stripHtml(value: string) {
  return String(value || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function imapString(value: string) {
  return `"${value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function lastResponseLine(text: string, tag: string) {
  const lines = text.trim().split(/\r?\n/).reverse();
  return (
    lines.find((line) => line.startsWith(tag)) ||
    lines[0] ||
    'IMAP command failed'
  );
}
