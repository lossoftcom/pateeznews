import type { NewsItem, SiteSettings } from '@/types';

export type PostUrlStructure = 'slug' | 'id';

export const getPostUrlStructure = (siteSettings?: SiteSettings | null): PostUrlStructure => (
  siteSettings?.content_post_url_structure === 'id' ? 'id' : 'slug'
);

export const getPostPathSegment = (
  post: Pick<NewsItem, 'id' | 'slug'> | null | undefined,
  siteSettings?: SiteSettings | null
) => {
  const id = String(post?.id || '').trim();
  const slug = String(post?.slug || '').trim();
  return getPostUrlStructure(siteSettings) === 'id' ? id : (slug || id);
};

export const getPostHref = (
  post: Pick<NewsItem, 'id' | 'slug'> | null | undefined,
  siteSettings?: SiteSettings | null
) => {
  const segment = getPostPathSegment(post, siteSettings);
  return segment ? `/haber/${encodeURIComponent(segment)}` : '/';
};
