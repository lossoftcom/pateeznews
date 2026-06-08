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
env.PATEEZNEWS_PROJECT_ROOT = cwd;
let shuttingDown = false;
const localStorageServer = shouldStartLocalStorageServer(command, args)
  ? spawn(process.execPath, ['./scripts/local-storage-server.mjs'], {
    cwd,
    env,
    stdio: 'inherit',
  })
  : null;
let child;

if (localStorageServer) {
  localStorageServer.on('exit', (code, signal) => {
    if (shuttingDown) return;
    const detail = signal ? `signal ${signal}` : `exit code ${code ?? 0}`;
    console.error(`Local storage server stopped unexpectedly (${detail}).`);
    shuttingDown = true;
    if (child && !child.killed) child.kill();
    process.exit(code && code > 0 ? code : 1);
  });

  localStorageServer.on('error', (error) => {
    if (shuttingDown) return;
    console.error(error.message);
    shuttingDown = true;
    if (child && !child.killed) child.kill();
    process.exit(1);
  });
}

child = process.platform === 'win32'
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
  shuttingDown = true;
  if (localStorageServer && !localStorageServer.killed) {
    localStorageServer.kill();
  }
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

child.on('error', (error) => {
  shuttingDown = true;
  if (localStorageServer && !localStorageServer.killed) {
    localStorageServer.kill();
  }
  console.error(error.message);
  process.exit(1);
});

function shouldStartLocalStorageServer(command, args) {
  return command === 'astro' && args[0] === 'dev';
}
