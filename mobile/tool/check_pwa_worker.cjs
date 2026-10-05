// Local-only contract checks for the public app service worker.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const listeners = new Map();
const cachedRequests = [];
let fetched = 0;
const scope = 'https://fixture.test/app/';
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/advise_service_worker.js'), 'utf8'), {
  URL,
  self: {
    registration: { scope },
    clients: { claim: async () => {} },
    addEventListener: (type, handler) => listeners.set(type, handler),
  },
  caches: {
    keys: async () => [],
    delete: async () => true,
    open: async () => ({ addAll: async () => {}, put: async (request) => cachedRequests.push(request.url) }),
    match: async () => undefined,
  },
  fetch: async () => {
    fetched++;
    return { ok: true, type: 'basic', clone: () => ({}) };
  },
});

function eventFor(url, { method = 'GET', authenticated = false } = {}) {
  return {
    request: { url, method, headers: { has: () => authenticated } },
    response: null,
    pending: [],
    respondWith(response) { this.response = response; },
    waitUntil(promise) { this.pending.push(promise); },
  };
}

(async () => {
  for (const [url, options] of [
    [scope + 'api/product/overview', {}],
    [scope + 'uploads/private.jpg', {}],
    ['https://api.fixture.test/health', {}],
    [scope + 'main.dart.js', { method: 'POST' }],
    [scope + 'assets/fixture.png', { authenticated: true }],
  ]) {
    const event = eventFor(url, options);
    listeners.get('fetch')(event);
    assert.equal(event.response, null, `Worker must not intercept ${url}`);
  }
  assert.equal(fetched, 0);
  for (const asset of ['main.dart.js', 'assets/assets/advise_logo.jpg', 'manifest.json']) {
    const event = eventFor(scope + asset);
    listeners.get('fetch')(event);
    assert.ok(event.response, `Public file should be eligible: ${asset}`);
    await event.response;
    await Promise.all(event.pending);
  }
  assert.equal(fetched, 3);
  assert.equal(cachedRequests.length, 3);
  console.log('PWA worker contract passed: only public app files are intercepted and cached.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
