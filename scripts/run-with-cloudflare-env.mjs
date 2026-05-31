#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { mergedCloudflareEnv } from './env-utils.mjs';

const [command, ...args] = process.argv.slice(2);

if (!command) {
  console.error('Usage: node ./scripts/run-with-cloudflare-env.mjs <command> [...args]');
  process.exit(1);
}

const child = spawn(command, args, {
  cwd: process.cwd(),
  env: mergedCloudflareEnv(process.cwd()),
  stdio: 'inherit',
});

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

child.on('error', (error) => {
  console.error(error.message);
  process.exit(1);
});
