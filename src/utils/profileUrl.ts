export const getProfileHref = (handle: unknown) => {
  const clean = String(handle || '').trim().replace(/^@+/, '');
  return clean ? `/profil/${encodeURIComponent(clean)}` : '';
};
