import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data');
const settingsFile = path.join(root, 'settings.json');
const usersFile = path.join(root, 'users.json');
const tenantsFile = path.join(root, 'tenants.json');
const licensesFile = path.join(root, 'licenses.json');
const logsFile = path.join(root, 'logs.json');
const postsFile = path.join(root, 'posts.json');

export const SYSTEM_TENANT_ID = 'system';

export const PLAN_DEFINITIONS = {
  BASIC: {
    name: 'Basic',
    maxMetaAccounts: 1,
    maxAds: 5,
    maxUsers: 1,
    features: { automation: true, analytics: true, bestTime: false, budgetReallocation: false, advancedReports: false, aiInsights: false, aiContent: true, autoMediaType: true, smartPublish: true, whiteLabel: false, apiAccess: false }
  },
  PRO: {
    name: 'Pro',
    maxMetaAccounts: 3,
    maxAds: 50,
    maxUsers: 5,
    features: { automation: true, analytics: true, bestTime: true, budgetReallocation: true, advancedReports: true, aiContent: true, autoMediaType: true, smartPublish: true }
  },
  AGENCY: {
    name: 'Agency',
    maxMetaAccounts: 20,
    maxAds: 500,
    maxUsers: 25,
    features: { automation: true, analytics: true, bestTime: true, budgetReallocation: true, advancedReports: true, aiInsights: true, aiContent: true, autoMediaType: true, smartPublish: true, whiteLabel: true, apiAccess: true }
  },
  ENTERPRISE: {
    name: 'Enterprise',
    maxMetaAccounts: 100,
    maxAds: 5000,
    maxUsers: 100,
    features: { automation: true, analytics: true, bestTime: true, budgetReallocation: true, advancedReports: true, aiInsights: true, aiContent: true, autoMediaType: true, smartPublish: true, whiteLabel: true, apiAccess: true, prioritySupport: true }
  }
};

const defaults = {
  weeklyBudget: 1000,
  messageCostLimit: 8,
  minSpendBeforeDecision: 50,
  autoPause: true,
  autoReallocate: true,
  weeklyDay: 1,
  startHour: 19,
  startMinute: 0,
  durationHours: 24,
  minDailyBudget: 50,
  maxDailyBudget: 500,
  earlyWindowHours: 12,
  earlyMinSpendBeforeDecision: 50,
  earlyMessageCostLimit: 8,
  earlyNoMessageSpendThreshold: 75,
  earlyBudgetReductionPercent: 30,
  autoPublish: true,
  enabled: false,
  autoBestTime: true,
  aiEnabled: true,
  aiTone: 'samimi ve güven veren',
  aiGoal: 'mesaj',
  aiLanguage: 'Türkçe',
  autoMediaType: true,
  preventDuplicateContent: true,
  publishMaxRetries: 3,
  publishRetryMinutes: 10,
  timezone: 'Europe/Istanbul',
  selection: {
    messageCostWeight: 0.55,
    ctrWeight: 0.20,
    messagesWeight: 0.20,
    explorationWeight: 0.05
  }
};

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

async function ensureFile(file, initial) {
  await fs.mkdir(root, {recursive: true});
  try {
    await fs.access(file);
  } catch {
    await fs.writeFile(file, JSON.stringify(initial, null, 2));
  }
}

async function readJson(file, fallback) {
  await ensureFile(file, fallback);
  try {
    return JSON.parse(await fs.readFile(file, 'utf8'));
  } catch {
    await fs.writeFile(file, JSON.stringify(fallback, null, 2));
    return clone(fallback);
  }
}

async function writeJson(file, value) {
  await ensureFile(file, value);
  await fs.writeFile(file, JSON.stringify(value, null, 2));
}

export function planDefinition(plan) {
  return clone(PLAN_DEFINITIONS[String(plan || 'BASIC').toUpperCase()] || PLAN_DEFINITIONS.BASIC);
}

