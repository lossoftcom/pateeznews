import { dbQuery } from './supabaseDb';
import { ensureAppSchema } from './appDb';

type QueryMethod = 'select' | 'insert' | 'update' | 'delete' | 'upsert';
type SingleMode = 'single' | 'maybeSingle' | null;

export type QueryFilter =
  | { type: 'comparison'; op: 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'like' | 'ilike' | 'is' | 'in'; column: string; value: any }
  | { type: 'not'; column: string; operator: string; value: any }
  | { type: 'or'; value: string };

export interface QuerySpec {
  table: string;
  schema?: string;
  method: QueryMethod;
  select?: string;
  values?: any;
  filters?: QueryFilter[];
  orders?: Array<{ column: string; ascending?: boolean }>;
  limit?: number;
  range?: { from: number; to: number };
  single?: SingleMode;
  count?: 'exact' | null;
  head?: boolean;
  options?: Record<string, any>;
  requiredColumns?: string[];
}

export interface QueryResult {
  data: any;
  error: { message: string; code?: string } | null;
  count?: number | null;
}

interface SqlState {
  values: any[];
}

interface RelationSelect {
  alias: string;
  token: string;
  innerSelect: string;
}

interface ParsedSelect {
  star: boolean;
  baseColumns: string[];
  relations: RelationSelect[];
}

interface RelationDefinition {
  aliases: string[];
  targetTable: string;
  localColumn: string;
  targetColumn: string;
  cardinality: 'one' | 'many';
}

const PUBLIC_SCHEMA = 'public';
const JSON_COLUMNS: Record<string, Set<string>> = {
  posts: new Set(['card_data', 'items', 'faq_data']),
  pages: new Set(['content_delta']),
  profiles: new Set(['social_links']),
  site_fonts: new Set(['font_files']),
  site_settings: new Set(['site_font_sizes']),
  stories: new Set(['story_data']),
};

const RELATIONS: Record<string, RelationDefinition[]> = {
  posts: [
    {
      aliases: ['profiles', 'profiles:publisher_id', 'publisher_id'],
      targetTable: 'profiles',
      localColumn: 'publisher_id',
      targetColumn: 'id',
      cardinality: 'one',
    },
  ],
  comments: [
    {
      aliases: ['profiles', 'profiles:user_id', 'user_id'],
      targetTable: 'profiles',
      localColumn: 'user_id',
      targetColumn: 'id',
      cardinality: 'one',
    },
  ],
  navigation_items: [
    {
      aliases: ['navigation_menus', 'navigation_menus!inner'],
      targetTable: 'navigation_menus',
      localColumn: 'menu_id',
      targetColumn: 'id',
      cardinality: 'one',
    },
  ],
  publisher_users: [
    {
      aliases: ['profiles', 'profiles!publisher_users_user_id_fkey'],
      targetTable: 'profiles',
      localColumn: 'user_id',
      targetColumn: 'id',
      cardinality: 'one',
    },
    {
      aliases: ['publisher', 'profiles!publisher_users_publisher_id_fkey'],
      targetTable: 'profiles',
      localColumn: 'publisher_id',
      targetColumn: 'id',
      cardinality: 'one',
    },
  ],
  publisher_categories: [
    {
      aliases: ['navigation_items'],
      targetTable: 'navigation_items',
      localColumn: 'category_id',
      targetColumn: 'id',
      cardinality: 'one',
    },
  ],
  profiles: [
    {
      aliases: ['publisher_users', 'publisher_users!publisher_users_user_id_fkey'],
      targetTable: 'publisher_users',
      localColumn: 'id',
      targetColumn: 'user_id',
      cardinality: 'many',
    },
  ],
};

function quoteIdent(identifier: string) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(identifier)) {
    throw new Error(`Unsafe SQL identifier: ${identifier}`);
  }
  return `"${identifier}"`;
}

function tableSql(schema: string | undefined, table: string) {
  return `${quoteIdent(schema || PUBLIC_SCHEMA)}.${quoteIdent(table)}`;
}

