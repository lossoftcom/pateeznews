const normalizeCandidate = (value) => {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  return raw.toLowerCase();
};
const parseAcceptLanguage = (header) => {
  const raw = String(header ?? "").trim();
  if (!raw) return [];
  const parsed = [];
  for (const part of raw.split(",")) {
    const section = part.trim();
    if (!section) continue;
    const [tagRaw, ...params] = section.split(";").map((s) => s.trim());
    const tag = normalizeCandidate(tagRaw);
    if (!tag) continue;
    let q = 1;
    for (const param of params) {
      if (!param.toLowerCase().startsWith("q=")) continue;
      const candidate = Number.parseFloat(param.slice(2));
      if (!Number.isNaN(candidate)) q = candidate;
    }
    parsed.push({ tag, q });
  }
  parsed.sort((a, b) => b.q - a.q);
  return parsed.map((entry) => entry.tag);
};
const resolveLangCode = (options) => {
  const byLower = /* @__PURE__ */ new Map();
  const supportedList = Array.isArray(options.supported) ? options.supported : [];
  for (const lang of supportedList) {
    const code = String(lang?.code ?? "").trim();
    if (!code) continue;
    byLower.set(code.toLowerCase(), code);
  }
  const supportedDefault = supportedList.find((l) => !!l?.isDefault)?.code || supportedList[0]?.code || "";
  const fallback = String(options.fallback ?? supportedDefault ?? "tr").trim() || "tr";
  const candidates = [
    options.urlLang,
    options.cookieLang,
    ...parseAcceptLanguage(options.acceptLanguageHeader)
  ];
  for (const candidate of candidates) {
    const normalized = normalizeCandidate(candidate);
    if (!normalized) continue;
    const direct = byLower.get(normalized);
    if (direct) return direct;
    const base = normalized.split(/[-_]/)[0];
    if (base && base !== normalized) {
      const baseMatch = byLower.get(base);
      if (baseMatch) return baseMatch;
    }
  }
  return fallback;
};

export { resolveLangCode as r };
