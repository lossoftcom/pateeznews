import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { renderLocalStorageHeadlineImage } from '@/lib/server/localStorageProxy';
import {
  fetchHeadlineSourceImage,
  headlineOutputSettings,
  normalizeHeadlinePlan,
  normalizeHeadlineTarget,
  renderHeadlineSvgFallback,
  safeHeadlineFilename,
} from '@/lib/server/headlineImage';

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'manage_content');
    const body = await request.json().catch(() => ({}));
    const languageCode = String(body?.languageCode || 'tr').trim() || 'tr';
    const target = normalizeHeadlineTarget(body?.target);
    const sourceMediaSrc = String(body?.source?.mediaSrc || '').trim();
    const sourceImage = await fetchHeadlineSourceImage({ request, src: sourceMediaSrc });
    const output = await headlineOutputSettings(languageCode);
    const plan = normalizeHeadlinePlan(body?.plan, target);
    const fileName = safeHeadlineFilename({
      stem: plan.media?.filenameStem || '',
      slug: body?.context?.slug || body?.context?.title || '',
      target,
      extension: output.extension,
    });

    const sourceBase64 = Buffer.from(sourceImage.bytes).toString('base64');
    let rendered: Record<string, any>;
    try {
      rendered = await renderLocalStorageHeadlineImage({
        sourceBase64,
        sourceMimeType: sourceImage.contentType,
        plan,
        target,
        outputFormat: output.format,
        maxBytes: output.maxBytes,
        fileName,
      });
    } catch (error) {
      if (!output.svgAllowed) throw error;
      rendered = renderHeadlineSvgFallback({
        sourceBase64,
        sourceMimeType: sourceImage.contentType,
        plan,
        target,
        maxBytes: output.maxBytes,
        fileName: safeHeadlineFilename({
          stem: plan.media?.filenameStem || '',
          slug: body?.context?.slug || body?.context?.title || '',
          target,
          extension: 'svg',
        }),
      });
    }

    const base64 = String(rendered?.base64 || '');
    if (!base64) throw Object.assign(new Error('Headline render returned empty output'), { status: 502 });
    const byteLength = Math.ceil((base64.length * 3) / 4);
    if (byteLength > output.maxBytes) {
      throw Object.assign(new Error('Rendered headline image exceeds upload limit'), { status: 413 });
    }

    return adminJson({
      success: true,
      base64,
      contentType: rendered?.contentType || output.contentType,
      fileName: rendered?.fileName || fileName,
    });
  } catch (error) {
    return adminError(error);
  }
};