function pushValue(state: SqlState, value: any) {
  state.values.push(value);
  return `$${state.values.length}`;
}

function splitTopLevel(input: string, delimiter = ',') {
  const parts: string[] = [];
  let depth = 0;
  let current = '';

  for (const char of input) {
    if (char === '(') depth += 1;
    if (char === ')') depth -= 1;
    if (char === delimiter && depth === 0) {
      if (current.trim()) parts.push(current.trim());
      current = '';
      continue;
    }
    current += char;
  }

  if (current.trim()) parts.push(current.trim());
  return parts;
}

function parseRelationHeader(header: string): { alias: string; token: string } {
  const colonIndex = header.indexOf(':');
  if (colonIndex >= 0) {
    const alias = header.slice(0, colonIndex).trim();
    const token = header.slice(colonIndex + 1).trim();
    return { alias, token };
  }

  const alias = header.split('!')[0].trim();
  return { alias, token: header.trim() };
}

function parseSelect(select = '*'): ParsedSelect {
  const parsed: ParsedSelect = { star: false, baseColumns: [], relations: [] };
  const parts = splitTopLevel(select.replace(/\s+/g, ' ').trim());

  for (const part of parts) {
    if (part === '*') {
      parsed.star = true;
      continue;
    }

    const openIndex = part.indexOf('(');
    if (openIndex > 0 && part.endsWith(')')) {
      const header = part.slice(0, openIndex).trim();
      const innerSelect = part.slice(openIndex + 1, -1).trim();
      const { alias, token } = parseRelationHeader(header);
      parsed.relations.push({ alias, token, innerSelect });
      continue;
    }

    parsed.baseColumns.push(part.trim());
  }

  return parsed;
}

function findRelation(table: string, relation: RelationSelect) {
  const defs = RELATIONS[table] || [];
  return defs.find((def) => def.aliases.includes(relation.token) || def.aliases.includes(relation.alias));
}

function normalizePayload(payload: any) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return payload;
  return Object.fromEntries(
    Object.entries(payload).filter(([, value]) => value !== undefined)
  );
}

function prepareMutationValue(table: string, column: string, value: any) {
  if (value === undefined) return null;
  if (value === null) return null;
  if (!JSON_COLUMNS[table]?.has(column)) return value;

  if (typeof value === 'string') {
    try {
      JSON.parse(value);
      return value;
    } catch {
      return JSON.stringify(value);
    }
  }

  return JSON.stringify(value);
}

function parseOrCondition(raw: string, state: SqlState) {
  const match = raw.match(/^([A-Za-z_][A-Za-z0-9_]*)\.(eq|neq|gt|gte|lt|lte|like|ilike|is)\.(.*)$/);
  if (!match) {
    throw new Error(`Unsupported OR condition: ${raw}`);
  }
  const [, column, op, rawValue] = match;
  const value = rawValue === 'null' ? null : rawValue;
  return comparisonSql({ type: 'comparison', column, op: op as any, value }, state);
}

function comparisonSql(filter: Extract<QueryFilter, { type: 'comparison' }>, state: SqlState) {
  const column = quoteIdent(filter.column);

  switch (filter.op) {
    case 'eq':
      return `${column} = ${pushValue(state, filter.value)}`;
    case 'neq':
      return `${column} <> ${pushValue(state, filter.value)}`;
    case 'gt':
      return `${column} > ${pushValue(state, filter.value)}`;
    case 'gte':
      return `${column} >= ${pushValue(state, filter.value)}`;
    case 'lt':
      return `${column} < ${pushValue(state, filter.value)}`;
    case 'lte':
      return `${column} <= ${pushValue(state, filter.value)}`;
    case 'like':
      return `${column} LIKE ${pushValue(state, filter.value)}`;
    case 'ilike':
      return `${column} ILIKE ${pushValue(state, filter.value)}`;
    case 'is':
      if (filter.value === null) return `${column} IS NULL`;
      if (filter.value === true) return `${column} IS TRUE`;
      if (filter.value === false) return `${column} IS FALSE`;
      return `${column} IS NOT DISTINCT FROM ${pushValue(state, filter.value)}`;
    case 'in':
      return `${column} = ANY(${pushValue(state, filter.value || [])})`;
    default:
      throw new Error(`Unsupported filter operator: ${filter.op}`);
  }
}

