import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { geminiFastModelAttempts, geminiThinkingConfigForModel, isGeminiFallbackWorthTrying, normalizeGeminiModelName } from '@/lib/geminiModelFallback';
import {
  fetchHeadlineAiSettings,
  fetchHeadlinePrompt,
  fetchHeadlineSourceImage,
  normalizeHeadlinePlan,
  normalizeHeadlineTarget,
} from '@/lib/server/headlineImage';

const AI_TIMEOUT_MS = 28_000;

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'manage_content');
    const body = await request.json().catch(() => ({}));
    const languageCode = String(body?.languageCode || 'tr').trim() || 'tr';
    const promptId = String(body?.promptId || '').trim();
    const target = normalizeHeadlineTarget(body?.target);
    if (!promptId) return adminJson({ error: 'Headline prompt is required' }, 400);

    const settings = await fetchHeadlineAiSettings(languageCode);
    if (settings?.google_ai_active !== true) {
      return adminJson({ error: 'Google AI is disabled' }, 400);
    }
    const apiKey = String(settings.google_ai_api_key || '').trim();
    if (!apiKey) return adminJson({ error: 'Google AI API key is not configured' }, 400);

    const prompt = await fetchHeadlinePrompt(promptId, languageCode);
    if (!prompt?.prompt?.trim()) {
      return adminJson({ error: 'Headline prompt was not found or is inactive' }, 404);
    }

    const sourceMediaSrc = String(body?.source?.mediaSrc || '').trim();
    const sourceImage = await fetchHeadlineSourceImage({ request, src: sourceMediaSrc });
    const model = normalizeGeminiModelName(settings.google_ai_model) || 'gemini-2.5-flash';
    const plan = await generateHeadlinePlan({
      apiKey,
      model,
      systemPrompt: prompt.prompt,
      target,
      context: body?.context || {},
      source: body?.source || {},
      sourceImage,
    });

    return adminJson({ success: true, plan: normalizeHeadlinePlan(plan, target) });
  } catch (error) {
    return adminError(error);
  }
};

async function generateHeadlinePlan(input: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  target: string;
  context: any;
  source: any;
  sourceImage: { bytes: Uint8Array; contentType: string };
}) {
  const userPrompt = buildUserPrompt(input.target, input.context, input.source);
  let lastError: { status?: number; message?: unknown } | null = null;
  for (const modelId of geminiFastModelAttempts(input.model)) {
    try {
      const payload = buildGeminiPayload({
        model: modelId,
        systemPrompt: input.systemPrompt,
        userPrompt,
        sourceImage: input.sourceImage,
      });
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(input.apiKey)}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(AI_TIMEOUT_MS),
        },
      );
      const decoded = await response.json().catch(() => ({}));
      if (!response.ok || decoded?.error) {
        lastError = {
          status: response.status,
          message: decoded?.error?.message || `Gemini HTTP ${response.status}`,
        };
        if (isGeminiFallbackWorthTrying(lastError.status, lastError.message)) continue;
        break;
      }
      return extractPlanJson(decoded);
    } catch (error: any) {
      lastError = {
        status: error?.name === 'TimeoutError' ? 408 : 0,
        message: error?.message || 'Gemini request failed',
      };
      if (isGeminiFallbackWorthTrying(lastError.status, lastError.message)) continue;
      break;
    }
  }
  throw Object.assign(
    new Error(String(lastError?.message || 'Headline AI plan failed')),
    { status: lastError?.status && lastError.status >= 400 ? lastError.status : 502 },
  );
}

function buildGeminiPayload(input: {
  model: string;
  systemPrompt: string;
  userPrompt: string;
  sourceImage: { bytes: Uint8Array; contentType: string };
}) {
  const generationConfig: Record<string, unknown> = {
    candidateCount: 1,
    temperature: 0.18,
    topP: 0.85,
    maxOutputTokens: 2200,
    responseMimeType: 'application/json',
    responseJsonSchema: headlinePlanSchema(),
  };
  const thinkingConfig = geminiThinkingConfigForModel(input.model);
  if (thinkingConfig) generationConfig.thinkingConfig = thinkingConfig;

  return {
    system_instruction: {
      parts: [{ text: input.systemPrompt }],
    },
    contents: [
      {
        role: 'user',
        parts: [
          { text: input.userPrompt },
          {
            inlineData: {
              mimeType: input.sourceImage.contentType,
              data: Buffer.from(input.sourceImage.bytes).toString('base64'),
            },
          },
        ],
      },
    ],
    generationConfig,
  };
}

function buildUserPrompt(target: string, context: any, source: any) {
  const clean = (value: unknown, max: number) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
  return [
    `Hedef format: ${target}`,
    `Haber başlığı: ${clean(context?.title, 180)}`,
    `Kısa özet: ${clean(context?.summary, 320)}`,
    `Kategori yolu: ${clean(context?.categoryPath, 120)}`,
    `Yayın tarihi: ${clean(context?.publishedAt, 80)}`,
    `Slug: ${clean(context?.slug, 100)}`,
    `Editör notu: ${clean(context?.editorNotes, 600)}`,
    `Kaynak URL: ${clean(source?.originalUrl, 260)}`,
    `Kaynak alt metni: ${clean(source?.altText, 220)}`,
    'Kaynak fotoğrafı değiştirme; yalnız metin ve yerleşim planı üret.',
  ].join('\n');
}

function extractPlanJson(decoded: any) {
  const text = String(decoded?.candidates?.[0]?.content?.parts?.[0]?.text || '').trim();
  if (!text) throw Object.assign(new Error('Gemini returned an empty plan'), { status: 502 });
  try {
    return JSON.parse(text);
  } catch {
    throw Object.assign(new Error('Gemini returned invalid JSON'), { status: 502 });
  }
}

function headlinePlanSchema() {
  return {
    type: 'object',
    properties: {
      schemaVersion: { type: 'integer' },
      templateId: { type: 'string' },
      target: { type: 'string' },
      headline: {
        type: 'object',
        properties: {
          kicker: { type: 'string' },
          top: { type: 'string' },
          main: { type: 'string' },
          bottom: { type: 'string' },
          support: { type: 'string' },
          tagline: { type: 'string' },
        },
      },
      highlights: { type: 'array', items: { type: 'string' } },
      emphasisWords: { type: 'array', items: { type: 'string' } },
      layout: {
        type: 'object',
        properties: {
          preferredTextZone: { type: 'string' },
          alignment: { type: 'string' },
          overlayStrength: { type: 'string' },
          avoidSubjectOverlap: { type: 'boolean' },
          focalPoint: {
            type: 'object',
            properties: {
              x: { type: 'number' },
              y: { type: 'number' },
              confidence: { type: 'number' },
            },
          },
          avoidZones: { type: 'array', items: { type: 'object' } },
        },
      },
      media: {
        type: 'object',
        properties: {
          filenameStem: { type: 'string' },
          title: { type: 'string' },
          altText: { type: 'string' },
          caption: { type: 'string' },
        },
      },
      readability: { type: 'object' },
      warnings: { type: 'array', items: { type: 'string' } },
    },
  };
}
