import express from 'express';
import cors from 'cors';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import jwt from 'jsonwebtoken';
import {config} from './config.js';
import {ensureAdmin, login, authMiddleware, allowRoles, createCustomerAccount, resetUserPassword, createTenantUser, changeOwnPassword} from './auth.js';
import {
  getSettings, saveSettings, getLogs, addLog, getPosts, savePosts,
  getTenant, updateTenant, getCustomerSummaries, adminStats, getUsersForTenant, getUserById, saveUser, publicUser,
  createLicense, getLicenses, assignLicense, deleteTenantCascade
} from './store.js';
import {getCampaigns, getAdSets, getAds, insights, setStatus, updateAdSetBudget, metaHealth, getInstagramMedia, createCampaign, createAdSet, createAdCreativeFromInstagramMedia, createAd} from './meta.js';
import {optimizeAds} from './optimizer.js';
import {startScheduler, scheduleUploadedPost, scheduleUploadedPosts, publishDuePosts} from './scheduler.js';
import {analyticsSummary, aiInsights, billingSummary, brandingSummary, saveBranding, notificationPrefs, saveNotificationPrefs, securityOverview, planCatalog, adminOverview} from './v78.js';
import {dbHealth} from './db.js';
import {aiAdvisor, performanceSummary, getAlerts, createAlert, markAlert, getLeads, createLead, updateLead, deleteLead, analyzeCreative, getCreatives, simulateBudget, createExperiment, getExperiments, updateExperiment, buildUtm, reportPack, agencyOverview} from './pro.js';
import {generateContentPack, generateCaption, generateCaptionVariants, scoreCreative, aiStatus} from './ai.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadDir = path.resolve(__dirname, '../uploads');
await fs.mkdir(uploadDir, {recursive: true});

function publicBaseUrlForRequest(req) {
  const forwardedProto = String(req.get('x-forwarded-proto') || '').split(',')[0].trim();
  const forwardedHost = String(req.get('x-forwarded-host') || '').split(',')[0].trim();
  const host = forwardedHost || String(req.get('host') || '').split(',')[0].trim();
  const proto = forwardedProto || req.protocol || 'http';
  if (host && proto === 'https') return `https://${host}`;
  return config.publicBaseUrl;
}

const IMAGE_EXTENSIONS = new Set([
  '.jpg', '.jpeg', '.jfif', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif', '.avif', '.tif', '.tiff'
]);
const VIDEO_EXTENSIONS = new Set([
  '.mp4', '.mov', '.m4v', '.webm', '.avi', '.mkv', '.3gp', '.mpeg', '.mpg', '.ogv'
]);

function fileExtension(name = '') {
  const value = String(name || '').toLowerCase().trim();
  const dot = value.lastIndexOf('.');
  return dot >= 0 ? value.slice(dot) : '';
}

