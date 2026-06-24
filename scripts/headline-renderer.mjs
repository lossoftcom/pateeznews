import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const TARGET_SIZES = {
  headline_square: { width: 1200, height: 1200 },
  article_4x3: { width: 1200, height: 900 },
  landscape_16x9: { width: 1280, height: 720 },
  social_9x16: { width: 1080, height: 1920 },
};

const PALETTE = {
  red: '#ef3b2d',
  yellow: '#ffd233',
  blue: '#16456a',
  dark: '#0f2434',
  white: '#ffffff',
};

export async function renderHeadlineImage(input, { projectRoot }) {
  const target = TARGET_SIZES[input.target] ? input.target : 'headline_square';
  const size = TARGET_SIZES[target];
  const outputFormat = normalizeOutputFormat(input.outputFormat);
  const source = Buffer.from(String(input.sourceBase64 || ''), 'base64');
  if (!source.length) throw statusError('Source image is empty', 400);
  const plan = normalizePlan(input.plan, target);
  const base = await sharp(source, { failOn: 'none', animated: false })
    .rotate()
    .resize(size.width, size.height, {
      fit: 'cover',
      position: focalPosition(plan.layout?.focalPoint),
      kernel: 'lanczos3',
    })
    .toBuffer();
  const svg = buildOverlaySvg(plan, size, projectRoot);
  let output = await encode(
    sharp(base)
      .composite([{ input: Buffer.from(svg), left: 0, top: 0 }]),
    outputFormat,
    92,
  );

  const maxBytes = Number(input.maxBytes || 0);
  if (maxBytes > 0 && output.length > maxBytes) {
    for (const quality of [86, 80, 74, 68]) {
      output = await encode(
        sharp(base).composite([{ input: Buffer.from(svg), left: 0, top: 0 }]),
        outputFormat,
        quality,
      );
      if (output.length <= maxBytes) break;
    }
    if (output.length > maxBytes) {
      throw statusError('Rendered headline image exceeds upload limit', 413);
    }
  }

  return {
    base64: output.toString('base64'),
    contentType: contentType(outputFormat),
    fileName: safeFileName(input.fileName, outputFormat),
    width: size.width,
    height: size.height,
  };
}

async function encode(pipeline, format, quality) {
  if (format === 'jpeg') {
    return pipeline
      .flatten({ background: PALETTE.white })
      .jpeg({ quality, mozjpeg: true })
      .toBuffer();
  }
  if (format === 'png') {
    return pipeline.png({ compressionLevel: 9, adaptiveFiltering: true }).toBuffer();
  }
  return pipeline.webp({ quality, alphaQuality: 95, effort: 5 }).toBuffer();
}

