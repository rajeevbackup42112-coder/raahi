import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const appDir = path.dirname(fileURLToPath(import.meta.url));
const bundleDir = path.join(appDir, 'source-bundle-v13');
const outputDir = path.join(appDir, 'reconstructed-v13');

const expectedTarSha256 = '9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc';

const expectedFiles = {
  'README.md': '2dc9ca49421b2c61109ed1e832a5ea45306b590c24dc5ab78dc00b7bc2de6bbf',
  'app.fixture.js': '6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c',
  'app.live-core-v13.js': '925ea0ecdbb95f76a2c548f3efa3fbdd3d99ac1bf355d5d59f945a626c14274b',
  'index.html': '620febde290d2d0b8fe8b8f16a7ef95af6d3ac55e1e1eeda55622ea460333183',
  'live.js': '8ae054cbd24e33775f1782f78609531e1003ea391e6acd9a2c10c264caedf058',
  'styles.css': 'b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd',
  'tests/cdp-v13-actions.mjs': '9c374662e5023a7fdf96728975caa7939df92fdd1d8a87a3919da1fd2fd93214',
  'tests/cdp-live-contract.mjs': 'efa0fb161d4aa094e58e3b0f298825d6643cc195caa94504e9b883efb41dc77a',
};

// Parts 00-10 transferred cleanly through the connector. The final logical part
// is deliberately represented by smaller verified pieces because large direct
// transfers of that tail were observed to mutate bytes. Do not simplify this
// list unless the rebuilt tar hash remains exactly equal to expectedTarSha256.
const pieces = [
  ...Array.from({ length: 11 }, (_, i) => `part${String(i).padStart(2, '0')}.b64`),
  'part11-00.b64',
  'part11-01.b64',
  'part11-02.b64',
  'part11-03-00.b64',
  'part11-03-01.b64',
  'part11-03-02.b64',
  'part11-03-03-00.b64',
  'part11-03-03-01.b64',
  'part11-03-03-02.b64',
  'part11-03-03-03.b64',
  'part11-03-03-04.b64',
  'part11-03-03-05.b64',
];

const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

for (const name of pieces) {
  if (!fs.existsSync(path.join(bundleDir, name))) {
    throw new Error(`Missing source bundle piece: ${name}`);
  }
}

const base64 = pieces
  .map(name => fs.readFileSync(path.join(bundleDir, name), 'utf8').trim())
  .join('');
const tarBytes = Buffer.from(base64, 'base64');
const tarSha = sha256(tarBytes);

if (tarSha !== expectedTarSha256) {
  throw new Error(`Source bundle hash mismatch: ${tarSha}`);
}

fs.rmSync(outputDir, { recursive: true, force: true });
fs.mkdirSync(outputDir, { recursive: true });
const tmpTar = path.join(outputDir, '.frontend-source-v1.3.tar.gz');
fs.writeFileSync(tmpTar, tarBytes);
execFileSync('tar', ['-xzf', tmpTar, '-C', outputDir], { stdio: 'inherit' });
fs.rmSync(tmpTar, { force: true });

for (const [relativePath, expected] of Object.entries(expectedFiles)) {
  const filePath = path.join(outputDir, relativePath);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing reconstructed file: ${relativePath}`);
  }
  const actual = sha256(fs.readFileSync(filePath));
  if (actual !== expected) {
    throw new Error(`Reconstructed hash mismatch for ${relativePath}: ${actual}`);
  }
}

console.log(`RAAHI_LEARNING_V13_SOURCE_RECONSTRUCTED ${tarSha}`);