function mediaKind(file = {}) {
  const mime = String(file.mimetype || '').toLowerCase().trim();
  const ext = fileExtension(file.originalname);
  if (mime.startsWith('image/') || IMAGE_EXTENSIONS.has(ext)) return 'IMAGE';
  if (mime.startsWith('video/') || VIDEO_EXTENSIONS.has(ext)) return 'VIDEO';
  return 'OTHER';
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const safe = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}-${safe}`);
  }
});

const upload = multer({
  storage,
  limits: {fileSize: 100 * 1024 * 1024},
  fileFilter: (_req, file, cb) => {
    const kind = mediaKind(file);
    if (kind === 'OTHER') {
      return cb(new Error(
        `Desteklenmeyen medya formatı: ${file.originalname}. JPG, JPEG, PNG, WEBP, GIF, BMP, HEIC/HEIF, AVIF, TIFF veya MP4, MOV, M4V, WEBM, AVI, MKV, 3GP, MPEG/MPG, OGV kullan.`
      ));
    }
    cb(null, true);
  }
});

function hasMetaCredentials(credentials = {}) {
  const accessToken = String(
    credentials?.accessToken ||
    credentials?.metaAccessToken ||
    config.metaAccessToken ||
    ''
  ).trim();
  const adAccountId = String(
    credentials?.adAccountId ||
    config.adAccountId ||
    ''
  ).replace(/^act_/, '').trim();
  return Boolean(accessToken && adAccountId);
}

function hasInstagramCredentials(credentials = {}) {
  const instagramUserId = String(
    credentials?.instagramUserId ||
    config.instagramUserId ||
    ''
  ).trim();
  const instagramAccessToken = String(
    credentials?.instagramAccessToken ||
    config.instagramAccessToken ||
    ''
  ).trim();
  return Boolean(instagramUserId && instagramAccessToken);
}
await ensureAdmin();

const app = express();
app.set('trust proxy', true);
app.use(cors());
app.use(express.json({limit: '2mb'}));
app.use('/uploads', express.static(uploadDir));

app.get('/health', (_req, res) => res.json({ok: true, app: 'AdVise AI', version: config.appVersion}));

app.post('/api/auth/login', async (req, res) => {
  try {
    const result = await login(String(req.body?.username || ''), String(req.body?.password || ''));
    if (!result) return res.status(401).json({error: 'Kullanıcı adı veya şifre hatalı.'});
    if (result.inactive) return res.status(403).json({error: result.message});
    res.json(result);
  } catch (e) {
    res.status(500).json({error: e.message});
  }
});

app.use('/api', authMiddleware);

app.get('/api/system/health', async (_req, res) => {
  try { res.json({app:'AdVise AI', version:config.appVersion, environment:config.environment, database: await dbHealth()}); }
  catch (e) { res.status(503).json({error:e.message}); }
});

app.get('/api/me', async (req, res) => {
  res.json({user: req.user, tenant: req.tenant});
});

app.post('/api/profile/password', async (req, res) => {
  try {
    const user = await changeOwnPassword(req.user.id, req.body?.currentPassword, req.body?.newPassword);
    res.json({user});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.get('/api/users', async (req, res) => {
  try { res.json({data: await getUsersForTenant(req.user.tenantId)}); }
  catch (e) { res.status(400).json({error: e.message}); }
});

app.post('/api/users', async (req, res) => {
  try {
    if (!['ADMIN', 'CUSTOMER_ADMIN'].includes(req.user.role)) return res.status(403).json({error: 'Bu işlem için yetkiniz yok.'});
    const user = await createTenantUser({
      tenantId: req.user.tenantId,
      username: req.body?.username,
      password: req.body?.password,
      fullName: req.body?.fullName,
      role: String(req.body?.role || 'OPERATOR').toUpperCase()
    });
    await addLog(req.user.tenantId, {type: 'USER_CREATED', userId: user.id, username: user.username});
    res.status(201).json({user});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.post('/api/users/:id/toggle', async (req, res) => {
  try {
    if (!['ADMIN', 'CUSTOMER_ADMIN'].includes(req.user.role)) return res.status(403).json({error: 'Bu işlem için yetkiniz yok.'});
    const user = await getUserById(req.params.id);
    if (!user || user.tenantId !== req.user.tenantId) return res.status(404).json({error: 'Kullanıcı bulunamadı.'});
    if (user.id === req.user.id) return res.status(400).json({error: 'Kendi hesabınızı bu ekrandan pasife alamazsınız.'});
    user.active = user.active === false;
    await saveUser(user);
    await addLog(req.user.tenantId, {type: 'USER_STATUS_CHANGED', userId: user.id, active: user.active});
    res.json({user: publicUser(user)});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.post('/api/users/:id/reset-password', async (req, res) => {
  try {
    if (!['ADMIN', 'CUSTOMER_ADMIN'].includes(req.user.role)) return res.status(403).json({error: 'Bu işlem için yetkiniz yok.'});
    const user = await getUserById(req.params.id);
    if (!user || user.tenantId !== req.user.tenantId) return res.status(404).json({error: 'Kullanıcı bulunamadı.'});
    const updated = await resetUserPassword(user.id, req.body?.password);
    await addLog(req.user.tenantId, {type: 'USER_PASSWORD_RESET', userId: user.id});
    res.json({user: updated});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.get('/api/dashboard', async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const tenantRaw = await getTenant(tenantId);
    const settings = await getSettings(tenantId);
    const [posts, logs] = await Promise.all([getPosts(tenantId), getLogs(tenantId, 50)]);
    const credentials = tenantId === 'system' ? {} : (tenantRaw?.meta?.connected ? tenantRaw.meta : null);

    let campaigns = [], adsets = [], ads = [];
    const metaReady = hasMetaCredentials(credentials || {});
    if (metaReady) {
      const [campaignsResp, adsetsResp, adsResp] = await Promise.all([
        getCampaigns(credentials || {}),
        getAdSets(credentials || {}),
        getAds(credentials || {})
      ]);
      campaigns = campaignsResp.data || [];
      adsets = adsetsResp.data || [];
      ads = adsResp.data || [];
    }

    res.json({
      me: req.user,
      tenant: req.tenant,
      campaigns,
      adsets,
      ads,
      settings,
      logs,
      posts,
      metaAvailable: metaReady,
      mode: metaReady ? 'CONNECTED' : 'PLANNING'
    });
  } catch (e) {
    res.status(502).json({error: e.message});
  }
});

// Meta data works for the system admin fallback account or the currently connected tenant.
app.get('/api/campaigns', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : tenant?.meta;
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Meta bağlantısı kurulmadı.'});
    }
    res.json(await getCampaigns(credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/adsets', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : tenant?.meta;
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Meta bağlantısı kurulmadı.'});
    }
    res.json(await getAdSets(credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/ads', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : tenant?.meta;
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Meta bağlantısı kurulmadı.'});
    }
    res.json(await getAds(credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/instagram/media', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : (tenant?.meta || {});
    const limit = Math.max(1, Math.min(100, Number(req.query.limit || 50)));
    if (!hasInstagramCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Instagram bağlantısı kurulmadı.'});
    }
    res.json(await getInstagramMedia(credentials, limit));
  } catch (e) { res.status(502).json({error: e.message}); }
});

app.post('/api/ads/create', allowRoles('ADMIN','CUSTOMER_ADMIN','OPERATOR'), async (req, res) => {
  let stage = 'validation';
  let createdCampaignId = '';
  let createdAdSetId = '';
  let createdCreativeId = '';
  let createdAdId = '';
  try {
    const tenantId = req.user.tenantId;
    const tenant = await getTenant(tenantId);
    const credentials = tenantId === 'system' ? {} : (tenant?.meta || {});
    const mediaId = String(req.body?.instagramMediaId || '').trim();
    const dailyBudget = Number(req.body?.dailyBudget);
    if (!mediaId) return res.status(400).json({error: 'Instagram gönderisi seçmelisin.'});
    if (!Number.isFinite(dailyBudget) || dailyBudget < 1) return res.status(400).json({error: 'Günlük bütçe en az 1 TL olmalı.'});

    const campaignName = String(req.body?.campaignName || 'AdVise AI Kampanyası').trim().slice(0, 120);
    const adSetName = String(req.body?.adSetName || 'AdVise AI Ad Set').trim().slice(0, 120);
    const adName = String(req.body?.adName || 'AdVise AI Reklamı').trim().slice(0, 120);
    const activate = req.body?.activate !== false;

    console.log(`[ADS CREATE] start media=${mediaId} budget=${dailyBudget} activate=${activate}`);

    stage = 'campaign';
    const campaign = await createCampaign({
      name: campaignName,
      objective: 'OUTCOME_ENGAGEMENT',
      status: 'PAUSED',
      credentials
    });
    createdCampaignId = String(campaign?.id || '');
    console.log(`[ADS CREATE] campaign=${campaign?.id || '-'}`);

    stage = 'adset';
    const adSet = await createAdSet({
      name: adSetName,
      campaignId: campaign.id,
      dailyBudget,
      optimizationGoal: 'CONVERSATIONS',
      billingEvent: 'IMPRESSIONS',
      destinationType: 'INSTAGRAM_DIRECT',
      credentials
    });
    createdAdSetId = String(adSet?.id || '');
    console.log(`[ADS CREATE] adset=${adSet?.id || '-'}`);

    stage = 'creative';
    const creative = await createAdCreativeFromInstagramMedia({
      name: adName,
      instagramMediaId: mediaId,
      instagramUserId: tenantId === 'system'
        ? String(config.instagramUserId || '').trim()
        : String(tenant?.meta?.instagramUserId || '').trim(),
      pageId: tenantId === 'system'
        ? String(config.metaPageId || '').trim()
        : String(tenant?.meta?.pageId || '').trim(),
      credentials: {
        ...credentials,
        instagramUserId: tenantId === 'system'
          ? String(config.instagramUserId || '').trim()
          : String(tenant?.meta?.instagramUserId || '').trim(),
        instagramUsername: tenantId === 'system'
          ? String(config.instagramUsername || '').trim()
          : String(tenant?.meta?.instagramUsername || '').trim()
      }
    });
    createdCreativeId = String(creative?.id || '');
    console.log(`[ADS CREATE] creative=${creative?.id || '-'}`);

    stage = 'ad';
    const ad = await createAd({
      name: adName,
      adsetId: adSet.id,
      creativeId: creative.id,
      status: 'PAUSED',
      credentials
    });
    createdAdId = String(ad?.id || '');
    console.log(`[ADS CREATE] ad=${ad?.id || '-'}`);

    if (activate) {
      stage = 'activation';
      await Promise.all([
        setStatus(campaign.id, 'ACTIVE', credentials),
        setStatus(adSet.id, 'ACTIVE', credentials),
        setStatus(ad.id, 'ACTIVE', credentials)
      ]);
      console.log('[ADS CREATE] activated');
    }

    await addLog(tenantId, {
      type: 'WEEKLY_LAUNCH',
      source: 'APP_AD_CREATE',
      adId: ad.id,
      adSetId: adSet.id,
      campaignId: campaign.id,
      instagramMediaId: mediaId,
      launchAt: new Date().toISOString(),
      selectionScore: 1
    });

    res.status(201).json({
      campaign,
      adset: adSet,
      creative,
      ad: {...ad, status: activate ? 'ACTIVE' : 'PAUSED'},
      activated: activate
    });
  } catch (e) {
    console.error(`[ADS CREATE] failed stage=${stage}:`, e.message);

    // A failed test should not leave half-created campaigns/ad sets in the account.
    for (const [kind, id] of [
      ['ad', createdAdId],
      ['creative', createdCreativeId],
      ['adset', createdAdSetId],
      ['campaign', createdCampaignId]
    ]) {
      if (!id) continue;
      try {
        await request(id, {method:'DELETE', credentials});
        console.log(`[ADS CREATE] cleanup ${kind}=${id}`);
      } catch (cleanupError) {
        console.error(`[ADS CREATE] cleanup ${kind}=${id} failed:`, cleanupError.message);
      }
    }

    res.status(502).json({error: e.message, operation: 'ads_create', stage});
  }
});

app.get('/api/insights/:id', async (req, res) => {
  try {
    const days = Math.max(1, Math.min(30, Number(req.query.days || 7)));
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : tenant?.meta;
    res.json(await insights(req.params.id, req.query.level || 'ad', days, credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.post('/api/status/:id', allowRoles('ADMIN','CUSTOMER_ADMIN','OPERATOR'), async (req, res) => {
  try {
    const status = String(req.body?.status || '').toUpperCase();
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : tenant?.meta;
    res.json(await setStatus(req.params.id, status, credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});

app.post('/api/budget/:id', allowRoles('ADMIN','CUSTOMER_ADMIN','OPERATOR'), async (req, res) => {
  try {
    const budget = Number(req.body?.dailyBudget);
    if (!Number.isFinite(budget) || budget <= 0) return res.status(400).json({error: 'Geçersiz günlük bütçe.'});
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : tenant?.meta;
    res.json(await updateAdSetBudget(req.params.id, budget, credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});

function oauthStatePayload(req) {
  return jwt.sign({sub:req.user.id, tenantId:req.user.tenantId, purpose:'meta-oauth'}, config.jwtSecret, {expiresIn:'10m'});
}

app.get('/api/meta/health', async (req, res) => {
  try {
    const tenant=req.tenant||{};
    const credentials=req.user.tenantId==='system' ? {} : (tenant.meta||{});
    res.json(await metaHealth(credentials));
  } catch(e) { res.status(502).json({error:e.message}); }
});

app.get('/api/meta/status', async (req, res) => {
  const meta = req.tenant?.meta || {};
  const configured = Boolean(config.metaAppId && config.metaAppSecret && config.metaRedirectUri);
  res.json({
    configured,
    connected: Boolean(meta.connected),
    adAccountId: meta.adAccountId || '',
    pageId: meta.pageId || '',
    instagramUserId: meta.instagramUserId || '',
    instagramUsername: meta.instagramUsername || '',
    businessId: meta.businessId || '',
    connectedAt: meta.connectedAt || null,
    source: meta.source || null,
    metaTokenReady: Boolean(meta.metaAccessToken || meta.accessToken || config.metaAccessToken),
    instagramTokenReady: Boolean(meta.instagramAccessToken || config.instagramAccessToken),
    appId: config.metaAppId || '',
    configId: config.metaLoginConfigId || '',
    configuredTarget: {
      businessId: config.metaBusinessId || '',
      pageId: config.metaPageId || '',
      instagramUserId: config.metaInstagramUserId || '',
      adAccountId: config.adAccountId || ''
    }
  });
});

app.get('/api/meta/connect/start', allowRoles('ADMIN','CUSTOMER_ADMIN'), async (req, res) => {
  try {
    const igToken = String(process.env.INSTAGRAM_ACCESS_TOKEN || '').trim();
    const configuredIgId = String(process.env.INSTAGRAM_USER_ID || '').trim();
    const pageId = String(process.env.META_PAGE_ID || config.metaPageId || '').trim();
    const businessId = String(process.env.META_BUSINESS_ID || config.metaBusinessId || '').trim();
    const rawAdAccount = String(process.env.META_AD_ACCOUNT_ID || config.adAccountId || '').trim();
    const adAccountId = rawAdAccount.replace(/^act_/, '');

    if (!igToken || !configuredIgId) {
      return res.status(503).json({
        error: 'Instagram baÄŸlantÄ±sÄ± iÃ§in INSTAGRAM_ACCESS_TOKEN ve INSTAGRAM_USER_ID .env iÃ§inde bulunmalÄ±.'
      });
    }

    const igUrl = new URL('https://graph.instagram.com/me');
    igUrl.searchParams.set('fields', 'id,username');
    igUrl.searchParams.set('access_token', igToken);

    const igResp = await fetch(igUrl);
    const igData = JSON.parse(await igResp.text());

    if (!igResp.ok || igData.error) {
      return res.status(401).json({
        error: igData.error?.message || 'Instagram access token doÄŸrulanamadÄ±.'
      });
    }

    const instagramUserId = String(igData.id || configuredIgId);
    if (configuredIgId && instagramUserId !== configuredIgId) throw new Error(`Instagram kullanıcı ID uyuşmuyor. .env=${configuredIgId}, API=${instagramUserId}`);
    const instagramUsername = String(igData.username || '');

    const metaPatch = {
      connected: true,
      source: 'INSTAGRAM_ENV',
      accessToken: config.metaAccessToken || '',
      metaAccessToken: config.metaAccessToken || '',
      instagramAccessToken: igToken,
      adAccountId,
      pageId,
      instagramUserId,
      instagramUsername,
      businessId,
      connectedAt: new Date().toISOString()
    };

    await updateTenant(req.user.tenantId, { meta: metaPatch });

    await addLog(req.user.tenantId, {
      type: 'META_CONNECTED',
      source: 'INSTAGRAM_ENV',
      adAccountId,
      instagramUserId
    });

    res.json({
      connected: true,
      source: metaPatch.source,
      adAccountId,
      pageId,
      instagramUserId,
      instagramUsername,
      businessId,
      connectedAt: metaPatch.connectedAt
    });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});
app.get('/api/meta/oauth/callback', async (req, res) => {
  const html = (title, body) => res.status(200).type('html').send(`<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${title}</title><style>body{font-family:Arial,sans-serif;background:#f6f7fb;padding:40px}main{max-width:640px;margin:auto;background:#fff;border-radius:20px;padding:28px;box-shadow:0 12px 40px rgba(0,0,0,.08)}h1{color:#252a5a}p{line-height:1.6}</style></head><body><main><h1>${title}</h1><p>${body}</p><p>AdVise AI uygulamasına dönüp <b>Yenile</b> düğmesine basabilirsin.</p></main></body></html>`);
  try {
    const state = String(req.query.state || '');
    if (!state) return html('Bağlantı başlatılamadı', 'OAuth state bulunamadı.');
    const payload = jwt.verify(state, config.jwtSecret);
    if (payload.purpose !== 'meta-oauth') return html('Geçersiz bağlantı', 'OAuth state doğrulanamadı.');
    if (req.query.error) return html('Meta bağlantısı iptal edildi', String(req.query.error_description || req.query.error));
    const code = String(req.query.code || '');
    if (!code) return html('Meta bağlantısı tamamlanamadı', 'Meta authorization code döndürmedi.');

    const tokenUrl = new URL(`https://graph.facebook.com/${config.metaApiVersion}/oauth/access_token`);
    tokenUrl.searchParams.set('client_id', config.metaAppId);
    tokenUrl.searchParams.set('redirect_uri', config.metaRedirectUri);
    tokenUrl.searchParams.set('client_secret', config.metaAppSecret);
    tokenUrl.searchParams.set('code', code);
    const tokenResp = await fetch(tokenUrl);
    const tokenData = JSON.parse(await tokenResp.text());
    if (!tokenResp.ok || tokenData.error) throw new Error(tokenData.error?.message || 'Meta token alınamadı.');
    let accessToken = tokenData.access_token;

    // Try long-lived user token exchange; keep the short-lived token if Meta rejects the exchange.
    try {
      const longUrl = new URL(`https://graph.facebook.com/${config.metaApiVersion}/oauth/access_token`);
      longUrl.searchParams.set('grant_type','fb_exchange_token');
      longUrl.searchParams.set('client_id',config.metaAppId);
      longUrl.searchParams.set('client_secret',config.metaAppSecret);
      longUrl.searchParams.set('fb_exchange_token',accessToken);
      const lr = await fetch(longUrl);
      const ld = JSON.parse(await lr.text());
      if (lr.ok && ld.access_token) accessToken = ld.access_token;
    } catch {}

    const fields = 'id,name,instagram_business_account';
    const pagesUrl = new URL(`https://graph.facebook.com/${config.metaApiVersion}/me/accounts`);
    pagesUrl.searchParams.set('fields', fields);
    pagesUrl.searchParams.set('access_token', accessToken);
    const pagesResp = await fetch(pagesUrl);
    const pagesData = JSON.parse(await pagesResp.text());
    if (!pagesResp.ok || pagesData.error) throw new Error(pagesData.error?.message || 'Meta sayfaları alınamadı.');

    const pageList = Array.isArray(pagesData.data) ? pagesData.data : [];
    const page = pageList.find(x => String(x.id || '') === config.metaPageId)
      || pageList.find(x => String(x.instagram_business_account?.id || '') === config.metaInstagramUserId)
      || pageList.find(x => x.instagram_business_account?.id)
      || pageList[0] || null;
    let instagramUserId = page?.instagram_business_account?.id || config.metaInstagramUserId || '';
    let instagramUsername = '';
    let businessId = config.metaBusinessId || '';
    if (instagramUserId) {
      const igUrl = new URL(`https://graph.facebook.com/${config.metaApiVersion}/${instagramUserId}`);
      igUrl.searchParams.set('fields','id,username');
      igUrl.searchParams.set('access_token',accessToken);
      const igResp = await fetch(igUrl);
      const igData = JSON.parse(await igResp.text());
      if (igResp.ok && !igData.error) instagramUsername = igData.username || '';
    }
    const adUrl = new URL(`https://graph.facebook.com/${config.metaApiVersion}/me/adaccounts`);
    adUrl.searchParams.set('fields','id,name,account_id,account_status');
    adUrl.searchParams.set('limit','100');
    adUrl.searchParams.set('access_token',accessToken);
    const adResp = await fetch(adUrl);
    const adData = JSON.parse(await adResp.text());
    const adList = Array.isArray(adData.data) ? adData.data : [];
    const expectedAd = String(config.adAccountId || '').replace(/^act_/, '');
    const adAccount = adList.find(x => String(x.account_id || x.id || '').replace(/^act_/, '') === expectedAd) || adList[0] || null;

    const metaPatch = {
      connected:true,
      source:'OAUTH',
      accessToken,
      adAccountId: adAccount?.account_id || adAccount?.id?.replace(/^act_/, '') || '',
      pageId: page?.id || '',
      instagramUserId,
      instagramUsername,
      businessId,
      connectedAt:new Date().toISOString()
    };
    const tenant = await updateTenant(payload.tenantId, {meta:metaPatch});
    await addLog(payload.tenantId, {type:'META_CONNECTED', source:'OAUTH', adAccountId:metaPatch.adAccountId, instagramUserId});
    return html('Meta bağlantısı tamamlandı', `Bağlanan Instagram: <b>${instagramUsername || instagramUserId || 'bulunamadı'}</b><br>Reklam hesabı: <b>${metaPatch.adAccountId || 'bulunamadı'}</b>`);
  } catch (e) { return html('Meta bağlantısı başarısız', String(e.message || e)); }
});