function buildOverlaySvg(plan, size, projectRoot) {
  const fontRegular = fontDataUri(projectRoot, 'public/fonts/site/poppins/Poppins-Regular.ttf');
  const fontBold = fontDataUri(projectRoot, 'public/fonts/site/poppins/Poppins-Bold.ttf');
  const margin = Math.round(Math.min(size.width, size.height) * 0.07);
  const maxTextWidth = Math.round(size.width - margin * 2);
  const zone = String(plan.layout?.preferredTextZone || 'bottom');
  const boxY = textBoxY(zone, size, margin);
  const align = plan.layout?.alignment === 'center' ? 'middle' : 'start';
  const x = align === 'middle' ? Math.round(size.width / 2) : margin;
  const lines = layoutLines(plan, maxTextWidth, size);
  const textHeight = lines.reduce((sum, line) => sum + line.size * line.height, 0);
  const yStart = Math.max(margin, Math.min(size.height - margin - textHeight, boxY));

  let y = yStart;
  const textParts = [];
  for (const line of lines) {
    y += line.size;
    textParts.push(
      `<text x="${x}" y="${Math.round(y)}" text-anchor="${align}" font-family="${line.bold ? 'PateezHeadlineBold' : 'PateezHeadline'}" font-size="${line.size}" font-weight="${line.bold ? 800 : 600}" fill="${line.color}" stroke="${line.stroke || 'none'}" stroke-width="${line.strokeWidth || 0}" paint-order="stroke" letter-spacing="0">${escapeXml(line.text)}</text>`,
    );
    y += line.size * (line.height - 1);
  }

  const overlayOpacity = plan.layout?.overlayStrength === 'low'
    ? 0.46
    : plan.layout?.overlayStrength === 'high'
      ? 0.72
      : 0.6;
  const bandHeight = Math.round(textHeight + margin * 1.3);
  const bandY = Math.max(0, Math.min(size.height - bandHeight, yStart - margin * 0.55));
  const brushY = Math.round(bandY + bandHeight - Math.min(size.height * 0.08, 78));

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${size.width}" height="${size.height}" viewBox="0 0 ${size.width} ${size.height}">
  <defs>
    <style>
      @font-face { font-family: 'PateezHeadline'; src: url('${fontRegular}') format('truetype'); }
      @font-face { font-family: 'PateezHeadlineBold'; src: url('${fontBold}') format('truetype'); }
    </style>
    <linearGradient id="fade" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="${PALETTE.dark}" stop-opacity="0"/>
      <stop offset="0.46" stop-color="${PALETTE.dark}" stop-opacity="${overlayOpacity}"/>
      <stop offset="1" stop-color="${PALETTE.dark}" stop-opacity="${Math.min(0.88, overlayOpacity + 0.16)}"/>
    </linearGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#fade)"/>
  <path d="M ${margin * 0.4} ${brushY} C ${size.width * 0.28} ${brushY - 34}, ${size.width * 0.52} ${brushY + 34}, ${size.width - margin * 0.2} ${brushY - 10} L ${size.width - margin * 0.15} ${brushY + 78} C ${size.width * 0.56} ${brushY + 115}, ${size.width * 0.28} ${brushY + 64}, ${margin * 0.2} ${brushY + 96} Z" fill="${PALETTE.red}" opacity="0.92"/>
  <rect x="${margin}" y="${Math.max(margin, bandY - 16)}" width="${Math.min(size.width * 0.38, 420)}" height="12" rx="3" fill="${PALETTE.yellow}" opacity="0.98"/>
  <rect x="${margin}" y="${Math.max(margin, bandY + bandHeight - 28)}" width="${Math.min(size.width * 0.28, 320)}" height="10" rx="3" fill="${PALETTE.blue}" opacity="0.96"/>
  ${textParts.join('\n  ')}
</svg>`;
}

function layoutLines(plan, maxWidth, size) {
  const headline = plan.headline || {};
  const minSide = Math.min(size.width, size.height);
  const base = Math.round(minSide / 1200 * 1);
  const rows = [
    { text: headline.kicker, size: 34 + base * 2, color: PALETTE.yellow, bold: true, upper: true, maxLines: 1 },
    { text: headline.top, size: 54 + base * 3, color: PALETTE.white, bold: true, maxLines: 2, stroke: PALETTE.dark, strokeWidth: 2 },
    { text: headline.main, size: 82 + base * 5, color: PALETTE.yellow, bold: true, maxLines: 2, stroke: PALETTE.dark, strokeWidth: 3 },
    { text: headline.bottom, size: 62 + base * 3, color: PALETTE.white, bold: true, maxLines: 2, stroke: PALETTE.dark, strokeWidth: 2 },
    { text: headline.support, size: 34 + base * 2, color: PALETTE.white, bold: false, maxLines: 2, stroke: PALETTE.dark, strokeWidth: 1 },
    { text: headline.tagline, size: 30 + base * 2, color: PALETTE.yellow, bold: true, upper: true, maxLines: 1 },
  ];
  const output = [];
  for (const row of rows) {
    const value = String(row.text || '').replace(/\s+/g, ' ').trim();
    if (!value) continue;
    const text = row.upper ? value.toLocaleUpperCase('tr-TR') : value;
    for (const wrapped of wrapText(text, maxWidth, row.size, row.maxLines)) {
      output.push({ ...row, text: wrapped, height: row.size >= 70 ? 1.04 : 1.12 });
    }
  }
  return output.length ? output : [{ text: 'PATEEZ', size: 72, color: PALETTE.yellow, bold: true, height: 1.05 }];
}

function wrapText(text, maxWidth, fontSize, maxLines) {
  const words = text.split(/\s+/).filter(Boolean);
  const lines = [];
  let current = '';
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (estimatedTextWidth(candidate, fontSize) <= maxWidth || !current) {
      current = candidate;
      continue;
    }
    lines.push(current);
    current = word;
    if (lines.length >= maxLines) break;
  }
  if (current && lines.length < maxLines) lines.push(current);
  return lines;
}

function estimatedTextWidth(text, fontSize) {
  let units = 0;
  for (const char of text) {
    if (char === ' ') units += 0.33;
    else if ('Iıijlft'.includes(char)) units += 0.36;
    else if ('mwMW@#'.includes(char)) units += 0.95;
    else units += 0.64;
  }
  return units * fontSize;
}

function textBoxY(zone, size, margin) {
  if (zone === 'top') return margin * 1.5;
  if (zone === 'left' || zone === 'right' || zone === 'center-left' || zone === 'center-right') {
    return Math.round(size.height * 0.48);
  }
  return Math.round(size.height * 0.58);
}

function focalPosition(focalPoint = {}) {
  const x = clamp01(focalPoint.x, 0.5);
  const y = clamp01(focalPoint.y, 0.5);
  const horizontal = x < 0.38 ? 'west' : x > 0.62 ? 'east' : '';
  const vertical = y < 0.38 ? 'north' : y > 0.62 ? 'south' : '';
  return `${vertical}${horizontal}` || 'centre';
}

function normalizePlan(plan, target) {
  const source = plan && typeof plan === 'object' ? plan : {};
  return {
    ...source,
    target,
    templateId: 'classic-red-yellow-blue',
    headline: source.headline && typeof source.headline === 'object' ? source.headline : {},
    layout: source.layout && typeof source.layout === 'object' ? source.layout : {},
    media: source.media && typeof source.media === 'object' ? source.media : {},
  };
}

function normalizeOutputFormat(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'jpeg' || normalized === 'jpg') return 'jpeg';
  if (normalized === 'png') return 'png';
  return 'webp';
}

function contentType(format) {
  if (format === 'jpeg') return 'image/jpeg';
  if (format === 'png') return 'image/png';
  return 'image/webp';
}

function safeFileName(value, format) {
  const fallback = `manset.${format === 'jpeg' ? 'jpg' : format}`;
  const name = path.posix.basename(String(value || fallback)).replace(/[^a-zA-Z0-9._-]/g, '-');
  return name || fallback;
}

function fontDataUri(projectRoot, relativePath) {
  const fullPath = path.resolve(projectRoot, relativePath);
  if (!fs.existsSync(fullPath)) {
    throw statusError(`Headline font not found: ${relativePath}`, 500);
  }
  return `data:font/truetype;base64,${fs.readFileSync(fullPath).toString('base64')}`;
}

function escapeXml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function clamp01(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.min(1, parsed));
}

function statusError(message, status) {
  const error = new Error(message);
  error.status = status;
  return error;
}
