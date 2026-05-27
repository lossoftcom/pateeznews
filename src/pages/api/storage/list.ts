import type { APIRoute } from "astro";
import fs from "fs";
import path from "path";

export const GET: APIRoute = async ({ request }) => {
  try {
    const url = new URL(request.url);
    const type = url.searchParams.get("type") || "image";

    const uploadRootDir = path.resolve(process.cwd(), "Upload");
    const typeDir = path.join(uploadRootDir, type);

    if (!fs.existsSync(typeDir)) {
      return new Response(JSON.stringify([]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const files: any[] = [];
    const videoExtensions = new Set([
      ".mp4",
      ".webm",
      ".mov",
      ".avi",
      ".m4v",
      ".mkv",
    ]);
    const audioExtensions = new Set([
      ".mp3",
      ".wav",
      ".ogg",
      ".oga",
      ".m4a",
      ".aac",
    ]);

    function traverse(dir: string, relativeParent: string) {
      if (!fs.existsSync(dir)) return;
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.isDirectory()) {
          traverse(
            path.join(dir, entry.name),
            relativeParent ? `${relativeParent}/${entry.name}` : entry.name,
          );
        } else {
          const fullPath = path.join(dir, entry.name);
          const ext = path.extname(entry.name).toLowerCase();
          const isVideoThumb =
            type === "video" && entry.name.endsWith("_thumb.webp");
          if (isVideoThumb) continue;
          if (type === "video" && !videoExtensions.has(ext)) continue;
          if (type === "audio" && !audioExtensions.has(ext)) continue;

          const stats = fs.statSync(fullPath);
          const relativeId = relativeParent
            ? `${relativeParent}/${entry.name}`
            : entry.name;
          const parsed = path.parse(entry.name);
          const thumbRelativeId =
            type === "video"
              ? relativeParent
                ? `${relativeParent}/${parsed.name}_thumb.webp`
                : `${parsed.name}_thumb.webp`
              : relativeId;
          const thumbFullPath =
            type === "video"
              ? path.join(dir, `${parsed.name}_thumb.webp`)
              : fullPath;

          files.push({
            id: relativeId,
            value: entry.name,
            size: stats.size,
            date: Math.floor(stats.mtimeMs / 1000),
            type: type,
            src: `/api/storage/file/${type}/${relativeId}`,
            thumb: `/api/storage/file/${type}/${fs.existsSync(thumbFullPath) ? thumbRelativeId : relativeId}`,
            path: relativeParent,
          });
        }
      }
    }

    traverse(typeDir, "");

    files.sort((a, b) => b.date - a.date);

    return new Response(JSON.stringify(files), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("Storage List Error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
};