app.post('/api/meta/disconnect', allowRoles('ADMIN','CUSTOMER_ADMIN'), async (req, res) => {
  try {
    const current = req.tenant?.meta || {};
    const meta = {connected:false, source:null, adAccountId:'', pageId:'', instagramUserId:'', instagramUsername:'', businessId:'', connectedAt:null, accessToken:'', metaAccessToken:'', instagramAccessToken:''};
    await updateTenant(req.user.tenantId, {meta});
    await addLog(req.user.tenantId, {type:'META_DISCONNECTED', previousAdAccountId:current.adAccountId || ''});
    res.json(meta);
  } catch(e) { res.status(400).json({error:e.message}); }
});

app.get('/api/analytics/summary', async (req, res) => { try { res.json(await analyticsSummary(req.user.tenantId)); } catch (e) { res.status(500).json({error:e.message}); } });
app.get('/api/ai/insights', async (req, res) => { try { res.json(await aiInsights(req.user.tenantId)); } catch (e) { res.status(500).json({error:e.message}); } });
app.get('/api/billing', async (req, res) => { try { res.json(await billingSummary(req.user.tenantId)); } catch (e) { res.status(500).json({error:e.message}); } });
app.get('/api/branding', async (req, res) => { try { res.json(await brandingSummary(req.user.tenantId)); } catch (e) { res.status(500).json({error:e.message}); } });
app.put('/api/branding', allowRoles('ADMIN', 'CUSTOMER_ADMIN'), async (req, res) => { try { res.json(await saveBranding(req.user.tenantId, req.body || {})); } catch (e) { res.status(400).json({error:e.message}); } });
app.get('/api/notifications', async (req, res) => { try { res.json(await notificationPrefs(req.user.tenantId)); } catch (e) { res.status(500).json({error:e.message}); } });
app.put('/api/notifications', async (req, res) => { try { res.json(await saveNotificationPrefs(req.user.tenantId, req.body || {})); } catch (e) { res.status(400).json({error:e.message}); } });
app.get('/api/security/overview', async (req, res) => { try { res.json(await securityOverview(req.user.tenantId)); } catch (e) { res.status(500).json({error:e.message}); } });
app.get('/api/ai/status', async (_req, res) => res.json(aiStatus()));
app.post('/api/ai/content-pack', async (req, res) => {
  try {
    const settings=await getSettings(req.user.tenantId);
    if(settings.aiEnabled===false) return res.json({source:'DISABLED',message:'AI modu kapalı.',recommendedFormat:String(req.body?.mediaType||'IMAGE').toUpperCase()==='VIDEO'?'REELS':'POST'});
    const history=await getLogs(req.user.tenantId, 20);
    const result=await generateContentPack({...req.body, tone:req.body?.tone||settings.aiTone, goal:req.body?.goal||settings.aiGoal, language:req.body?.language||settings.aiLanguage, timezone:config.timezone, history});
    await addLog(req.user.tenantId,{type:'AI_CONTENT_GENERATED',source:result.source,mediaType:req.body?.mediaType||'AUTO'});
    res.json(result);
  } catch(e) { res.status(400).json({error:e.message}); }
});
app.post('/api/ai/content-pack-from-file', upload.single('image'), async (req, res) => {
  let filePath = '';
  try {
    if (!req.file) return res.status(400).json({error: 'AI görsel analizi için bir görsel gerekli.'});
    filePath = req.file.path;

    if (!String(req.file.mimetype || '').startsWith('image/')) {
      return res.status(400).json({error: 'AI içerik stüdyosu için JPEG, PNG veya WebP görsel kullanmalısın.'});
    }

    const settings = await getSettings(req.user.tenantId);
    if (settings.aiEnabled === false) {
      return res.json({
        source: 'DISABLED',
        message: 'AI modu kapalı.',
        recommendedFormat: String(req.body?.mediaType || 'IMAGE').toUpperCase() === 'VIDEO' ? 'REELS' : 'POST'
      });
    }

    const kind = mediaKind(req.file);
    const ext = fileExtension(req.file.originalname);
    const visionMimeByExt = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.jfif': 'image/jpeg',
      '.png': 'image/png',
      '.webp': 'image/webp',
      '.gif': 'image/gif'
    };
    const visionMime = String(req.file.mimetype || '').startsWith('image/')
      ? String(req.file.mimetype).toLowerCase()
      : (visionMimeByExt[ext] || '');

    const publicUrl = publicBaseUrlForRequest(req) + '/uploads/' + encodeURIComponent(req.file.filename);
    const rawBuffer = kind === 'IMAGE' ? await fs.readFile(req.file.path) : null;
    const imageDataUrl = rawBuffer && visionMime
      ? `data:${visionMime};base64,${rawBuffer.toString('base64')}`
      : '';

    const history = await getLogs(req.user.tenantId, 20);
    const result = await generateContentPack({
      title: req.body?.title || req.file.originalname,
      context: req.body?.context || '',
      tone: req.body?.tone || settings.aiTone,
      goal: req.body?.goal || settings.aiGoal,
      language: req.body?.language || settings.aiLanguage,
      mediaType: req.body?.mediaType || (kind === 'VIDEO' ? 'REELS' : 'AUTO'),
      imageUrl: '',
      imageDataUrl,
      timezone: config.timezone,
      history,
      mediaNote: kind === 'VIDEO'
        ? 'Dosya bir video. Video yüklemesi kabul edildi; bu endpoint videoyu doğrudan kare kare analiz etmiyor. İçerik önerisi dosya adı, kullanıcı bilgisi ve seçilen Reels formatına göre hazırlanır.'
        : visionMime ? '' : 'Görsel dosyası kabul edildi ancak bu dosyanın türü doğrudan görsel analizine uygun olmadığı için metin ağırlıklı analiz yapılır.'
    });

    await addLog(req.user.tenantId, {
      type: 'AI_CONTENT_GENERATED',
      source: result.source,
      mediaType: req.body?.mediaType || 'AUTO',
      visualAnalysis: true
    });

    res.json({...result, visualAnalysis: true});
  } catch (e) {
    res.status(400).json({error: e.message});
  } finally {
    if (filePath) await fs.rm(filePath, {force:true}).catch(() => {});
  }
});

