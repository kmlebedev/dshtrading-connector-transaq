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

test('package is a publishable DSH bundle and ships the patch', () => {
  assert.equal(pkg.name, '@dshtrading/ru');
  assert.notEqual(pkg.private, true);
  assert.equal(pkg.publishConfig?.access, 'public');
  assert.equal(pkg.dsh?.bundle?.patch, './cordis.patch.yml');
  assert.ok(Array.isArray(pkg.files) && pkg.files.includes('cordis.patch.yml'));
  assert.ok(pkg.files.includes('*.js'));
  assert.ok(existsSync(patchUrl));
});

test('bundle patch inserts exactly one connector row with the standard defaults', () => {
  assert.match(activePatch, /^\s*- insert:/m);
  assert.equal((activePatch.match(/^\s*- id:/gm) ?? []).length, 1);
  assert.equal((activePatch.match(/id: dsh-trading-ru-connector-transaq/g) ?? []).length, 1);
  assert.match(activePatch, /name: ['"]@dshtrading\/ru['"]/);
  assert.match(activePatch, /gatewayUrl: 'http:\/\/127\.0\.0\.1:18095'/);
  assert.match(activePatch, /tokenRef: TERMINAL_API_TOKEN/);
  assert.doesNotMatch(activePatch, /@local\//);
});

test('code default matches the bundle and QUICKSTART port', () => {
  assert.equal(DEFAULTS.gatewayUrl, 'http://127.0.0.1:18095');
  assert.equal(DEFAULTS.tokenRef, 'TERMINAL_API_TOKEN');
});
