import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {GEMINI_TEST_TASKS, readGeminiTestConfig, runGeminiTest} from '../test-gemini/client.js';

test('test Gemini config reads only the supplied test env and redacts no key into output', async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'advise-gemini-test-'));
  const envPath = path.join(dir, '.env');
  await fs.writeFile(envPath, 'GEMINI_TEST_MODE=true\nGEMINI_API_KEY=test-only-key\nGEMINI_MODEL=fixture-model\n');
  const config = readGeminiTestConfig({envPath, env: {}});
  assert.deepEqual(config, {enabled: true, apiKey: 'test-only-key', model: 'fixture-model', apiBase: 'https://generativelanguage.googleapis.com/v1beta'});
  await fs.rm(dir, {recursive: true, force: true});
});

test('mock Gemini tasks never call Meta, ads or queue services', async () => {
  const calls = [];
  const transport = async (url, options) => {
    calls.push({url, method: options.method, body: JSON.parse(options.body)});
    return {ok: true, status: 200, json: async () => ({candidates: [{content: {parts: [{text: '{"ok":true}'}]}}]})};
  };
  const env = {GEMINI_TEST_MODE: 'true', GEMINI_API_KEY: 'fixture-key', GEMINI_MODEL: 'fixture-model'};
  for (const task of Object.values(GEMINI_TEST_TASKS)) {
    const result = await runGeminiTest(task, {product: 'fixture'}, {env, transport});
    assert.equal(result.task, task);
    assert.equal(result.text, '{"ok":true}');
  }
  assert.equal(calls.length, 3);
  assert.ok(calls.every(call => call.url.startsWith('https://generativelanguage.googleapis.com/')));
  assert.ok(calls.every(call => !/facebook|meta|ads|queue|scheduler/i.test(call.url)));
  assert.ok(calls.every(call => !('access_token' in call.body) && !('ad_account_id' in call.body)));
});

test('test Gemini mode fails closed without a test key or enable flag', async () => {
  await assert.rejects(() => runGeminiTest('AD_COPY', {}, {env: {GEMINI_TEST_MODE: 'false', GEMINI_API_KEY: 'fixture-key'}}), /etkin değil/);
  await assert.rejects(() => runGeminiTest('STRATEGY', {}, {env: {GEMINI_TEST_MODE: 'true', GEMINI_API_KEY: ''}}), /bulunamadı/);
});
