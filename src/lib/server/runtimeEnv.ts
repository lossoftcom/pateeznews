import { env as cloudflareEnv } from 'cloudflare:workers';

type RuntimeEnv = Record<string, unknown>;
type HyperdriveBinding = {
  connectionString?: unknown;
};

function stringValue(value: unknown) {
  return typeof value === 'string' ? value : '';
}

export function readRuntimeEnv(name: string) {
  const metaEnv = ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env || {});
  return (
    stringValue((cloudflareEnv as RuntimeEnv)[name]) ||
    stringValue(process.env[name]) ||
    stringValue(metaEnv[name])
  );
}

export function getHyperdriveConnectionString(bindingName = 'HYPERDRIVE') {
  const binding = (cloudflareEnv as RuntimeEnv)[bindingName] as
    | HyperdriveBinding
    | undefined;
  return stringValue(binding?.connectionString);
}
