ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS show_in_manset boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS posts_manset_feed_idx
  ON public.posts (language_code, status, published_at DESC)
  WHERE show_in_manset IS TRUE;