function normalizeTenant(tenant) {
  const plan = String(tenant.plan || 'BASIC').toUpperCase();
  const def = planDefinition(plan);
  return {
    id: tenant.id,
    companyName: tenant.companyName || tenant.name || tenant.id,
    plan,
    active: tenant.active !== false,
    subscriptionStart: tenant.subscriptionStart || new Date().toISOString(),
    subscriptionEnd: tenant.subscriptionEnd || null,
    createdAt: tenant.createdAt || new Date().toISOString(),
    archivedAt: tenant.archivedAt || null,
    meta: {
      connected: Boolean(tenant.meta?.connected),
      source: tenant.meta?.source || null,
      accessToken: tenant.meta?.accessToken || '',
      metaAccessToken: tenant.meta?.metaAccessToken || tenant.meta?.accessToken || '',
      instagramAccessToken: tenant.meta?.instagramAccessToken || '',
      adAccountId: tenant.meta?.adAccountId || '',
      pageId: tenant.meta?.pageId || '',
      instagramUserId: tenant.meta?.instagramUserId || '',
      instagramUsername: tenant.meta?.instagramUsername || '',
      businessId: tenant.meta?.businessId || '',
      connectedAt: tenant.meta?.connectedAt || null
    },
    branding: {
      appName: tenant.branding?.appName || 'AdVise AI',
      logoUrl: tenant.branding?.logoUrl || '',
      primaryColor: tenant.branding?.primaryColor || '#4F46E5',
      supportEmail: tenant.branding?.supportEmail || ''
    },
    notificationPrefs: {
      email: tenant.notificationPrefs?.email !== false,
      push: tenant.notificationPrefs?.push !== false,
      highCost: tenant.notificationPrefs?.highCost !== false,
      subscription: tenant.notificationPrefs?.subscription !== false
    },
    limits: {
      maxMetaAccounts: Number(tenant.limits?.maxMetaAccounts ?? def.maxMetaAccounts),
      maxAds: Number(tenant.limits?.maxAds ?? def.maxAds),
      maxUsers: Number(tenant.limits?.maxUsers ?? def.maxUsers)
    },
    features: {...def.features, ...(tenant.features || {})}
  };
}

export async function getTenants() {
  const raw = await readJson(tenantsFile, []);
  const tenants = raw.map(normalizeTenant);
  if (!tenants.some(t => t.id === SYSTEM_TENANT_ID)) {
    tenants.unshift(normalizeTenant({
      id: SYSTEM_TENANT_ID,
      companyName: 'AdVise AI System',
      plan: 'AGENCY',
      active: true
    }));
    await writeJson(tenantsFile, tenants);
  }
  return tenants;
}

export async function saveTenants(tenants) {
  await writeJson(tenantsFile, tenants.map(normalizeTenant));
}

export async function getTenant(id) {
  const tenants = await getTenants();
  return tenants.find(t => t.id === id) || null;
}

export async function createTenant({companyName, plan = 'BASIC', days = 30}) {
  const tenants = await getTenants();
  const p = String(plan).toUpperCase();
  if (!PLAN_DEFINITIONS[p]) throw new Error('Geçersiz paket. BASIC, PRO, AGENCY veya ENTERPRISE seç.');
  const now = new Date();
  const end = new Date(now.getTime() + Math.max(1, Number(days) || 30) * 86400000);
  const def = planDefinition(p);
  const tenant = normalizeTenant({
    id: `tenant_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`,
    companyName: String(companyName || 'Yeni Müşteri').trim(),
    plan: p,
    active: true,
    subscriptionStart: now.toISOString(),
    subscriptionEnd: end.toISOString(),
    createdAt: now.toISOString(),
    limits: {
      maxMetaAccounts: def.maxMetaAccounts,
      maxAds: def.maxAds,
      maxUsers: def.maxUsers
    },
    features: def.features
  });
  tenants.unshift(tenant);
  await saveTenants(tenants);
  return tenant;
}