app.post('/api/ai/caption', async (req, res) => {
  try {
    const settings=await getSettings(req.user.tenantId);
    if(settings.aiEnabled===false) return res.status(403).json({error:'AI modu kapalı.'});
    const history=await getLogs(req.user.tenantId, 20);
    res.json(await generateCaption({...req.body,tone:req.body?.tone||settings.aiTone,goal:req.body?.goal||settings.aiGoal,language:req.body?.language||settings.aiLanguage,timezone:config.timezone,history}));
  } catch(e) { res.status(400).json({error:e.message}); }
});
app.post('/api/ai/caption-variants', async (req,res)=>{ try { res.json(await generateCaptionVariants(req.body||{})); } catch(e) { res.status(400).json({error:e.message}); } });
app.post('/api/ai/creative-score', async (req,res)=>{ try { res.json(await scoreCreative(req.body||{})); } catch(e) { res.status(400).json({error:e.message}); } });

app.get('/api/settings', async (req, res) => res.json(await getSettings(req.user.tenantId)));
app.put('/api/settings', allowRoles('ADMIN', 'CUSTOMER_ADMIN'), async (req, res) => {
  try { res.json(await saveSettings(req.user.tenantId, req.body || {})); }
  catch (e) { res.status(400).json({error: e.message}); }
});