function notSql(filter: Extract<QueryFilter, { type: 'not' }>, state: SqlState) {
  const column = quoteIdent(filter.column);
  if (filter.operator === 'is' && filter.value === null) return `${column} IS NOT NULL`;
  if (filter.operator === 'eq') return `${column} <> ${pushValue(state, filter.value)}`;
  if (filter.operator === 'ilike') return `${column} NOT ILIKE ${pushValue(state, filter.value)}`;
  if (filter.operator === 'like') return `${column} NOT LIKE ${pushValue(state, filter.value)}`;
  throw new Error(`Unsupported NOT operator: ${filter.operator}`);
}

function whereSql(filters: QueryFilter[] | undefined, state: SqlState) {
  if (!filters?.length) return '';

  const clauses = filters.map((filter) => {
    if (filter.type === 'comparison') return comparisonSql(filter, state);
    if (filter.type === 'not') return notSql(filter, state);
    const orClauses = splitTopLevel(filter.value).map((part) => parseOrCondition(part, state));
    return `(${orClauses.join(' OR ')})`;
  });

  return ` WHERE ${clauses.join(' AND ')}`;
}

function orderSql(orders: QuerySpec['orders']) {
  if (!orders?.length) return '';
  return ` ORDER BY ${orders
    .map((order) => `${quoteIdent(order.column)} ${order.ascending === false ? 'DESC' : 'ASC'}`)
    .join(', ')}`;
}

function limitSql(spec: QuerySpec, state: SqlState) {
  if (spec.range) {
    const limit = Math.max(0, spec.range.to - spec.range.from + 1);
    return ` LIMIT ${pushValue(state, limit)} OFFSET ${pushValue(state, spec.range.from)}`;
  }
  if (typeof spec.limit === 'number') return ` LIMIT ${pushValue(state, spec.limit)}`;
  return '';
}

function getConflictColumns(table: string, options?: Record<string, any>) {
  if (typeof options?.onConflict === 'string' && options.onConflict.trim()) {
    return options.onConflict.split(',').map((column: string) => column.trim()).filter(Boolean);
  }

  const fallback: Record<string, string[]> = {
    languages: ['code'],
    language_translations: ['language_code', 'key'],
    profiles: ['id'],
    posts: ['id'],
    site_fonts: ['id'],
    site_settings: ['language_code'],
    publisher_users: ['publisher_id', 'user_id'],
  };
  return fallback[table] || ['id'];
}

function columnsForSelect(spec: QuerySpec, parsed: ParsedSelect) {
  if (parsed.star) return '*';

  const columns = new Set<string>(parsed.baseColumns);
  for (const column of spec.requiredColumns || []) columns.add(column);

  for (const relation of parsed.relations) {
    const definition = findRelation(spec.table, relation);
    if (definition) columns.add(definition.localColumn);
  }

  if (!columns.size) columns.add('id');
  return Array.from(columns).map(quoteIdent).join(', ');
}

