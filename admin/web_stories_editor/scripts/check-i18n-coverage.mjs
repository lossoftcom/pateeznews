// Audits that every msgid the editor packages pass to __/_x/_n/_nx is covered by
// our Turkish catalog (tr.json + tr-extra.json). Prints any gaps.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const EOT = '';
const tr = JSON.parse(readFileSync('src/i18n/tr.json', 'utf8'));
const extra = JSON.parse(readFileSync('src/i18n/tr-extra.json', 'utf8'));
const baseCat = new Set(
  [...Object.keys(tr), ...Object.keys(extra)].map((k) =>
    k.includes(EOT) ? k.split(EOT)[1] : k
  )
);

const root = 'node_modules/@googleforcreators';
const pkgs = readdirSync(root).filter((p) => {
  try {
    return statSync(join(root, p, 'dist-module')).isDirectory();
  } catch {
    return false;
  }
});

function walk(dir, acc) {
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, acc);
    else if (f.endsWith('.js')) acc.push(p);
  }
  return acc;
}

const reDouble = /\b(__|_x|_n|_nx)\(\s*"((?:[^"\\]|\\.)*)"/g;
const reSingle = /\b(__|_x|_n|_nx)\(\s*'((?:[^'\\]|\\.)*)'/g;
function unesc(s) {
  try {
    return JSON.parse('"' + s.replace(/\\'/g, "'").replace(/"/g, '\\"') + '"');
  } catch {
    return s;
  }
}

const used = new Set();
for (const pk of pkgs) {
  for (const file of walk(join(root, pk, 'dist-module'), [])) {
    const src = readFileSync(file, 'utf8');
    for (const re of [reDouble, reSingle]) {
      re.lastIndex = 0;
      let m;
      while ((m = re.exec(src))) used.add(unesc(m[2]));
    }
  }
}

const missing = [...used].filter((s) => s && !baseCat.has(s));
console.log('distinct msgids used by editor packages:', used.size);
console.log('NOT covered by Turkish catalog:', missing.length);
missing.slice(0, 60).forEach((s) => console.log('  •', JSON.stringify(s).slice(0, 110)));