app.get('/api/pro/ai', async (req,res)=>{ try{ res.json(await aiAdvisor(req.user.tenantId)); }catch(e){res.status(500).json({error:e.message});} });
app.get('/api/pro/performance', async (req,res)=>{ try{ res.json(await performanceSummary(req.user.tenantId)); }catch(e){res.status(500).json({error:e.message});} });
app.get('/api/pro/alerts', async (req,res)=>{ try{ res.json({data:await getAlerts(req.user.tenantId)}); }catch(e){res.status(500).json({error:e.message});} });
app.post('/api/pro/alerts', async (req,res)=>{ try{ res.status(201).json(await createAlert(req.user.tenantId,req.body||{})); }catch(e){res.status(400).json({error:e.message});} });
app.post('/api/pro/alerts/:id/read', async (req,res)=>{ try{res.json(await markAlert(req.user.tenantId,req.params.id,true));}catch(e){res.status(400).json({error:e.message});} });
app.get('/api/pro/leads', async (req,res)=>{ try{res.json({data:await getLeads(req.user.tenantId)});}catch(e){res.status(500).json({error:e.message});} });
app.post('/api/pro/leads', async (req,res)=>{ try{res.status(201).json(await createLead(req.user.tenantId,req.body||{}));}catch(e){res.status(400).json({error:e.message});} });
app.put('/api/pro/leads/:id', async (req,res)=>{ try{res.json(await updateLead(req.user.tenantId,req.params.id,req.body||{}));}catch(e){res.status(400).json({error:e.message});} });
app.delete('/api/pro/leads/:id', async (req,res)=>{ try{res.json(await deleteLead(req.user.tenantId,req.params.id));}catch(e){res.status(400).json({error:e.message});} });
app.post('/api/pro/creatives/analyze', async (req,res)=>{ try{res.status(201).json(await analyzeCreative(req.user.tenantId,req.body||{}));}catch(e){res.status(400).json({error:e.message});} });
app.get('/api/pro/creatives', async (req,res)=>{ try{res.json({data:await getCreatives(req.user.tenantId)});}catch(e){res.status(500).json({error:e.message});} });
app.post('/api/pro/budget/simulate', async (req,res)=>{ try{res.json(await simulateBudget(req.user.tenantId,req.body||{}));}catch(e){res.status(400).json({error:e.message});} });
app.get('/api/pro/experiments', async (req,res)=>{ try{res.json({data:await getExperiments(req.user.tenantId)});}catch(e){res.status(500).json({error:e.message});} });
app.post('/api/pro/experiments', async (req,res)=>{ try{res.status(201).json(await createExperiment(req.user.tenantId,req.body||{}));}catch(e){res.status(400).json({error:e.message});} });
app.post('/api/pro/experiments/:id/status', async (req,res)=>{ try{res.json(await updateExperiment(req.user.tenantId,req.params.id,req.body?.status));}catch(e){res.status(400).json({error:e.message});} });
app.post('/api/pro/utm', async (req,res)=>{ try{res.json(buildUtm(req.body||{}));}catch(e){res.status(400).json({error:e.message});} });
app.get('/api/pro/report', async (req,res)=>{ try{res.json(await reportPack(req.user.tenantId));}catch(e){res.status(500).json({error:e.message});} });
app.get('/api/pro/agency', async (_req,res)=>{ try{res.json(await agencyOverview());}catch(e){res.status(500).json({error:e.message});} });