export async function updateTenant(id, patch) {
  const tenants = await getTenants();
  const index = tenants.findIndex(t => t.id === id);
  if (index < 0) throw new Error('Müşteri bulunamadı.');
  const old = tenants[index];
  const plan = patch.plan ? String(patch.plan).toUpperCase() : old.plan;
  const def = planDefinition(plan);
  const next = normalizeTenant({
    ...old,
    ...patch,
    id: old.id,
    plan,
    limits: {...old.limits, ...(patch.limits || {}), maxMetaAccounts: patch.limits?.maxMetaAccounts ?? (patch.plan ? def.maxMetaAccounts : old.limits.maxMetaAccounts), maxAds: patch.limits?.maxAds ?? (patch.plan ? def.maxAds : old.limits.maxAds), maxUsers: patch.limits?.maxUsers ?? (patch.plan ? def.maxUsers : old.limits.maxUsers)},
    features: {...old.features, ...(patch.features || {}), ...(patch.plan ? def.features : {})},
    meta: {...old.meta, ...(patch.meta || {})}
  });
  tenants[index] = next;
  await saveTenants(tenants);
  return next;
}

export async function getUsers() {
  return readJson(usersFile, []);
}

export async function saveUsers(users) {
  await writeJson(usersFile, users);
}

export async function getUserById(id) {
  const users = await getUsers();
  return users.find(u => u.id === id) || null;
}

export async function getUserByUsername(username) {
  const users = await getUsers();
  return users.find(u => u.username === username) || null;
}


export async function getUsersForTenant(tenantId) {
  const users = await getUsers();
  return users.filter(u => (u.tenantId || SYSTEM_TENANT_ID) === tenantId).map(publicUser);
}

export async function saveUser(user) {
  const users = await getUsers();
  const index = users.findIndex(u => u.id === user.id);
  if (index >= 0) users[index] = user;
  else users.push(user);
  await saveUsers(users);
  return user;
}

function isTenantActive(tenant) {
  if (!tenant || tenant.active === false) return false;
  if (tenant.subscriptionEnd && new Date(tenant.subscriptionEnd).getTime() < Date.now()) return false;
  return true;
}

export {isTenantActive};

export async function getCustomerSummaries() {
  const [tenants, users] = await Promise.all([getTenants(), getUsers()]);
  return tenants
    .filter(t => t.id !== SYSTEM_TENANT_ID && !t.archivedAt)
    .map(t => {
      const account = users.find(u => u.tenantId === t.id && u.role !== 'OPERATOR') || users.find(u => u.tenantId === t.id);
      const expired = t.subscriptionEnd && new Date(t.subscriptionEnd).getTime() < Date.now();
      return {
        ...t,
        active: Boolean(t.active && !expired),
        expired: Boolean(expired),
        user: account ? publicUser(account) : null
      };
    });
}

export function publicUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    username: user.username,
    role: user.role,
    tenantId: user.tenantId,
    active: user.active !== false,
    fullName: user.fullName || '',
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt || null
  };
}

export function publicTenant(tenant) {
  if (!tenant) return null;
  const safe = clone(tenant);
  if (safe.meta) {
    const hasMetaToken = Boolean(safe.meta.accessToken || safe.meta.metaAccessToken);
    const hasInstagramToken = Boolean(safe.meta.instagramAccessToken);
    delete safe.meta.accessToken; delete safe.meta.metaAccessToken; delete safe.meta.instagramAccessToken;
    safe.meta.hasAccessToken = hasMetaToken; safe.meta.hasInstagramAccessToken = hasInstagramToken;
  }
  return safe;
}

export async function deleteTenantCascade(tenantId) {
  if (!tenantId || tenantId === SYSTEM_TENANT_ID) throw new Error('Sistem hesabı silinemez.');
  const tenants = await getTenants();
  const tenant = tenants.find(t => t.id === tenantId);
  if (!tenant) throw new Error('Müşteri bulunamadı.');
  await saveTenants(tenants.filter(t => t.id !== tenantId));

  const users = await getUsers();
  await saveUsers(users.filter(u => u.tenantId !== tenantId));

  const settings = await readJson(settingsFile, {});
  if (settings && typeof settings === 'object' && !Array.isArray(settings)) {
    delete settings[tenantId];
    await writeJson(settingsFile, settings);
  }

  const logs = await readJson(logsFile, []);
  await writeJson(logsFile, logs.filter(x => (x.tenantId || SYSTEM_TENANT_ID) !== tenantId));

  const posts = await readJson(postsFile, []);
  const removedPosts = posts.filter(x => (x.tenantId || SYSTEM_TENANT_ID) === tenantId);
  await writeJson(postsFile, posts.filter(x => (x.tenantId || SYSTEM_TENANT_ID) !== tenantId));

  const licenses = await readJson(licensesFile, []);
  const unassigned = licenses.map(x => x.tenantId === tenantId ? ({...x, tenantId:null, status:'UNUSED', assignedAt:null}) : x);
  await writeJson(licensesFile, unassigned);

  return {tenant, removedPostsCount: removedPosts.length, removedUserCount: users.filter(u => u.tenantId === tenantId).length};
}

