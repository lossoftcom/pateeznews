type Filter =
  | { type: 'comparison'; op: 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'like' | 'ilike' | 'is' | 'in'; column: string; value: any }
  | { type: 'not'; column: string; operator: string; value: any }
  | { type: 'or'; value: string };

type QueryMethod = 'select' | 'insert' | 'update' | 'delete' | 'upsert';

interface QuerySpec {
  table: string;
  method: QueryMethod;
  select?: string;
  values?: any;
  filters: Filter[];
  orders: Array<{ column: string; ascending?: boolean }>;
  limit?: number;
  range?: { from: number; to: number };
  single?: 'single' | 'maybeSingle' | null;
  count?: 'exact' | null;
  head?: boolean;
  options?: Record<string, any>;
}

export interface User {
  id: string;
  email?: string | null;
  role?: string | null;
  aud?: string | null;
  user_metadata?: Record<string, any>;
  app_metadata?: Record<string, any>;
}

export interface Session {
  access_token: string;
  token_type: 'bearer';
  expires_at: number;
  user: User;
}

type AuthEvent = 'SIGNED_IN' | 'SIGNED_OUT' | 'TOKEN_REFRESHED' | 'USER_UPDATED' | 'INITIAL_SESSION';
type AuthListener = (event: AuthEvent, session: Session | null) => void;

const AUTH_STORAGE_KEY = 'neon-auth-token';
const authListeners = new Set<AuthListener>();

async function executeQuery(spec: QuerySpec) {
  if (import.meta.env.SSR) {
    const { executeQuerySpec } = await import('./server/neonQuery');
    return executeQuerySpec(spec as any);
  }

  const response = await fetch('/api/neon/query', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(spec),
  });
  return response.json();
}

async function executeRpc(name: string, args?: Record<string, any>) {
  if (import.meta.env.SSR) {
    const { executeRpc } = await import('./server/neonQuery');
    return executeRpc(name, args || {});
  }

  const response = await fetch('/api/neon/query', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ kind: 'rpc', name, args: args || {} }),
  });
  return response.json();
}

class NeonQueryBuilder implements PromiseLike<any> {
  private spec: QuerySpec;

  constructor(table: string) {
    this.spec = {
      table,
      method: 'select',
      filters: [],
      orders: [],
      single: null,
      count: null,
    };
  }

  select(columns = '*', options?: { count?: 'exact'; head?: boolean }) {
    this.spec.select = columns;
    if (!['insert', 'update', 'delete', 'upsert'].includes(this.spec.method)) {
      this.spec.method = 'select';
    }
    this.spec.count = options?.count || null;
    this.spec.head = options?.head || false;
    return this;
  }

  insert(values: any) {
    this.spec.method = 'insert';
    this.spec.values = values;
    return this;
  }

  update(values: any) {
    this.spec.method = 'update';
    this.spec.values = values;
    return this;
  }

  upsert(values: any, options?: Record<string, any>) {
    this.spec.method = 'upsert';
    this.spec.values = values;
    this.spec.options = options || {};
    return this;
  }

  delete() {
    this.spec.method = 'delete';
    return this;
  }

  eq(column: string, value: any) { return this.addComparison('eq', column, value); }
  neq(column: string, value: any) { return this.addComparison('neq', column, value); }
  gt(column: string, value: any) { return this.addComparison('gt', column, value); }
  gte(column: string, value: any) { return this.addComparison('gte', column, value); }
  lt(column: string, value: any) { return this.addComparison('lt', column, value); }
  lte(column: string, value: any) { return this.addComparison('lte', column, value); }
  like(column: string, value: any) { return this.addComparison('like', column, value); }
  ilike(column: string, value: any) { return this.addComparison('ilike', column, value); }
  is(column: string, value: any) { return this.addComparison('is', column, value); }
  in(column: string, value: any[]) { return this.addComparison('in', column, value); }

  not(column: string, operator: string, value: any) {
    this.spec.filters.push({ type: 'not', column, operator, value });
    return this;
  }

  or(value: string) {
    this.spec.filters.push({ type: 'or', value });
    return this;
  }

  filter(column: string, operator: string, value: any) {
    if (operator === 'eq') return this.eq(column, value);
    if (operator === 'neq') return this.neq(column, value);
    if (operator === 'gt') return this.gt(column, value);
    if (operator === 'gte') return this.gte(column, value);
    if (operator === 'lt') return this.lt(column, value);
    if (operator === 'lte') return this.lte(column, value);
    if (operator === 'like') return this.like(column, value);
    if (operator === 'ilike') return this.ilike(column, value);
    if (operator === 'is') return this.is(column, value);
    return this;
  }