app.post('/api/automation/run', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {} : (tenant?.meta || {});
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({
        enabled: true,
        actions: [{action: 'WAIT_META_CONNECTION'}],
        mode: 'PLANNING',
        message: 'Meta bağlantısı kurulmadan gerçek reklam verisi kontrol edilemez.'
      });
    }
    res.json(await optimizeAds(req.user.tenantId));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/logs', async (req, res) => res.json({data: await getLogs(req.user.tenantId, req.query.limit || 200)}));

app.get('/api/posts', async (req, res) => res.json({data: await getPosts(req.user.tenantId)}));
app.post('/api/posts', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({error: 'Görsel veya video gerekli.'});
    const tenantId=req.user.tenantId;
    const settings=await getSettings(tenantId);
    const posts=await getPosts(tenantId);
    const buffer=await fs.readFile(req.file.path);
    const fileHash=crypto.createHash('sha256').update(buffer).digest('hex');
    if(settings.preventDuplicateContent!==false && posts.some(x=>x.fileHash===fileHash)) {
      await fs.rm(req.file.path,{force:true});
      return res.status(409).json({error:'Bu içerik daha önce yüklenmiş. Aynı görsel/video tekrar kuyruğa alınmadı.'});
    }
    const requestedMediaType=String(req.body?.mediaType||'AUTO').toUpperCase();
    const mediaType=mediaKind(req.file)==='VIDEO'?'REELS':(requestedMediaType==='CAROUSEL'?'CAROUSEL':'POST');
    const requestedAuto=String(req.body?.autoPublish ?? 'true').toLowerCase()!=='false';
    const useAI=String(req.body?.useAI ?? 'true').toLowerCase()!=='false';
    const post={
      id:`post_${Date.now()}`,
      tenantId,
      title:String(req.body?.title||req.file.originalname).trim(),
      caption:String(req.body?.caption||'').trim(),
      linkUrl:String(req.body?.linkUrl||'').trim(),
      autoPublish:requestedAuto && settings.autoPublish !== false,
      filePath:req.file.path,
      publicUrl:`${publicBaseUrlForRequest(req)}/uploads/${encodeURIComponent(req.file.filename)}`,
      fileHash,
      mimeType:req.file.mimetype,
      mediaType,
      format:mediaType,
      aiGenerated:false,
      performanceScore:0,
      createdAt:new Date().toISOString()
    };
    if(useAI && settings.aiEnabled!==false && !post.caption) {
      const history=await getLogs(tenantId, 20);
      const pack=await generateContentPack({title:post.title,context:req.body?.aiContext||'',tone:settings.aiTone,goal:settings.aiGoal,language:settings.aiLanguage,mediaType,timezone:config.timezone,history,imageUrl:mediaType==='POST' && /^https:\/\//i.test(post.publicUrl)?post.publicUrl:''});
      post.aiGenerated=true;
      post.aiSource=pack.source;
      post.aiHook=String(pack.hook||'').trim();
      post.aiCta=String(pack.cta||'').trim();
      post.aiHashtags=Array.isArray(pack.hashtags)?pack.hashtags:[];
      post.aiRecommendedPostTime=pack.recommendedPostTime||'';
      post.aiRecommendedPostTimeReason=pack.recommendedPostTimeReason||'';
      post.aiCreativeScore=Number(pack.creativeScore||0);
      post.caption=[
        post.aiHook,
        String(pack.caption||'').trim(),
        post.aiCta,
        post.aiHashtags.join(' ')
      ].filter(Boolean).join('\\n\\n');
    }
    if(post.autoPublish) await scheduleUploadedPost(post,tenantId); else post.publishStatus='MANUAL';
    posts.unshift(post);
    await savePosts(tenantId,posts);
    await addLog(tenantId,{type:'POST_UPLOADED',postId:post.id,title:post.title,mediaType,aiGenerated:post.aiGenerated});
    res.status(201).json(post);
  } catch (e) { res.status(500).json({error:e.message}); }
});

