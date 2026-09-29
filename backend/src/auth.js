import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import {config} from './config.js';
import {
  getUsers,
  saveUsers,
  getUserById,
  getUserByUsername,
  getTenant,
  createTenant,
  getUsersForTenant,
  saveUser,
  publicUser,
  publicTenant,
  isTenantActive
} from './store.js';

export async function ensureAdmin() {
  const users = await getUsers();
  const existing = users.find(u => u.username === config.adminUsername);
  if (!existing) {
    const passwordHash = await bcrypt.hash(config.adminPassword, 12);
    users.push({
      id: 'admin',
      username: config.adminUsername,
      passwordHash,
      role: 'ADMIN',
      tenantId: 'system',
      active: true,
      fullName: 'System Admin',
      createdAt: new Date().toISOString()
    });
    await saveUsers(users);
  } else {
    let changed = false;
    if (!existing.tenantId) { existing.tenantId = 'system'; changed = true; }
    if (existing.role !== 'ADMIN') { existing.role = 'ADMIN'; changed = true; }
    if (existing.active === false) { existing.active = true; changed = true; }
    // Keep the persisted admin password aligned with ADMIN_PASSWORD from .env.
    // This also repairs a stale/overwritten users.json without exposing the password.
    if (!(await bcrypt.compare(config.adminPassword, existing.passwordHash || ''))) {
      existing.passwordHash = await bcrypt.hash(config.adminPassword, 12);
      changed = true;
    }
    if (changed) await saveUsers(users);
  }
}

export async function login(username, password) {
  const user = await getUserByUsername(username);
  if (!user || user.active === false) return null;
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return null;

  const tenant = await getTenant(user.tenantId || 'system');
  if (user.role !== 'ADMIN' && (!tenant || !isTenantActive(tenant))) {
    return {inactive: true, message: 'Hesap pasif veya abonelik süresi dolmuş.'};
  }

  user.lastLoginAt = new Date().toISOString();
  await saveUser(user);

  const token = jwt.sign(
    {sub: user.id, username: user.username, role: user.role, tenantId: user.tenantId || 'system'},
    config.jwtSecret,
    {expiresIn: '7d'}
  );

  return {token, user: publicUser(user), tenant: publicTenant(tenant)};
}

export async function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return res.status(401).json({error: 'Authentication required'});
  try {
    const decoded = jwt.verify(header.slice(7), config.jwtSecret);
    const user = await getUserById(decoded.sub);
    if (!user || user.active === false) return res.status(401).json({error: 'Hesap pasif.'});
    const tenant = await getTenant(user.tenantId || 'system');
    if (user.role !== 'ADMIN' && (!tenant || !isTenantActive(tenant))) {
      return res.status(403).json({error: 'Hesap pasif veya abonelik süresi dolmuş.'});
    }
    req.user = publicUser(user);
    req.tenant = publicTenant(tenant);
    next();
  } catch {
    return res.status(401).json({error: 'Invalid or expired session'});
  }
}

export function allowRoles(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) return res.status(403).json({error: 'Bu işlem için yetkiniz yok.'});
    next();
  };
}

export function requireFeature(feature) {
  return (req, res, next) => {
    if (req.user?.role === 'ADMIN') return next();
    if (req.tenant?.features?.[feature] === true) return next();
    return res.status(403).json({error: `Bu özellik ${req.tenant?.plan || ''} paketinde kapalı.`});
  };
}


export async function createTenantUser({tenantId, username, password, fullName = '', role = 'OPERATOR'}) {
  const tenant = await getTenant(tenantId);
  if (!tenant) throw new Error('Müşteri bulunamadı.');
  const cleanUsername = String(username || '').trim().toLowerCase();
  const cleanPassword = String(password || '');
  if (!cleanUsername || cleanUsername.length < 3) throw new Error('Kullanıcı adı en az 3 karakter olmalı.');
  if (cleanPassword.length < 6) throw new Error('Şifre en az 6 karakter olmalı.');
  if (await getUserByUsername(cleanUsername)) throw new Error('Bu kullanıcı adı zaten kullanımda.');
  const existing = await getUsersForTenant(tenantId);
  const maxUsers = Number(tenant.limits?.maxUsers || 1);
  if (existing.length >= maxUsers) throw new Error(`Paket kullanıcı limitine ulaşıldı (${maxUsers}).`);
  const requestedRole = String(role || 'OPERATOR').toUpperCase();
  const allowedRole = ['MANAGER', 'OPERATOR', 'VIEWER'].includes(requestedRole) ? requestedRole : 'OPERATOR';
  const user = {
    id: `user_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    username: cleanUsername,
    passwordHash: await bcrypt.hash(cleanPassword, 12),
    role: allowedRole,
    tenantId,
    active: true,
    fullName: String(fullName || '').trim(),
    createdAt: new Date().toISOString()
  };
  const users = await getUsers();
  users.push(user);
  await saveUsers(users);
  return publicUser(user);
}

export async function changeOwnPassword(userId, currentPassword, newPassword) {
  const user = await getUserById(userId);
  if (!user) throw new Error('Kullanıcı bulunamadı.');
  if (String(newPassword || '').length < 6) throw new Error('Yeni şifre en az 6 karakter olmalı.');
  const ok = await bcrypt.compare(String(currentPassword || ''), user.passwordHash);
  if (!ok) throw new Error('Mevcut şifre hatalı.');
  user.passwordHash = await bcrypt.hash(String(newPassword), 12);
  await saveUser(user);
  return publicUser(user);
}

export async function createCustomerAccount({companyName, username, password, plan = 'BASIC', days = 30, fullName = ''}) {
  const cleanUsername = String(username || '').trim().toLowerCase();
  const cleanPassword = String(password || '');
  if (!companyName?.trim()) throw new Error('Şirket adı gerekli.');
  if (!cleanUsername || cleanUsername.length < 3) throw new Error('Kullanıcı adı en az 3 karakter olmalı.');
  if (cleanPassword.length < 6) throw new Error('Şifre en az 6 karakter olmalı.');
  if (await getUserByUsername(cleanUsername)) throw new Error('Bu kullanıcı adı zaten kullanımda.');
  const tenant = await createTenant({companyName, plan, days});
  const users = await getUsers();
  const user = {
    id: `user_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    username: cleanUsername,
    passwordHash: await bcrypt.hash(cleanPassword, 12),
    role: 'CUSTOMER_ADMIN',
    tenantId: tenant.id,
    active: true,
    fullName: String(fullName || '').trim(),
    createdAt: new Date().toISOString()
  };
  users.push(user);
  await saveUsers(users);
  return {user: publicUser(user), tenant: publicTenant(tenant)};
}

export async function resetUserPassword(userId, newPassword) {
  if (String(newPassword || '').length < 6) throw new Error('Yeni şifre en az 6 karakter olmalı.');
  const user = await getUserById(userId);
  if (!user) throw new Error('Kullanıcı bulunamadı.');
  user.passwordHash = await bcrypt.hash(String(newPassword), 12);
  await saveUser(user);
  return publicUser(user);
}