async function hydrateRows(table: string, rows: any[], relations: RelationSelect[]) {
  if (!rows.length || !relations.length) return rows;

  for (const relation of relations) {
    const definition = findRelation(table, relation);
    if (!definition) continue;

    const ids = Array.from(new Set(rows.map((row) => row[definition.localColumn]).filter((value) => value !== null && value !== undefined)));
    if (!ids.length) {
      for (const row of rows) row[relation.alias] = definition.cardinality === 'many' ? [] : null;
      continue;
    }

    const targetResult = await executeQuerySpec({
      table: definition.targetTable,
      method: 'select',
      select: relation.innerSelect || '*',
      filters: [{ type: 'comparison', op: 'in', column: definition.targetColumn, value: ids }],
      requiredColumns: [definition.targetColumn],
    });

    if (targetResult.error) throw new Error(targetResult.error.message);

    const targetRows = Array.isArray(targetResult.data) ? targetResult.data : [];
    const grouped = new Map<any, any[]>();
    for (const targetRow of targetRows) {
      const key = targetRow[definition.targetColumn];
      if (!grouped.has(key)) grouped.set(key, []);
      grouped.get(key)!.push(targetRow);
    }

    for (const row of rows) {
      const matches = grouped.get(row[definition.localColumn]) || [];
      row[relation.alias] = definition.cardinality === 'many' ? matches : (matches[0] || null);
    }
  }

  return rows;
}

async function runSelect(spec: QuerySpec): Promise<QueryResult> {
  const parsed = parseSelect(spec.select || '*');
  const state: SqlState = { values: [] };
  const from = tableSql(spec.schema, spec.table);
  const where = whereSql(spec.filters, state);
  const countPromise = spec.count === 'exact'
    ? dbQuery<{ count: string }>(`SELECT COUNT(*)::bigint AS count FROM ${from}${where}`, state.values.slice())
    : null;

  if (spec.head) {
    const countResult = countPromise ? await countPromise : null;
    return { data: null, error: null, count: countResult ? Number(countResult.rows[0]?.count || 0) : null };
  }

  const sql = [
    `SELECT ${columnsForSelect(spec, parsed)} FROM ${from}`,
    where,
    orderSql(spec.orders),
    limitSql(spec, state),
  ].join('');

  const [result, countResult] = await Promise.all([
    dbQuery(sql, state.values),
    countPromise,
  ]);

  const rows = await hydrateRows(spec.table, result.rows, parsed.relations);
  const count = countResult ? Number(countResult.rows[0]?.count || 0) : null;

  if (spec.single === 'single') {
    if (rows.length !== 1) {
      return { data: null, error: { message: `Expected one row, received ${rows.length}` }, count };
    }
    return { data: rows[0], error: null, count };
  }

  if (spec.single === 'maybeSingle') {
    if (rows.length > 1) {
      return { data: null, error: { message: `Expected zero or one row, received ${rows.length}` }, count };
    }
    return { data: rows[0] || null, error: null, count };
  }

  return { data: rows, error: null, count };
}

function rowsFromValues(values: any) {
  return (Array.isArray(values) ? values : [values]).map(normalizePayload);
}

function returningSql(spec: QuerySpec) {
  if (spec.select === undefined) return ' RETURNING *';
  const parsed = parseSelect(spec.select);
  if (parsed.star) return ' RETURNING *';
  if (!parsed.baseColumns.length) return '';
  return ` RETURNING ${parsed.baseColumns.map(quoteIdent).join(', ')}`;
}

async function runInsert(spec: QuerySpec): Promise<QueryResult> {
  const rows = rowsFromValues(spec.values);
  if (!rows.length) return { data: [], error: null, count: null };

  const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))));
  const state: SqlState = { values: [] };
  const valuesSql = rows
    .map((row) => `(${columns.map((column) => pushValue(state, prepareMutationValue(spec.table, column, row[column]))).join(', ')})`)
    .join(', ');

  const sql = `INSERT INTO ${tableSql(spec.schema, spec.table)} (${columns.map(quoteIdent).join(', ')}) VALUES ${valuesSql}${returningSql(spec)}`;
  const result = await dbQuery(sql, state.values);
  return finishMutationResult(spec, result.rows);
}