app.post('/api/posts/bulk', upload.array('files', 20), async (req, res) => {
  try {
    const files = Array.isArray(req.files) ? req.files.slice(0, 20) : [];
    if (!files.length) return res.status(400).json({error:'En az bir fotoğraf veya video seçmelisin.'});

    const tenantId=req.user.tenantId;
    const settings=await getSettings(tenantId);
    const existing=await getPosts(tenantId);
    const accepted=[];
    const seenHashes=new Set(existing.map(x=>x.fileHash).filter(Boolean));
    const useAI=String(req.body?.useAI ?? 'true').toLowerCase()!=='false';
    const requestedAuto=String(req.body?.autoPublish ?? 'true').toLowerCase()!=='false';
    const aiContext=String(req.body?.aiContext || '').trim();
    const aiHistory=useAI && settings.aiEnabled!==false ? await getLogs(tenantId,20) : [];

    for(const file of files) {
      try {
        const buffer=await fs.readFile(file.path);
        const fileHash=crypto.createHash('sha256').update(buffer).digest('hex');
        if(settings.preventDuplicateContent!==false && seenHashes.has(fileHash)) {
          await fs.rm(file.path,{force:true});
          continue;
        }
        seenHashes.add(fileHash);

        const mediaType=mediaKind(file)==='VIDEO'?'REELS':'POST';
        const post={
          id:`post_${Date.now()}_${accepted.length}`,
          tenantId,
          title:String(file.originalname || 'Yeni içerik').replace(/\\.[^.]+$/,'').trim(),
          caption:'',
          linkUrl:'',
          autoPublish:requestedAuto && settings.autoPublish !== false,
          filePath:file.path,
          publicUrl:`${publicBaseUrlForRequest(req)}/uploads/${encodeURIComponent(file.filename)}`,
          fileHash,
          mimeType:file.mimetype,
          mediaType,
          format:mediaType,
          aiGenerated:false,
          performanceScore:0,
          createdAt:new Date().toISOString()
        };

        if(useAI && settings.aiEnabled!==false) {
          const pack=await generateContentPack({
            title:post.title,
            context:aiContext,
            tone:settings.aiTone,
            goal:settings.aiGoal,
            language:settings.aiLanguage,
            mediaType,
            timezone:config.timezone,
            history:aiHistory,
            imageUrl:mediaType==='POST' && /^https:\/\//i.test(post.publicUrl) ? post.publicUrl : ''
          });
          post.aiGenerated=true;
          post.aiSource=pack.source;
          post.aiHook=String(pack.hook||'').trim();
          post.aiCta=String(pack.cta||'').trim();
          post.aiHashtags=Array.isArray(pack.hashtags)?pack.hashtags:[];
          post.aiRecommendedPostTime=pack.recommendedPostTime||'';
          post.aiRecommendedPostTimeReason=pack.recommendedPostTimeReason||'';
          post.aiCreativeScore=Number(pack.creativeScore||0);
          post.caption=[
            post.aiHook,
            String(pack.caption||'').trim(),
            post.aiCta,
            post.aiHashtags.join(' ')
          ].filter(Boolean).join('\\n\\n');
        }

        accepted.push(post);
      } catch(fileError) {
        await fs.rm(file.path,{force:true}).catch(()=>{});
      }
    }

    if(!accepted.length) return res.status(409).json({error:'Yüklenecek yeni içerik bulunamadı. Tekrarlanan içerikler atlanmış olabilir.'});

    if(requestedAuto && settings.autoPublish !== false) {
      await scheduleUploadedPosts(accepted,tenantId);
    } else {
      for(const post of accepted) post.publishStatus='MANUAL';
    }

    const nextPosts=[...accepted,...existing];
    await savePosts(tenantId,nextPosts);

    for(const post of accepted) {
      await addLog(tenantId,{type:'POST_UPLOADED',postId:post.id,title:post.title,mediaType:post.mediaType,aiGenerated:post.aiGenerated,bulk:true});
    }

    res.status(201).json({
      count:accepted.length,
      skipped:files.length-accepted.length,
      order:accepted.map(x=>({id:x.id,title:x.title,mediaType:x.mediaType,nextPublishAt:x.nextPublishAt||null})),
      posts:accepted
    });
  } catch(e) {
    for(const file of (req.files||[])) await fs.rm(file.path,{force:true}).catch(()=>{});
    res.status(500).json({error:e.message});
  }
});

