import {PLAN_DEFINITIONS, getTenant, updateTenant, getPosts, getLogs, getSettings, getUsersForTenant, getLicenses, getCustomerSummaries} from './store.js';
import {config} from './config.js';

function n(v, fallback = 0) { const x = Number(v); return Number.isFinite(x) ? x : fallback; }

export async function analyticsSummary(tenantId) {
  const [tenant, posts, logs, settings, users] = await Promise.all([
    getTenant(tenantId), getPosts(tenantId), getLogs(tenantId, 500), getSettings(tenantId), getUsersForTenant(tenantId)
  ]);
  const byType = {};
  for (const item of logs) byType[item.type || 'OTHER'] = (byType[item.type || 'OTHER'] || 0) + 1;
  const published = posts.filter(p => String(p.publishStatus || '').toUpperCase() === 'PUBLISHED').length;
  const pending = posts.length - published;
  const activeUsers = users.filter(u => u.active !== false).length;
  const subscriptionEnd = tenant?.subscriptionEnd || null;
  const remainingDays = subscriptionEnd ? Math.max(0, Math.ceil((new Date(subscriptionEnd).getTime() - Date.now()) / 86400000)) : null;
  return {
    tenantId,
    plan: tenant?.plan || 'BASIC',
    posts: posts.length,
    publishedPosts: published,
    pendingPosts: pending,
    logCount: logs.length,
    activeUsers,
    totalUsers: users.length,
    weeklyBudget: n(settings.weeklyBudget),
    messageCostLimit: n(settings.messageCostLimit, 8),
    remainingSubscriptionDays: remainingDays,
    eventCounts: byType,
    generatedAt: new Date().toISOString()
  };
}

export async function aiInsights(tenantId) {
  const [tenant, settings, posts, logs] = await Promise.all([
    getTenant(tenantId), getSettings(tenantId), getPosts(tenantId), getLogs(tenantId, 300)
  ]);
  const published = posts.filter(p => String(p.publishStatus || '').toUpperCase() === 'PUBLISHED').length;
  const insights = [];
  if (!tenant?.meta?.connected) {
    insights.push({type:'INFO', title:'Meta bağlantısı bekleniyor', body:'Gerçek reklam performansı bağlandığında analizler mesaj maliyeti, CTR ve harcama verisi üzerinden çalışacaktır.'});
  }
  if (settings.enabled !== true) {
    insights.push({type:'ACTION', title:'Otomasyon pasif', body:'Otomasyon açıldığında planlanan kontroller ve karar motoru zamanlanmış şekilde çalışabilir.'});
  }
  if (posts.length === 0) {
    insights.push({type:'ACTION', title:'İlk içeriğini ekle', body:'Tek bir içerik yükleyerek planlama kuyruğunu oluşturabilirsin.'});
  } else if (published === 0) {
    insights.push({type:'INFO', title:'Yayın bekleyen içerikler var', body:`${posts.length} içerik kaydı var; henüz yayınlanmış içerik görünmüyor.`});
  } else {
    insights.push({type:'GOOD', title:'İçerik akışı aktif', body:`${published} içerik yayınlanmış durumda. Karar motoru için performans verisi geldikçe öneriler ayrıntılanır.`});
  }
  if (n(settings.earlyMessageCostLimit,8) > 0) {
    insights.push({type:'RULE', title:'12 saatlik hedef', body:`Erken karar hedefi ${n(settings.earlyMessageCostLimit,8).toFixed(2)} TL olarak ayarlı.`});
  }
  if (logs.length > 0) {
    const errors = logs.filter(x => String(x.type || '').toUpperCase().includes('ERROR')).length;
    insights.push(errors ? {type:'WARN', title:'Sistem loglarını kontrol et', body:`Son kayıtlar içinde ${errors} hata tipi bulundu.`} : {type:'GOOD', title:'Son işlemler temiz', body:'Son işlem kayıtlarında ERROR tipi görünmüyor.'});
  }
  return {generatedAt:new Date().toISOString(),mode:'RULE_BASED',insights};
}