  order(column: string, options?: { ascending?: boolean }) {
    this.spec.orders.push({ column, ascending: options?.ascending });
    return this;
  }

  limit(count: number) {
    this.spec.limit = count;
    return this;
  }

  range(from: number, to: number) {
    this.spec.range = { from, to };
    return this;
  }

  abortSignal() {
    return this;
  }

  single() {
    this.spec.single = 'single';
    return this.execute();
  }

  maybeSingle() {
    this.spec.single = 'maybeSingle';
    return this.execute();
  }

  then<TResult1 = any, TResult2 = never>(
    onfulfilled?: ((value: any) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): PromiseLike<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }

  private addComparison(op: Extract<Filter, { type: 'comparison' }>['op'], column: string, value: any) {
    this.spec.filters.push({ type: 'comparison', op, column, value });
    return this;
  }

  private execute() {
    return executeQuery(this.spec);
  }
}

function readStoredSession(): Session | null {
  if (import.meta.env.SSR) return null;
  try {
    const stored = localStorage.getItem(AUTH_STORAGE_KEY);
    return stored ? JSON.parse(stored) as Session : null;
  } catch {
    return null;
  }
}

function writeStoredSession(session: Session | null) {
  if (import.meta.env.SSR) return;
  try {
    for (const key of Object.keys(localStorage)) {
      if ((key.startsWith('sb-') || key.startsWith('neon-')) && key.endsWith('-auth-token') && key !== AUTH_STORAGE_KEY) {
        localStorage.removeItem(key);
      }
    }
    if (session) {
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(session));
      document.cookie = `${AUTH_STORAGE_KEY}=${encodeURIComponent(session.access_token)}; path=/; max-age=${60 * 60 * 24 * 30}; SameSite=Lax`;
    } else {
      localStorage.removeItem(AUTH_STORAGE_KEY);
      document.cookie = `${AUTH_STORAGE_KEY}=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax`;
    }
  } catch { }
}

function notifyAuth(event: AuthEvent, session: Session | null) {
  for (const listener of authListeners) listener(event, session);
}

async function authRequest(action: string, payload: Record<string, any> = {}) {
  const response = await fetch('/api/neon/auth', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, ...payload }),
  });
  return response.json();
}

const auth = {
  async getSession() {
    if (import.meta.env.SSR) return { data: { session: null }, error: null };
    const stored = readStoredSession();
    if (!stored?.access_token) return { data: { session: null }, error: null };

    const result = await authRequest('getSession', { token: stored.access_token });
    const session = result?.data?.session || null;
    writeStoredSession(session);
    return { data: { session }, error: result.error || null };
  },

  async getUser() {
    const { data, error } = await auth.getSession();
    return { data: { user: data.session?.user || null }, error };
  },

  async signInWithPassword({ email, password }: { email: string; password: string }) {
    const result = await authRequest('signInWithPassword', { email, password });
    const session = result?.data?.session || null;
    if (session) {
      writeStoredSession(session);
      notifyAuth('SIGNED_IN', session);
    }
    return result;
  },

  async signUp({ email, password, options }: { email: string; password: string; options?: { data?: Record<string, any> } }) {
    const result = await authRequest('signUp', { email, password, data: options?.data || {} });
    const session = result?.data?.session || null;
    if (session) {
      writeStoredSession(session);
      notifyAuth('SIGNED_IN', session);
    }
    return result;
  },

  async signOut() {
    writeStoredSession(null);
    notifyAuth('SIGNED_OUT', null);
    return { error: null };
  },

  async updateUser(attrs: { password?: string; email?: string }) {
    const session = readStoredSession();
    const result = await authRequest('updateUser', { token: session?.access_token, attrs });
    if (!result.error) notifyAuth('USER_UPDATED', session);
    return result;
  },

  onAuthStateChange(callback: AuthListener) {
    authListeners.add(callback);
    queueMicrotask(() => callback('INITIAL_SESSION', readStoredSession()));
    return {
      data: {
        subscription: {
          unsubscribe: () => authListeners.delete(callback),
        },
      },
    };
  },
};

function createNoopChannel() {
  return {
    on(..._args: any[]) {
      return this;
    },
    subscribe(callback?: (status: string) => void) {
      callback?.('SUBSCRIBED');
      return this;
    },
    unsubscribe() {
      return Promise.resolve('ok');
    },
  };
}

export const neon = {
  from(table: string) {
    return new NeonQueryBuilder(table);
  },
  rpc(name: string, args?: Record<string, any>) {
    return executeRpc(name, args);
  },
  auth,
  channel(..._args: any[]) {
    return createNoopChannel();
  },
  removeChannel(channel: { unsubscribe?: () => Promise<string> | string }) {
    channel?.unsubscribe?.();
    return Promise.resolve('ok');
  },
};