app.post('/api/posts/:id/publish', async (req, res) => {
  try {
    const tenantId=req.user.tenantId;
    const posts=await getPosts(tenantId);
    const post=posts.find(x=>x.id===req.params.id);
    if(!post) return res.status(404).json({error:'Post bulunamadı.'});
    if(!/^https:\/\//i.test(String(post.publicUrl||''))) return res.status(400).json({error:'Instagram paylaşımı için PUBLIC_BASE_URL HTTPS olmalı.'});
    const tenant=await getTenant(tenantId);
    const credentials=tenantId==='system'?{}:(tenant?.meta||{});
    const {instagramPublishMedia}=await import('./meta.js');
    const result=await instagramPublishMedia({mediaType:post.mediaType||'POST',imageUrl:post.publicUrl,videoUrl:post.publicUrl,caption:post.caption||'',coverUrl:post.coverPublicUrl||'',thumbOffset:post.coverThumbOffset,credentials});
    post.publishStatus='PUBLISHED'; post.publishedAt=new Date().toISOString(); post.instagramPublishResult=result; post.publishError='';
    await savePosts(tenantId,posts);
    await addLog(tenantId,{type:'INSTAGRAM_POST_PUBLISHED',postId:post.id,mediaType:post.mediaType||'POST',manual:true});
    res.json(post);
  } catch(e) { res.status(502).json({error:e.message}); }
});

app.post('/api/automation/publish-due', async (_req, res) => {
  try { res.json(await publishDuePosts()); } catch (e) { res.status(502).json({error: e.message}); }
});

app.post('/api/posts/:id/cover', upload.single('cover'), async (req,res) => {
  try {
    const postId=req.params.id;
    const tenantId=req.user.tenantId;
    const postList=await getPosts(tenantId);
    const post=postList.find(x=>x.id===postId);
    if(!post) return res.status(404).json({error:'İçerik bulunamadı.'});
    if(post.mediaType!=='REELS') return res.status(400).json({error:'Özel kapak yalnızca Reels için kullanılabilir.'});
    if(!req.file) return res.status(400).json({error:'Kapak görseli gerekli.'});
    if(!String(req.file.mimetype||'').startsWith('image/')) {
      await fs.rm(req.file.path,{force:true});
      return res.status(400).json({error:'Reels kapağı JPEG, PNG veya WebP olmalı.'});
    }

    if(post.coverPath && post.coverPath!==req.file.path) await fs.rm(post.coverPath,{force:true}).catch(()=>{});
    post.coverPath=req.file.path;
    post.coverPublicUrl=`${publicBaseUrlForRequest(req)}/uploads/${encodeURIComponent(req.file.filename)}`;
    post.coverUpdatedAt=new Date().toISOString();
    post.coverThumbOffset=null;
    await savePosts(tenantId,postList);
    res.json({post});
  } catch(e) {
    if(req.file?.path) await fs.rm(req.file.path,{force:true}).catch(()=>{});
    res.status(500).json({error:e.message});
  }
});

app.delete('/api/posts/:id', async (req, res) => {
  const tenantId = req.user.tenantId;
  const posts = await getPosts(tenantId);
  const post = posts.find(x => x.id === req.params.id);
  if (!post) return res.status(404).json({error: 'Post bulunamadı.'});
  await fs.rm(post.filePath, {force: true});
  if(post.coverPath) await fs.rm(post.coverPath, {force: true});
  await savePosts(tenantId, posts.filter(x => x.id !== req.params.id));
  await addLog(tenantId, {type: 'POST_DELETED', postId: post.id});
  res.json({ok: true});
});

// Super Admin / SaaS management
app.get('/api/admin/stats', allowRoles('ADMIN'), async (_req, res) => res.json(await adminStats()));
app.get('/api/admin/overview', allowRoles('ADMIN'), async (_req, res) => res.json(await adminOverview()));
app.get('/api/admin/plans', allowRoles('ADMIN'), async (_req, res) => res.json({data: planCatalog()}));
app.get('/api/admin/runtime', allowRoles('ADMIN'), async (_req, res) => { try { res.json({app:'AdVise AI', version:config.appVersion, environment:config.environment, port:config.port, database:await dbHealth()}); } catch(e) { res.status(503).json({error:e.message}); } });
app.get('/api/admin/customers', allowRoles('ADMIN'), async (_req, res) => res.json({data: await getCustomerSummaries()}));

app.post('/api/admin/customers', allowRoles('ADMIN'), async (req, res) => {
  try {
    const created = await createCustomerAccount({
      companyName: req.body?.companyName,
      username: req.body?.username,
      password: req.body?.password,
      plan: req.body?.plan || 'BASIC',
      days: req.body?.days || 30,
      fullName: req.body?.fullName || ''
    });
    await addLog('system', {type: 'CUSTOMER_CREATED', tenantId: created.tenant.id, username: created.user.username});
    res.status(201).json(created);
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.put('/api/admin/customers/:tenantId', allowRoles('ADMIN'), async (req, res) => {
  try {
    const patch = {};
    if (req.body?.companyName !== undefined) patch.companyName = String(req.body.companyName).trim();
    if (req.body?.active !== undefined) patch.active = Boolean(req.body.active);
    if (req.body?.plan !== undefined) patch.plan = req.body.plan;
    if (req.body?.subscriptionEnd !== undefined) patch.subscriptionEnd = req.body.subscriptionEnd;
    if (req.body?.meta !== undefined) patch.meta = req.body.meta;
    const tenant = await updateTenant(req.params.tenantId, patch);
    await addLog('system', {type: 'CUSTOMER_UPDATED', tenantId: tenant.id, active: tenant.active, plan: tenant.plan});
    res.json({tenant});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.post('/api/admin/customers/:tenantId/toggle', allowRoles('ADMIN'), async (req, res) => {
  try {
    const tenant = await getTenant(req.params.tenantId);
    if (!tenant) return res.status(404).json({error: 'Müşteri bulunamadı.'});
    const next = await updateTenant(tenant.id, {active: !tenant.active});
    await addLog('system', {type: 'CUSTOMER_TOGGLED', tenantId: next.id, active: next.active});
    res.json({tenant: next});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.post('/api/admin/customers/:tenantId/reset-password', allowRoles('ADMIN'), async (req, res) => {
  try {
    const tenant = await getTenant(req.params.tenantId);
    if (!tenant) return res.status(404).json({error: 'Müşteri bulunamadı.'});
    const {getUsers} = await import('./store.js');
    const users = await getUsers();
    const user = users.find(u => u.tenantId === tenant.id && u.role === 'CUSTOMER_ADMIN');
    if (!user) return res.status(404).json({error: 'Müşteri kullanıcı hesabı bulunamadı.'});
    const updated = await resetUserPassword(user.id, req.body?.password);
    await addLog('system', {type: 'PASSWORD_RESET', tenantId: tenant.id, userId: user.id});
    res.json({user: updated});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.post('/api/admin/customers/:tenantId/extend', allowRoles('ADMIN'), async (req, res) => {
  try {
    const tenant = await getTenant(req.params.tenantId);
    if (!tenant) return res.status(404).json({error: 'Müşteri bulunamadı.'});
    const days = Math.max(1, Number(req.body?.days || 30));
    const base = tenant.subscriptionEnd && new Date(tenant.subscriptionEnd).getTime() > Date.now() ? new Date(tenant.subscriptionEnd) : new Date();
    const end = new Date(base.getTime() + days * 86400000);
    const next = await updateTenant(tenant.id, {subscriptionEnd: end.toISOString(), active: true});
    await addLog('system', {type: 'SUBSCRIPTION_EXTENDED', tenantId: tenant.id, days, subscriptionEnd: end.toISOString()});
    res.json({tenant: next});
  } catch (e) { res.status(400).json({error: e.message}); }
});

app.delete('/api/admin/customers/:tenantId', allowRoles('ADMIN'), async (req, res) => {
  try {
    const result = await deleteTenantCascade(req.params.tenantId);
    for (const post of result.removedPosts || []) {
      if (post.filePath) await fs.rm(post.filePath, {force:true}).catch(()=>{});
    }
    await addLog('system', {type:'CUSTOMER_DELETED', tenantId:req.params.tenantId, companyName:result.tenant.companyName});
    res.json({ok:true, tenantId:req.params.tenantId});
  } catch (e) { res.status(400).json({error:e.message}); }
});

app.post('/api/admin/licenses', allowRoles('ADMIN'), async (req, res) => {
  try { res.status(201).json(await createLicense({plan: req.body?.plan || 'BASIC', days: req.body?.days || 30})); }
  catch (e) { res.status(400).json({error: e.message}); }
});
app.get('/api/admin/licenses', allowRoles('ADMIN'), async (_req, res) => res.json({data: await getLicenses()}));
app.post('/api/admin/licenses/:licenseId/assign', allowRoles('ADMIN'), async (req, res) => {
  try { res.json(await assignLicense(req.params.licenseId, req.body?.tenantId)); }
  catch (e) { res.status(400).json({error: e.message}); }
});

app.use((err, _req, res, _next) => {
  const message = err?.message || 'Request error';
  if (err instanceof multer.MulterError) {
    console.error('[UPLOAD] multer error:', err.code, message);
    return res.status(400).json({error: message, code: err.code});
  }
  console.error('[REQUEST] error:', message);
  res.status(400).json({error: message});
});

app.listen(config.port, '0.0.0.0', () => console.log(`AdVise AI backend: http://0.0.0.0:${config.port}`));
startScheduler();
