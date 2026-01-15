import fs from 'fs';
import path from 'path';
export { r as renderers } from '../../../../chunks/_@astro-renderers_8ZcaT4W7.mjs';

const GET = async ({ params }) => {
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
    const fileContent = fs.readFileSync(fullPath);
    const ext = path.extname(fullPath).toLowerCase();
    const mimeTypes = {
      ".webp": "image/webp",
      ".jpg": "image/jpeg",
      ".jpeg": "image/jpeg",
      ".png": "image/png",
      ".gif": "image/gif",
      ".svg": "image/svg+xml",
      ".mp4": "video/mp4",
      ".mp3": "audio/mpeg",
      ".pdf": "application/pdf"
    };
    const contentType = mimeTypes[ext] || "application/octet-stream";
    return new Response(fileContent, {
      status: 200,
      headers: {
        "Content-Type": contentType,
        "Cache-Control": "public, max-age=31536000, immutable",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
  return new Response("Not Found", { status: 404 });
};

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
    __proto__: null,
    GET
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
