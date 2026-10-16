import test from 'node:test';
import assert from 'node:assert/strict';

Object.assign(process.env, {
  DOTENV_CONFIG_PATH: '/tmp/advise-meta-geolocation-test-missing.env',
  JWT_SECRET: 'meta-geolocation-test-secret',
  ADMIN_USERNAME: 'meta-geolocation-admin',
  ADMIN_PASSWORD: 'meta-geolocation-password',
  CRON_ENABLED: 'false',
  NODE_ENV: 'test'
});

const {resolveAdGeoTargeting, selectAdGeoLocation} = await import('../src/meta.js');

const karadeniz = ['Amasya','Artvin','Bartın','Bayburt','Bolu','Çorum','Düzce','Giresun','Gümüşhane','Karabük','Kastamonu','Ordu','Rize','Samsun','Sinop','Tokat','Trabzon','Zonguldak'];

test('Meta Tokat city response is matched without changing its city scope', () => {
  const match = selectAdGeoLocation([{
    key: '2334170', name: 'Tokat (ilçe)', type: 'city', country_code: 'TR',
    country_name: 'Türkiye', region: 'Tokat Province', region_id: 3704
  }], 'Tokat');
  assert.deepEqual({key: match.key, name: match.name, type: match.type}, {
    key: '2334170', name: 'Tokat (ilçe)', type: 'city'
  });
});

test('Karadeniz resolves all 18 provinces as Meta city keys', async () => {
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async url => {
    const query = new URL(url).searchParams.get('q');
    const row = query === 'Tokat'
      ? {key: '2334170', name: 'Tokat (ilçe)', type: 'city', country_code: 'TR', region: 'Tokat Province'}
      : {key: `fixture-${karadeniz.indexOf(query)}`, name: query, type: 'city', country_code: 'TR', region: `${query} Province`};
    return {ok: true, status: 200, text: async () => JSON.stringify({data: [row]})};
  };
  try {
    const result = await resolveAdGeoTargeting('REGION', ['Karadeniz'], {accessToken: 'fixture-token', adAccountId: '123'});
    assert.equal(result.locationMode, 'REGION');
    assert.deepEqual(result.locations, karadeniz);
    assert.equal(result.geo_locations.cities.length, 18);
    assert.equal(result.geo_locations.cities[karadeniz.indexOf('Tokat')].key, '2334170');
  } finally {
    globalThis.fetch = oldFetch;
  }
});

test('non-city or non-Türkiye matches fail closed', () => {
  assert.equal(selectAdGeoLocation([
    {key: 'wrong-1', name: 'Tokat', type: 'subcity', country_code: 'TR'},
    {key: 'wrong-2', name: 'Tokat', type: 'city', country_code: 'US'}
  ], 'Tokat'), null);
});
