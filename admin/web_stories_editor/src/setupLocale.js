// MUST be imported before any @googleforcreators/* module so that module-level
// __()/_x() calls (e.g. the Insert/Style tab labels, element names) resolve
// against the Turkish catalog. ES module imports evaluate in order, so importing
// this first in main.jsx guarantees the locale is set before the editor loads.
import { setLocaleData } from '@googleforcreators/i18n';

import trMessages from './i18n/tr.json'; // official tr_TR (translate.wordpress.org)
import trExtra from './i18n/tr-extra.json'; // Turkish for every string the official catalog left untranslated

// The editor's default i18n domain is "web-stories"; setLocaleData merges our
// catalog into it while keeping the built-in plural function. trExtra fills the
// gaps so no UI string remains in English.
setLocaleData({
  locale_data: { 'web-stories': { ...trMessages, ...trExtra } },
});