export async function billingSummary(tenantId) {
  const tenant = await getTenant(tenantId);
  const p = tenant?.plan || 'BASIC';
  const def = PLAN_DEFINITIONS[p] || PLAN_DEFINITIONS.BASIC;
  const end = tenant?.subscriptionEnd ? new Date(tenant.subscriptionEnd) : null;
  const days = end ? Math.max(0, Math.ceil((end.getTime()-Date.now())/86400000)) : 0;
  const monthlyCatalog = {BASIC:499, PRO:1499, AGENCY:3999, ENTERPRISE:9999};
  return {plan:p, planName:def.name, limits:def, subscriptionStart:tenant?.subscriptionStart||null, subscriptionEnd:tenant?.subscriptionEnd||null, remainingDays:days, estimatedMonthlyPriceTRY:monthlyCatalog[p]||monthlyCatalog.BASIC, currency:'TRY', billingMode:'MANUAL_LICENSE'};
}

export async function brandingSummary(tenantId) {
  const tenant = await getTenant(tenantId);
  return tenant?.branding || {appName:'Advise Digital',logoUrl:'',primaryColor:'#4F46E5',supportEmail:''};
}

export async function saveBranding(tenantId, input) {
  const current = await brandingSummary(tenantId);
  const next = {
    appName: String(input?.appName ?? current.appName).trim().slice(0, 80) || 'Advise Digital',
    logoUrl: String(input?.logoUrl ?? current.logoUrl).trim().slice(0, 500),
    primaryColor: String(input?.primaryColor ?? current.primaryColor).trim().slice(0, 20) || '#4F46E5',
    supportEmail: String(input?.supportEmail ?? current.supportEmail).trim().slice(0, 160)
  };
  await updateTenant(tenantId, {branding: next});
  return next;
}

export async function notificationPrefs(tenantId) {
  const tenant = await getTenant(tenantId);
  return tenant?.notificationPrefs || {email:true,push:true,highCost:true,subscription:true};
}

export async function saveNotificationPrefs(tenantId, input) {
  const current = await notificationPrefs(tenantId);
  const next = {
    email: input?.email === undefined ? current.email : Boolean(input.email),
    push: input?.push === undefined ? current.push : Boolean(input.push),
    highCost: input?.highCost === undefined ? current.highCost : Boolean(input.highCost),
    subscription: input?.subscription === undefined ? current.subscription : Boolean(input.subscription)
  };
  await updateTenant(tenantId, {notificationPrefs: next});
  return next;
}

export async function securityOverview(tenantId) {
  const users = await getUsersForTenant(tenantId);
  const tenant = await getTenant(tenantId);
  return {
    environment: config.environment,
    jwtSessionDays: 7,
    httpsRecommended: !String(config.publicBaseUrl).startsWith('https://'),
    databaseConfigured: Boolean(config.databaseUrl),
    multiTenant: true,
    tenantIsolated: true,
    userCount: users.length,
    activeUserCount: users.filter(u=>u.active!==false).length,
    metaConnected: Boolean(tenant?.meta?.connected)
  };
}

export function planCatalog() {
  const price = {BASIC:499, PRO:1499, AGENCY:3999, ENTERPRISE:9999};
  return Object.entries(PLAN_DEFINITIONS).map(([code, def]) => ({code, ...def, monthlyPriceTRY: price[code] || 0}));
}

export async function adminOverview() {
  const [customers, licenses] = await Promise.all([getCustomerSummaries(), getLicenses()]);
  const totalMRR = customers.filter(c=>c.active).reduce((sum,c)=>sum + ({BASIC:499,PRO:1499,AGENCY:3999,ENTERPRISE:9999}[c.plan]||0),0);
  return {totalMRREstimateTRY: totalMRR, customersByPlan: customers.reduce((m,c)=>{m[c.plan]=(m[c.plan]||0)+1;return m;},{}), unusedLicenses: licenses.filter(l=>l.status==='UNUSED').length, generatedAt:new Date().toISOString()};
}