export async function getSettings(tenantId = SYSTEM_TENANT_ID) {
  const raw = await readJson(settingsFile, {});
  let map;
  if (raw && typeof raw === 'object' && !Array.isArray(raw) && ('weeklyBudget' in raw || 'messageCostLimit' in raw)) {
    map = {[SYSTEM_TENANT_ID]: {...defaults, ...raw}};
    await writeJson(settingsFile, map);
  } else {
    map = raw || {};
  }
  if (!map[tenantId]) {
    map[tenantId] = clone(defaults);
    await writeJson(settingsFile, map);
  }
  return clone({...defaults, ...map[tenantId], selection: {...defaults.selection, ...(map[tenantId].selection || {})}});
}

export async function saveSettings(tenantId, input) {
  if (typeof tenantId === 'object') {
    input = tenantId;
    tenantId = SYSTEM_TENANT_ID;
  }
  const raw = await readJson(settingsFile, {});
  const old = await getSettings(tenantId);
  const next = {...old, ...(input || {}), selection: {...old.selection, ...((input || {}).selection || {})}};
  next.weeklyBudget = Math.max(0, Number(next.weeklyBudget));
  next.messageCostLimit = Math.max(0, Number(next.messageCostLimit));
  next.minSpendBeforeDecision = Math.max(0, Number(next.minSpendBeforeDecision));
  next.weeklyDay = Math.max(1, Math.min(7, Number(next.weeklyDay)));
  next.startHour = Math.max(0, Math.min(23, Number(next.startHour)));
  next.startMinute = Math.max(0, Math.min(59, Number(next.startMinute)));
  next.durationHours = Math.max(1, Math.min(168, Number(next.durationHours)));
  next.minDailyBudget = Math.max(1, Number(next.minDailyBudget));
  next.maxDailyBudget = Math.max(next.minDailyBudget, Number(next.maxDailyBudget));
  next.earlyWindowHours = Math.max(1, Math.min(24, Number(next.earlyWindowHours)));
  next.earlyMinSpendBeforeDecision = Math.max(0, Number(next.earlyMinSpendBeforeDecision));
  next.earlyMessageCostLimit = Math.max(0, Number(next.earlyMessageCostLimit));
  next.earlyNoMessageSpendThreshold = Math.max(0, Number(next.earlyNoMessageSpendThreshold));
  next.earlyBudgetReductionPercent = Math.max(5, Math.min(90, Number(next.earlyBudgetReductionPercent)));
  next.autoPublish = Boolean(next.autoPublish);
  next.enabled = Boolean(next.enabled);
  next.aiEnabled = next.aiEnabled !== false;
  next.autoMediaType = next.autoMediaType !== false;
  next.preventDuplicateContent = next.preventDuplicateContent !== false;
  next.publishMaxRetries = Math.max(1, Math.min(5, Number(next.publishMaxRetries || 3)));
  next.publishRetryMinutes = Math.max(1, Math.min(120, Number(next.publishRetryMinutes || 10)));
  next.aiTone = String(next.aiTone || 'samimi ve güven veren').slice(0,80);
  next.aiGoal = String(next.aiGoal || 'mesaj').slice(0,80);
  next.aiLanguage = String(next.aiLanguage || 'Türkçe').slice(0,30);
  const map = (raw && typeof raw === 'object' && !Array.isArray(raw) && !('weeklyBudget' in raw)) ? raw : {[SYSTEM_TENANT_ID]: old};
  map[tenantId] = next;
  await writeJson(settingsFile, map);
  return next;
}

