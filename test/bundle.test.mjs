import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { DEFAULTS } from '../config.js';

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
const patchUrl = new URL('../cordis.patch.yml', import.meta.url);
const patch = readFileSync(patchUrl, 'utf8');
const activePatch = patch
  .split(/\r?\n/)
  .filter((line) => !line.trimStart().startsWith('#'))
  .join('\n');

test('package declares the DSH bundle patch and ships it', () => {
  assert.equal(pkg.name, '@local/dshtrading-connector-transaq');
  assert.equal(pkg.dsh?.bundle?.patch, './cordis.patch.yml');
  assert.ok(Array.isArray(pkg.files) && pkg.files.includes('cordis.patch.yml'));
  assert.ok(existsSync(patchUrl));
});

test('bundle patch inserts exactly one connector row with the standard defaults', () => {
  assert.match(activePatch, /^\s*- insert:/m);
  assert.equal((activePatch.match(/id: dsh-trading-ru-connector-transaq/g) ?? []).length, 1);
  assert.match(activePatch, /name: '@local\/dshtrading-connector-transaq'/);
  assert.match(activePatch, /gatewayUrl: 'http:\/\/127\.0\.0\.1:18095'/);
  assert.match(activePatch, /tokenRef: TERMINAL_API_TOKEN/);
});

test('code default matches the bundle and QUICKSTART port', () => {
  assert.equal(DEFAULTS.gatewayUrl, 'http://127.0.0.1:18095');
  assert.equal(DEFAULTS.tokenRef, 'TERMINAL_API_TOKEN');
});
