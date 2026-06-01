#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { delimiter, resolve } from 'node:path';
import { mergedCloudflareEnv } from './env-utils.mjs';

const [command, ...args] = process.argv.slice(2);

if (!command) {
  console.error('Usage: node ./scripts/run-with-cloudflare-env.mjs <command> [...args]');
  process.exit(1);
}

const cwd = process.cwd();
const env = withLocalBinPath(mergedCloudflareEnv(cwd), cwd);
const child = process.platform === 'win32'
  ? spawn(process.env.ComSpec || 'cmd.exe', [
    '/d',
    '/s',
    '/c',
    [command, ...args].map(quoteWindowsArg).join(' '),
  ], {
    cwd,
    env,
    stdio: 'inherit',
  })
  : spawn(command, args, {
    cwd,
    env,
    stdio: 'inherit',
  });

function withLocalBinPath(env, cwd) {
  const nextEnv = { ...env };
  const key = Object.keys(nextEnv).find((name) => name.toLowerCase() === 'path') || 'PATH';
  const localBin = resolve(cwd, 'node_modules', '.bin');
  nextEnv[key] = nextEnv[key] ? `${localBin}${delimiter}${nextEnv[key]}` : localBin;
  return nextEnv;
}

function quoteWindowsArg(value) {
  const arg = String(value);
  if (!/[\s"&|<>^]/.test(arg)) return arg;
  return `"${arg.replace(/"/g, '\\"')}"`;
}

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