export async function getLogs(tenantId = SYSTEM_TENANT_ID, limit = 200) {
  if (typeof tenantId !== 'string') {
    limit = tenantId;
    tenantId = SYSTEM_TENANT_ID;
  }
  const x = await readJson(logsFile, []);
  const filtered = x.filter(item => (item.tenantId || SYSTEM_TENANT_ID) === tenantId);
  return filtered.slice(0, Math.max(1, Math.min(1000, Number(limit))));
}

export async function addLog(tenantId, entry) {
  if (typeof tenantId === 'object') {
    entry = tenantId;
    tenantId = SYSTEM_TENANT_ID;
  }
  const logs = await getLogs(tenantId, 1000);
  logs.unshift({...entry, tenantId, at: new Date().toISOString()});
  const all = await readJson(logsFile, []);
  const others = all.filter(item => (item.tenantId || SYSTEM_TENANT_ID) !== tenantId);
  await writeJson(logsFile, [...logs, ...others].slice(0, 5000));
}

export async function getPosts(tenantId = SYSTEM_TENANT_ID) {
  const x = await readJson(postsFile, []);
  return x.filter(item => (item.tenantId || SYSTEM_TENANT_ID) === tenantId);
}

export async function savePosts(tenantId, posts) {
  if (Array.isArray(tenantId)) {
    posts = tenantId;
    tenantId = SYSTEM_TENANT_ID;
  }
  const all = await readJson(postsFile, []);
  const prepared = posts.map(p => ({...p, tenantId}));
  const others = all.filter(item => (item.tenantId || SYSTEM_TENANT_ID) !== tenantId);
  await writeJson(postsFile, [...prepared, ...others]);
}

export async function createLicense({plan = 'BASIC', days = 30, tenantId = null}) {
  const p = String(plan).toUpperCase();
  if (!PLAN_DEFINITIONS[p]) throw new Error('Geçersiz paket.');
  const licenses = await readJson(licensesFile, []);
  let code = '';
  do {
    code = `ADV-${crypto.randomBytes(2).toString('hex').toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
  } while (licenses.some(x => x.code === code));
  const license = {
    id: `lic_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`,
    code,
    plan: p,
    days: Math.max(1, Number(days) || 30),
    tenantId: tenantId || null,
    status: tenantId ? 'ASSIGNED' : 'UNUSED',
    createdAt: new Date().toISOString(),
    assignedAt: tenantId ? new Date().toISOString() : null
  };
  licenses.unshift(license);
  await writeJson(licensesFile, licenses);
  return license;
}

export async function getLicenses() {
  return readJson(licensesFile, []);
}

export async function assignLicense(licenseId, tenantId) {
  const licenses = await getLicenses();
  const license = licenses.find(x => x.id === licenseId);
  if (!license) throw new Error('Lisans bulunamadı.');
  if (license.status === 'USED' || license.tenantId) throw new Error('Bu lisans zaten kullanılmış.');
  const tenant = await getTenant(tenantId);
  if (!tenant) throw new Error('Müşteri bulunamadı.');
  const now = new Date();
  const currentEnd = tenant.subscriptionEnd && new Date(tenant.subscriptionEnd).getTime() > now.getTime()
    ? new Date(tenant.subscriptionEnd)
    : now;
  const newEnd = new Date(currentEnd.getTime() + Number(license.days) * 86400000);
  await updateTenant(tenantId, {subscriptionEnd: newEnd.toISOString(), plan: license.plan, active: true});
  license.tenantId = tenantId;
  license.status = 'USED';
  license.assignedAt = now.toISOString();
  await writeJson(licensesFile, licenses);
  return license;
}

export async function adminStats() {
  const [customers, users, licenses] = await Promise.all([getCustomerSummaries(), getUsers(), getLicenses()]);
  const active = customers.filter(c => c.active).length;
  const expiringSoon = customers.filter(c => c.subscriptionEnd && new Date(c.subscriptionEnd).getTime() > Date.now() && new Date(c.subscriptionEnd).getTime() <= Date.now() + 7 * 86400000).length;
  return {
    totalCustomers: customers.length,
    activeCustomers: active,
    passiveCustomers: customers.length - active,
    expiringSoon,
    totalUsers: users.length,
    unusedLicenses: licenses.filter(l => l.status === 'UNUSED').length
  };
}
