// getFonts apiCallback.
//
// The editor was built against @googleforcreators/fonts; its fonts.json is the
// exact catalog the WordPress plugin serves from its `getFonts` endpoint, so we
// return it verbatim. The editor keys fonts by `family`, so no remapping is
// needed.
import GOOGLE_FONTS from '@googleforcreators/fonts/fonts.json';

// The font provider calls getFonts() for the curated/Google list and
// getFonts({ service: 'custom' }) for user-uploaded fonts (none in this embed).
export async function getFonts({ service } = {}) {
  if (service === 'custom') return [];
  return GOOGLE_FONTS;
}
