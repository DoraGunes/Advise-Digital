import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';

const sql=await fs.readFile(new URL('../database/migrations/20261007_ai_memory_scale.sql',import.meta.url),'utf8');

test('AI memory scale migration is additive and idempotent',()=>{
  const normalized=sql.toLowerCase();
  for(const table of ['content_memories','performance_memories','style_recipes','ai_generation_events','publish_outcomes']) {
    assert.match(normalized,new RegExp('create\\s+table\\s+if\\s+not\\s+exists\\s+'+table));
  }
  assert.doesNotMatch(normalized,/\bdrop\s+(table|column|index)\b/);
  assert.doesNotMatch(normalized,/\btruncate\b/);
  assert.doesNotMatch(normalized,/\bdelete\s+from\b/);
  assert.doesNotMatch(normalized,/\balter\s+table\b/);
});

test('AI memory scale migration keeps tenant-aware indexes',()=>{
  const normalized=sql.toLowerCase();
  assert.match(normalized,/content_memories\(tenant_id, created_at desc\)/);
  assert.match(normalized,/performance_memories\(tenant_id, measured_at desc\)/);
  assert.match(normalized,/style_recipes\(tenant_id, updated_at desc\)/);
  assert.match(normalized,/ai_generation_events\(tenant_id, created_at desc\)/);
  assert.match(normalized,/publish_outcomes\(tenant_id, measured_at desc\)/);
});
