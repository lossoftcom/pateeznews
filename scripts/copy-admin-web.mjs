import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';

const source = resolve('admin/build/web');
const target = resolve('public/admin');

if (!existsSync(resolve(source, 'index.html'))) {
  throw new Error('admin/build/web/index.html is missing. Run npm run build:admin:web first.');
}

rmSync(target, { recursive: true, force: true });
mkdirSync(target, { recursive: true });
cpSync(source, target, { recursive: true });

console.log(`Copied Flutter admin web build to ${target}`);
