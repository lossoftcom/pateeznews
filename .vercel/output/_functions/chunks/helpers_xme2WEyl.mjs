const formatTime = (seconds) => {
  if (isNaN(seconds)) return "00:00";
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
};
const isUUID = (str) => {
  if (!str) return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
};
const isPostId = (value) => {
  if (!value) return false;
  if (isUUID(value)) return true;
  return /^[0-9]+$/.test(value);
};
const getRelativeTime = (dateString, lang = "tr") => {
  if (!dateString) return "";
  const date = new Date(dateString);
  const now = /* @__PURE__ */ new Date();
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1e3);
  if (diffInSeconds < 60) return lang === "tr" ? "şimdi" : "just now";
  const diffInMinutes = Math.floor(diffInSeconds / 60);
  if (diffInMinutes < 60) return `${diffInMinutes} ${lang === "tr" ? "dk" : "min"}`;
  const diffInHours = Math.floor(diffInMinutes / 60);
  if (diffInHours < 24) return `${diffInHours} ${lang === "tr" ? "saat" : "hours"}`;
  const diffInDays = Math.floor(diffInHours / 24);
  if (diffInDays < 7) return `${diffInDays} ${lang === "tr" ? "gün" : "days"}`;
  return date.toLocaleDateString(lang === "tr" ? "tr-TR" : "en-US");
};
const TURKISH_CHAR_MAP = {
  "Ç": "c",
  "ç": "c",
  "Ğ": "g",
  "ğ": "g",
  "İ": "i",
  "ı": "i",
  "Ö": "o",
  "ö": "o",
  "Ş": "s",
  "ş": "s",
  "Ü": "u",
  "ü": "u"
};
const slugify = (input) => {
  if (!input) return "";
  const mapped = input.split("").map((ch) => TURKISH_CHAR_MAP[ch] || ch).join("");
  return mapped.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
};

export { formatTime as f, getRelativeTime as g, isPostId as i, slugify as s };