async function runUpdate(spec: QuerySpec): Promise<QueryResult> {
  const payload = normalizePayload(spec.values);
  const columns = Object.keys(payload || {});
  if (!columns.length) return { data: [], error: null, count: null };
  if (!spec.filters?.length) {
    return { data: null, error: { message: 'Update requires at least one filter' }, count: null };
  }

  const state: SqlState = { values: [] };
  const setSql = columns.map((column) => `${quoteIdent(column)} = ${pushValue(state, prepareMutationValue(spec.table, column, payload[column]))}`).join(', ');
  const where = whereSql(spec.filters, state);
  const sql = `UPDATE ${tableSql(spec.schema, spec.table)} SET ${setSql}${where}${returningSql(spec)}`;
  const result = await dbQuery(sql, state.values);
  return finishMutationResult(spec, result.rows);
}

async function runDelete(spec: QuerySpec): Promise<QueryResult> {
  if (!spec.filters?.length) {
    return { data: null, error: { message: 'Delete requires at least one filter' }, count: null };
  }
  const state: SqlState = { values: [] };
  const where = whereSql(spec.filters, state);
  const sql = `DELETE FROM ${tableSql(spec.schema, spec.table)}${where}${returningSql(spec)}`;
  const result = await dbQuery(sql, state.values);
  return finishMutationResult(spec, result.rows);
}

async function runUpsert(spec: QuerySpec): Promise<QueryResult> {
  const rows = rowsFromValues(spec.values);
  if (!rows.length) return { data: [], error: null, count: null };

  const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))));
  const conflictColumns = getConflictColumns(spec.table, spec.options);
  const updateColumns = columns.filter((column) => !conflictColumns.includes(column));
  const state: SqlState = { values: [] };
  const valuesSql = rows
    .map((row) => `(${columns.map((column) => pushValue(state, prepareMutationValue(spec.table, column, row[column]))).join(', ')})`)
    .join(', ');
  const conflictSql = updateColumns.length
    ? `DO UPDATE SET ${updateColumns.map((column) => `${quoteIdent(column)} = EXCLUDED.${quoteIdent(column)}`).join(', ')}`
    : 'DO NOTHING';

  const sql = `INSERT INTO ${tableSql(spec.schema, spec.table)} (${columns.map(quoteIdent).join(', ')}) VALUES ${valuesSql} ON CONFLICT (${conflictColumns.map(quoteIdent).join(', ')}) ${conflictSql}${returningSql(spec)}`;
  const result = await dbQuery(sql, state.values);
  return finishMutationResult(spec, result.rows);
}

function finishMutationResult(spec: QuerySpec, rows: any[]): QueryResult {
  if (spec.single === 'single') return { data: rows[0] || null, error: rows[0] ? null : { message: 'No row returned' }, count: null };
  if (spec.single === 'maybeSingle') return { data: rows[0] || null, error: rows.length > 1 ? { message: `Expected zero or one row, received ${rows.length}` } : null, count: null };
  return { data: rows, error: null, count: null };
}

export async function executeRpc(name: string, args: Record<string, any> = {}): Promise<QueryResult> {
  try {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) throw new Error(`Unsafe RPC name: ${name}`);
    const state: SqlState = { values: [] };
    const values = Object.values(args);
    const params = values.map((value) => pushValue(state, value)).join(', ');
    const result = await dbQuery(`SELECT ${tableSql(PUBLIC_SCHEMA, name)}(${params}) AS result`, state.values);
    return { data: result.rows[0]?.result ?? null, error: null, count: null };
  } catch (error: any) {
    return { data: null, error: { message: error.message || 'RPC failed' }, count: null };
  }
}

export async function executeQuerySpec(spec: QuerySpec): Promise<QueryResult> {
  try {
    await ensureAppSchema();
    switch (spec.method) {
      case 'select':
        return await runSelect(spec);
      case 'insert':
        return await runInsert(spec);
      case 'update':
        return await runUpdate(spec);
      case 'delete':
        return await runDelete(spec);
      case 'upsert':
        return await runUpsert(spec);
      default:
        throw new Error(`Unsupported query method: ${(spec as any).method}`);
    }
  } catch (error: any) {
    return { data: null, error: { message: error.message || 'Query failed' }, count: null };
  }
}
