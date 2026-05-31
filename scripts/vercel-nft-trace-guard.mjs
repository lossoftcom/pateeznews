import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const traceModule = require('@vercel/nft/out/node-file-trace');
const originalNodeFileTrace = traceModule.nodeFileTrace;

// Astro's Vercel adapter does not expose these @vercel/nft options.
// Keep the trace inside the deployable Astro workspace surface.
const ignoredWorkspaceRoots = ['.git', 'admin', 'frontend'];
const maxFileIOConcurrency = 128;

const normalizeTracePath = (value) => String(value || '').replaceAll('\\', '/');

const isIgnoredWorkspacePath = (value) => {
  const normalized = normalizeTracePath(value);
  return ignoredWorkspaceRoots.some((root) => normalized === root || normalized.startsWith(`${root}/`));
};

const buildExistingIgnore = (ignore) => {
  if (typeof ignore === 'function') return ignore;
  if (typeof ignore === 'string') return (value) => normalizeTracePath(value) === normalizeTracePath(ignore);
  if (Array.isArray(ignore)) {
    const exactIgnores = ignore.map(normalizeTracePath);
    return (value) => exactIgnores.includes(normalizeTracePath(value));
  }
  return () => false;
};

traceModule.nodeFileTrace = (files, options = {}) => {
  const existingIgnore = buildExistingIgnore(options.ignore);
  const requestedConcurrency = Number(options.fileIOConcurrency || maxFileIOConcurrency);

  return originalNodeFileTrace(files, {
    ...options,
    fileIOConcurrency: Math.min(requestedConcurrency, maxFileIOConcurrency),
    ignore: (value) => isIgnoredWorkspacePath(value) || existingIgnore(value),
  });
};
