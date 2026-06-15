BEGIN;

ALTER TABLE public.pages
  ADD COLUMN IF NOT EXISTS page_group text NOT NULL DEFAULT 'Kurumsal';

ALTER TABLE public.pages
  ALTER COLUMN page_group SET DEFAULT 'Kurumsal';

UPDATE public.pages
SET
  page_group = 'Kurumsal',
  updated_at = now()
WHERE page_group IS NULL
   OR btrim(page_group) = '';

ALTER TABLE public.pages
  ALTER COLUMN page_group SET NOT NULL;

CREATE INDEX IF NOT EXISTS pages_group_idx
  ON public.pages USING btree (language_code, category_id, page_group, menu_order);

COMMIT;
