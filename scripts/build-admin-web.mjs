#!/usr/bin/env node
import fs from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { mergedCloudflareEnv } from './env-utils.mjs';

const cwd = process.cwd();
const env = mergedCloudflareEnv(cwd);
const adminCwd = `${cwd}/admin`;
env.XDG_CONFIG_HOME = ensureLocalFlutterConfig(adminCwd);
const supabaseUrl = env.PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
const publishableKey = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_PUBLISHABLE_KEY;

if (!supabaseUrl || !publishableKey) {
  console.error('Missing Supabase public env values: PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required for admin web build.');
  process.exit(1);
}

if (shouldRunPubGet(adminCwd)) {
  const pubGet = spawnSync('flutter', ['pub', 'get'], {
    cwd: adminCwd,
    env,
    stdio: 'inherit',
  });
  if (pubGet.status !== 0) {
    process.exit(pubGet.status ?? 1);
  }
}

const child = spawn('flutter', [
  'build',
  'web',
  '--release',
  '--no-pub',
  '--no-wasm-dry-run',
  '--no-web-resources-cdn',
  '--base-href=/admin/',
  `--dart-define=SUPABASE_URL=${supabaseUrl}`,
  `--dart-define=SUPABASE_PUBLISHABLE_KEY=${publishableKey}`,
], {
  cwd: adminCwd,
  env,
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

function shouldRunPubGet(projectDir) {
  const packageConfig = `${projectDir}/.dart_tool/package_config.json`;
  const pubspec = `${projectDir}/pubspec.yaml`;
  const lockfile = `${projectDir}/pubspec.lock`;
  if (!fs.existsSync(packageConfig)) return true;

  const packageConfigTime = fs.statSync(packageConfig).mtimeMs;
  for (const file of [pubspec, lockfile]) {
    if (fs.existsSync(file) && fs.statSync(file).mtimeMs > packageConfigTime) {
      return true;
    }
  }
  return false;
}

function ensureLocalFlutterConfig(projectDir) {
  const configHome = `${projectDir}/.dart_tool/flutter_config`;
  const flutterConfigDir = `${configHome}/flutter`;
  const settingsFile = `${flutterConfigDir}/settings`;
  fs.mkdirSync(flutterConfigDir, { recursive: true });
  fs.writeFileSync(settingsFile, `${JSON.stringify({
    'enable-swift-package-manager': true,
    'cli-animations': false,
  }, null, 2)}\n`);
  return configHome;
}
