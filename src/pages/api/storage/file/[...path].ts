import type { APIRoute } from "astro";
import fs from "fs";
import path from "path";
import sharp from "sharp";

const RESIZABLE_IMAGE_EXTENSIONS = new Set([
  ".webp",
  ".jpg",
  ".jpeg",
  ".png",
  ".avif",
  ".tif",
  ".tiff",
]);
const RANGEABLE_MEDIA_EXTENSIONS = new Set([
  ".mp4",
  ".m4v",
  ".webm",
  ".mov",
  ".avi",
  ".mkv",
  ".mp3",
  ".wav",
  ".ogg",
  ".oga",
  ".m4a",
  ".aac",
]);

const parseBoundedInt = (value: string | null, min: number, max: number) => {
  if (!value) return null;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return null;
  return Math.min(Math.max(parsed, min), max);
};

export const GET: APIRoute = async ({ params, request }) => {
  const filePath = params.path;

  if (!filePath) {
    return new Response("Path is required", { status: 400 });
  }

  const uploadRootDir = path.resolve(process.cwd(), "Upload");
  const imageBaseDir = path.join(uploadRootDir, "image");
  const videoBaseDir = path.join(uploadRootDir, "video");
  const audioBaseDir = path.join(uploadRootDir, "audio");
  const fileBaseDir = path.join(uploadRootDir, "file");
  const logoBaseDir = path.join(uploadRootDir, "logo");
  const profileBaseDir = path.join(uploadRootDir, "profile");

  let fullPath = "";

  if (filePath.startsWith("video/")) {
    fullPath = path.join(videoBaseDir, filePath.replace("video/", ""));
  } else if (filePath.startsWith("audio/")) {
    fullPath = path.join(audioBaseDir, filePath.replace("audio/", ""));
  } else if (filePath.startsWith("file/")) {
    fullPath = path.join(fileBaseDir, filePath.replace("file/", ""));
  } else if (filePath.startsWith("image/")) {
    fullPath = path.join(imageBaseDir, filePath.replace("image/", ""));
  } else if (filePath.startsWith("logo/")) {
    fullPath = path.join(logoBaseDir, filePath.replace("logo/", ""));
  } else if (filePath.startsWith("profile/")) {
    fullPath = path.join(profileBaseDir, filePath.replace("profile/", ""));
  } else {
    fullPath = path.join(imageBaseDir, filePath);
  }

  console.log(`[Storage API] Requested: ${filePath}, Resolved: ${fullPath}`);

  if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
    const stats = fs.statSync(fullPath);
    const fileContent = fs.readFileSync(fullPath);
    const ext = path.extname(fullPath).toLowerCase();

    const mimeTypes: Record<string, string> = {
      ".webp": "image/webp",
      ".jpg": "image/jpeg",
      ".jpeg": "image/jpeg",
      ".png": "image/png",
      ".gif": "image/gif",
      ".svg": "image/svg+xml",
      ".mp4": "video/mp4",
      ".m4v": "video/mp4",
      ".webm": "video/webm",
      ".mov": "video/quicktime",
      ".avi": "video/x-msvideo",
      ".mkv": "video/x-matroska",
      ".mp3": "audio/mpeg",
      ".wav": "audio/wav",
      ".ogg": "audio/ogg",
      ".oga": "audio/ogg",
      ".m4a": "audio/mp4",
      ".aac": "audio/aac",
      ".pdf": "application/pdf",
    };

    const contentType = mimeTypes[ext] || "application/octet-stream";
    const url = new URL(request.url);
    const previewWidth = parseBoundedInt(url.searchParams.get("w"), 64, 2400);
    const commonHeaders = {
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=31536000, immutable",
      "Access-Control-Allow-Origin": "*",
    };

    if (previewWidth && RESIZABLE_IMAGE_EXTENSIONS.has(ext)) {
      try {
        const previewQuality =
          parseBoundedInt(url.searchParams.get("q"), 40, 100) ?? 88;
        const previewContent = await sharp(fileContent)
          .rotate()
          .resize({
            width: previewWidth,
            fit: "inside",
            withoutEnlargement: true,
            kernel: "lanczos3",
          })
          .webp({
            quality: previewQuality,
            effort: 5,
            smartSubsample: true,
            smartDeblock: true,
          })
          .toBuffer();

        return new Response(previewContent, {
          status: 200,
          headers: {
            "Content-Type": "image/webp",
            "Cache-Control": "public, max-age=31536000, immutable",
            "Access-Control-Allow-Origin": "*",
          },
        });
      } catch (err) {
        console.error("[Storage API] Preview resize failed:", err);
      }
    }

    if (RANGEABLE_MEDIA_EXTENSIONS.has(ext)) {
      const range = request.headers.get("range");
      if (range) {
        const match = /^bytes=(\d*)-(\d*)$/.exec(range.trim());
        if (!match) {
          return new Response("Invalid Range", {
            status: 416,
            headers: {
              ...commonHeaders,
              "Accept-Ranges": "bytes",
              "Content-Range": `bytes */${stats.size}`,
            },
          });
        }

        const [, startRaw, endRaw] = match;
        let start = startRaw ? Number.parseInt(startRaw, 10) : 0;
        let end = endRaw ? Number.parseInt(endRaw, 10) : stats.size - 1;

        if (!startRaw && endRaw) {
          const suffixLength = Number.parseInt(endRaw, 10);
          start = Math.max(stats.size - suffixLength, 0);
          end = stats.size - 1;
        }

        if (
          !Number.isFinite(start) ||
          !Number.isFinite(end) ||
          start < 0 ||
          end < start ||
          start >= stats.size
        ) {
          return new Response("Range Not Satisfiable", {
            status: 416,
            headers: {
              ...commonHeaders,
              "Accept-Ranges": "bytes",
              "Content-Range": `bytes */${stats.size}`,
            },
          });
        }

        end = Math.min(end, stats.size - 1);
        const chunk = fileContent.subarray(start, end + 1);
        return new Response(chunk, {
          status: 206,
          headers: {
            ...commonHeaders,
            "Accept-Ranges": "bytes",
            "Content-Range": `bytes ${start}-${end}/${stats.size}`,
            "Content-Length": String(chunk.length),
          },
        });
      }

      return new Response(fileContent, {
        status: 200,
        headers: {
          ...commonHeaders,
          "Accept-Ranges": "bytes",
          "Content-Length": String(stats.size),
        },
      });
    }

    return new Response(fileContent, {
      status: 200,
      headers: commonHeaders,
    });
  }

  return new Response("Not Found", { status: 404 });
};
