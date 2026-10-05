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
import {getCampaigns, getAdSets, getAds, insights, setStatus, updateAdSetBudget, metaHealth, getInstagramMedia, createCampaign, createAdSet, createAdCreativeFromInstagramMedia, createAd, resolveAdGeoTargeting,resolveCredentials} from './meta.js';
import {AD_CITIES, AD_REGIONS, provinceNamesForTargeting} from './ad-targeting.js';
import {optimizeAds} from './optimizer.js';
import {startScheduler, scheduleUploadedPost, scheduleUploadedPosts, publishDuePosts,publishPost} from './scheduler.js';
import {analyticsSummary, aiInsights, billingSummary, brandingSummary, saveBranding, notificationPrefs, saveNotificationPrefs, securityOverview, planCatalog, adminOverview} from './v78.js';
import {dbHealth} from './db.js';
import {aiAdvisor, performanceSummary, getAlerts, createAlert, markAlert, getLeads, createLead, updateLead, deleteLead, analyzeCreative, getCreatives, simulateBudget, createExperiment, getExperiments, updateExperiment, buildUtm, reportPack, agencyOverview} from './pro.js';
import {generateContentPack, generateCaption, generateCaptionVariants, scoreCreative, aiStatus} from './ai.js';
import {learnFromGeneration, linkGenerationToPost, getMemorySummary} from './ai-memory.js';
import {runGeminiAdReview, applyGeminiAdDecision} from './gemini-ads.js';
import {withDataLock} from './persistence.js';
import {tenantCredentials,metaReady,budgetGuard,activationGuard} from './automation-safety.js';
import {metaOAuthCallback,startMetaOAuth,metaAssets,selectMetaAssets} from './meta-oauth.js';
import {productOverview,productReport,onboardingStatus,saveOnboarding} from './product.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadDir = path.resolve(process.env.ADVISE_UPLOAD_DIR || path.resolve(__dirname, '../uploads'));
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

function adTargetingPrompt(settings = {}) {
  const mode = String(settings.adTargetingMode || 'COUNTRY').toUpperCase();
  const locations = Array.isArray(settings.adTargetingLocations) ? settings.adTargetingLocations : [];
  if (mode === 'COUNTRY' || !locations.length) return 'Instagram reklam hedefi: Türkiye geneli.';
  const selected = locations.map(x => String(x || '').trim()).filter(Boolean);
  const detail = mode === 'REGION'
    ? selected.map(region => `${region} (${AD_REGIONS[region]?.join(', ') || ''})`).join('; ')
    : selected.join(', ');
  return `Instagram reklam hedefi: ${mode === 'REGION' ? 'seçilen bölgelerin illeri' : 'seçilen iller'}: ${detail}.`;
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
  return metaReady(credentials);
}

function hasInstagramCredentials(credentials = {}) {
  const c=resolveCredentials(credentials);
  return Boolean(c.instagramUserId&&c.instagramAccessToken);
}
await ensureAdmin();

export const app = express();
app.set('trust proxy', true);
app.use(cors());
app.use(express.json({limit: '2mb'}));
app.use('/uploads', express.static(uploadDir));

app.get('/health', (_req, res) => res.json({
  ok: true,
  app: 'AdVise AI',
  version: config.appVersion,
  apiVersion:16,
  minClientVersion:'14.0.0',
  capabilities:{productExperience:true,productOverview:true,productReporting:true,onboarding:true,scheduledPublishing:true,geminiAdReview:true,safeAutomationV16:true},
  buildMarker: 'ADVISE_PRODUCT_V16_2026_10_05',
  uploadMode: 'EXTENSION_AWARE',
  aiImageMode: 'GEMINI_INTERACTIONS_MULTIMODAL'
}));

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

// Diagnostic marker for the AI media upload route. Placed before auth so we can prove
// whether the request from the phone is actually reaching this backend.
app.use('/api/ai/content-pack-from-file', (req, res, next) => {
  console.log(
    '[AI MEDIA ROUTE HIT]',
    req.method,
    req.ip,
    req.get('content-type') || '-',
    req.get('user-agent') || '-'
  );
  res.set('X-AdVise-AI-Route', 'MEDIA_FIX_2026_10_03_V3');
  next();
});

app.get('/api/meta/oauth/callback',metaOAuthCallback);
app.use('/api', authMiddleware);
app.use('/api', (req,res,next)=>{
  const originalJson=res.json.bind(res);
  const safe=value=>{
    if(Array.isArray(value))return value.map(safe);
    if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).filter(([key])=>!['accessToken','access_token','metaAccessToken','instagramAccessToken','passwordHash','oauthAssets','oauthNonce','oauthUserId'].includes(key)).map(([key,item])=>[key,safe(item)]));
    if(typeof value==='string')return value.replace(/([?&](?:access_token|key|token)=)[^&\s]+/gi,'$1[hidden]').replace(/Bearer\s+[\w.-]+/gi,'Bearer [hidden]');
    return value;
  };
  res.json=body=>originalJson(safe(body));
  const feature=req.path.startsWith('/ai/')?'aiContent':req.path.startsWith('/automation/')||req.path.includes('/gemini-')?'automation':req.path.startsWith('/product/report')?'analytics':null;
  if(feature && req.user.role!=='ADMIN' && req.tenant.features?.[feature]!==true)return res.status(403).json({error:'Bu özellik mevcut paketinizde etkin değil.'});
  if(['GET','HEAD','OPTIONS'].includes(req.method))return next();
  const personal=req.path==='/profile/password'||/^\/pro\/alerts\/[^/]+\/read$/.test(req.path);
  if(!personal&&!['ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'].includes(req.user.role))return res.status(403).json({error:'Bu işlem için yetkiniz bulunmuyor.'});
  withDataLock(()=>new Promise(resolve=>{res.once('finish',resolve);res.once('close',resolve);next();})).catch(error=>{if(!res.headersSent)res.status(409).json({error:error.message});});
});

app.get('/api/system/health', async (_req, res) => {
  try { res.json({app:'AdVise AI', version:config.appVersion, environment:config.environment, database: await dbHealth()}); }
  catch (e) { res.status(503).json({error:e.message}); }
});

app.get('/api/me', async (req, res) => {
  res.json({user: req.user, tenant: req.tenant});
});

app.get('/api/product/overview',async(req,res)=>{try{res.json(await productOverview(req.user.tenantId,req.user));}catch{res.status(503).json({error:'Ana sayfa verileri alınamadı. Yeniden deneyin.'});}});
app.get('/api/product/report',async(req,res)=>{try{res.json(await productReport(req.user.tenantId,req.query));}catch(error){res.status(400).json({error:error.message});}});
app.get('/api/product/onboarding',async(req,res)=>{try{res.json(await onboardingStatus(req.user.tenantId));}catch(error){res.status(503).json({error:'Kurulum bilgileri alınamadı.'});}});
app.put('/api/product/onboarding',allowRoles('ADMIN','CUSTOMER_ADMIN'),async(req,res)=>{try{res.json(await saveOnboarding(req.user.tenantId,req.body));}catch(error){res.status(400).json({error:error.message});}});

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
    const credentials = tenantId === 'system' ? {systemAccount:true} : (tenantRaw?.meta?.connected ? tenantRaw.meta : null);

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
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : tenant?.meta;
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Meta bağlantısı kurulmadı.'});
    }
    res.json(await getCampaigns(credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/adsets', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : tenant?.meta;
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Meta bağlantısı kurulmadı.'});
    }
    res.json(await getAdSets(credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/ads', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : tenant?.meta;
    if (!hasMetaCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Meta bağlantısı kurulmadı.'});
    }
    res.json(await getAds(credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.get('/api/instagram/media', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : (tenant?.meta || {});
    const limit = Math.max(1, Math.min(100, Number(req.query.limit || 50)));
    if (!hasInstagramCredentials(credentials || {})) {
      return res.json({data: [], connected: false, mode: 'PLANNING', reason: 'Instagram bağlantısı kurulmadı.'});
    }
    res.json(await getInstagramMedia(credentials, limit));
  } catch (e) { res.status(502).json({error: e.message}); }
});

app.get('/api/ads/targeting-options', async (req, res) => {
  try {
    const settings = await getSettings(req.user.tenantId);
    res.json({cities:AD_CITIES, regions:Object.keys(AD_REGIONS), mode:settings.adTargetingMode, locations:settings.adTargetingLocations});
  } catch (e) { res.status(500).json({error:e.message}); }
});

app.put('/api/ads/targeting-preferences', allowRoles('ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'), async (req, res) => {
  try {
    const mode = String(req.body?.mode || 'COUNTRY').toUpperCase();
    const locations = Array.isArray(req.body?.locations) ? [...new Set(req.body.locations.map(x => String(x || '').trim()).filter(Boolean))] : [];
    if (mode !== 'COUNTRY') provinceNamesForTargeting(mode, locations);
    const settings = await saveSettings(req.user.tenantId, {adTargetingMode:mode, adTargetingLocations:mode === 'COUNTRY' ? [] : locations});
    res.json({mode:settings.adTargetingMode, locations:settings.adTargetingLocations});
  } catch (e) { res.status(400).json({error:e.message}); }
});

app.post('/api/ads/create', allowRoles('ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'), async (req, res) => {
  let stage = 'validation';
  let createdCampaignId = '';
  let createdAdSetId = '';
  let createdCreativeId = '';
  let createdAdId = '';
  try {
    const tenantId = req.user.tenantId;
    const tenant = await getTenant(tenantId);
    const credentials = tenantId === 'system' ? {systemAccount:true} : (tenant?.meta || {});
    const savedSettings = await getSettings(tenantId);
    const locationMode = String(req.body?.locationMode || savedSettings.adTargetingMode || 'COUNTRY').toUpperCase();
    const rawLocations = Array.isArray(req.body?.locations) ? req.body.locations : savedSettings.adTargetingLocations;
    const locations = [...new Set(rawLocations.map(x => String(x || '').trim()).filter(Boolean))];
    const mediaId = String(req.body?.instagramMediaId || '').trim();
    const dailyBudget = Number(req.body?.dailyBudget);
    if (!mediaId) return res.status(400).json({error: 'Instagram gönderisi seçmelisin.'});
    if (!Number.isFinite(dailyBudget) || dailyBudget < 1) return res.status(400).json({error: 'Günlük bütçe en az 1 TL olmalı.'});

    const campaignName = String(req.body?.campaignName || 'AdVise AI Kampanyası').trim().slice(0, 120);
    const adSetName = String(req.body?.adSetName || 'AdVise AI Ad Set').trim().slice(0, 120);
    const adName = String(req.body?.adName || 'AdVise AI Reklamı').trim().slice(0, 120);
    const activate = req.body?.activate !== false;
    await budgetGuard(credentials,savedSettings,{nextBudget:dailyBudget,creating:true});
    const media=await getInstagramMedia(credentials,100);
    if(!(media.data||[]).some(row=>String(row.id)===mediaId))throw new Error('Seçilen Instagram gönderisi bu hesaba ait değil.');
    const existingAds=await getAds(credentials);
    if((existingAds.data||[]).length>=Number(req.tenant.limits?.maxAds||0))throw new Error('Paketinizin reklam limitine ulaşıldı.');

    console.log(`[ADS CREATE] start media=${mediaId} budget=${dailyBudget} activate=${activate}`);

    stage = 'targeting';
    const audience = await resolveAdGeoTargeting(locationMode, locations, credentials);
    await saveSettings(tenantId, {
      adTargetingMode: locationMode,
      adTargetingLocations: locationMode === 'COUNTRY' ? [] : locations
    });

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
      destinationType: 'WHATSAPP',
      targeting: {geo_locations:audience.geo_locations},
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
      activated: activate,
      contactChannel: 'WHATSAPP',
      targeting: {mode: audience.locationMode, locations: audience.locations}
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
        if(kind!=='creative') await setStatus(id,'PAUSED',tenantCredentials(req.user.tenantId,await getTenant(req.user.tenantId)));
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
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : tenant?.meta;
    res.json(await insights(req.params.id, req.query.level || 'ad', days, credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});
app.post('/api/status/:id', allowRoles('ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'), async (req, res) => {
  try {
    const status = String(req.body?.status || '').toUpperCase();
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : tenant?.meta;
    if(status==='ACTIVE')await activationGuard(credentials||{},await getSettings(req.user.tenantId),req.params.id);
    const result=await setStatus(req.params.id, status, credentials || {});
    await addLog(req.user.tenantId,{type:'META_STATUS_CHANGED',id:String(req.params.id),status,source:'USER_ACTION',actorId:req.user.id});
    res.json(result);
  } catch (e) { res.status(502).json({error: e.message}); }
});

app.post('/api/budget/:id', allowRoles('ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'), async (req, res) => {
  try {
    const budget = Number(req.body?.dailyBudget);
    if (!Number.isFinite(budget) || budget <= 0) return res.status(400).json({error: 'Geçersiz günlük bütçe.'});
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : tenant?.meta;
    res.json(await updateAdSetBudget(req.params.id, budget, credentials || {}));
  } catch (e) { res.status(502).json({error: e.message}); }
});

app.post('/api/ads/gemini-review', allowRoles('ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'), async (req,res) => {
  try { res.json(await runGeminiAdReview(req.user.tenantId,{force:true})); }
  catch (e) { res.status(502).json({error:e.message}); }
});

app.post('/api/ads/gemini-apply', allowRoles('ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR'), async (req,res) => {
  try {
    const adSetId=String(req.body?.adSetId||'').trim();
    const action=String(req.body?.action||'').trim().toUpperCase();
    if (!adSetId) return res.status(400).json({error:'Reklam grubu seçilmedi.'});
    res.json(await applyGeminiAdDecision(req.user.tenantId,{adSetId,action}));
  } catch (e) { res.status(400).json({error:e.message}); }
});

function oauthStatePayload(req) {
  return jwt.sign({sub:req.user.id, tenantId:req.user.tenantId, purpose:'meta-oauth'}, config.jwtSecret, {expiresIn:'10m'});
}

app.get('/api/meta/health', async (req, res) => {
  try {
    const tenant=await getTenant(req.user.tenantId);
    const credentials=tenantCredentials(req.user.tenantId,tenant);
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
    metaTokenReady: Boolean(meta.metaAccessToken || meta.accessToken || (system&&config.metaAccessToken)),
    instagramTokenReady: Boolean(meta.instagramAccessToken || (system&&config.instagramAccessToken)),
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
app.get('/api/meta/assets',allowRoles('ADMIN','CUSTOMER_ADMIN'),metaAssets);
app.post('/api/meta/select',allowRoles('ADMIN','CUSTOMER_ADMIN'),async(req,res)=>{try {await selectMetaAssets(req,res);}catch(error){res.status(400).json({error:error.message});}});

app.post('/api/meta/disconnect', allowRoles('ADMIN','CUSTOMER_ADMIN'), async (req, res) => {
  try {
    const current = req.tenant?.meta || {};
    const meta = {oauthAssets:null,oauthNonce:'',oauthUserId:'',connected:false, source:null, adAccountId:'', pageId:'', instagramUserId:'', instagramUsername:'', businessId:'', connectedAt:null, accessToken:'', metaAccessToken:'', instagramAccessToken:''};
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
app.get('/api/ai/memory', async (req, res) => { try { res.json(await getMemorySummary(req.user.tenantId)); } catch(e) { res.status(500).json({error:e.message}); } });
app.post('/api/ai/content-pack', async (req, res) => {
  try {
    const settings=await getSettings(req.user.tenantId);
    if(settings.aiEnabled===false) return res.json({source:'DISABLED',message:'AI modu kapalı.',recommendedFormat:String(req.body?.mediaType||'IMAGE').toUpperCase()==='VIDEO'?'REELS':'POST'});
    const history=await getLogs(req.user.tenantId, 20);
    const result=await generateContentPack({...req.body, tone:req.body?.tone||settings.aiTone, goal:'WhatsApp mesajı', adTargeting:adTargetingPrompt(settings), language:req.body?.language||settings.aiLanguage, timezone:config.timezone, tenantId:req.user.tenantId, history});
    await addLog(req.user.tenantId,{type:'AI_CONTENT_GENERATED',source:result.source,mediaType:req.body?.mediaType||'AUTO'});
    const generation = result.source === 'GEMINI'
      ? await learnFromGeneration(req.user.tenantId, result, {postId: String(req.body?.postId || '').trim(), mediaType: req.body?.mediaType || 'AUTO'})
      : null;
    res.json(generation ? {...result, memoryGenerationId: generation.id} : result);
  } catch(e) { res.status(400).json({error:e.message}); }
});
app.post('/api/ai/content-pack-from-file', upload.single('image'), async (req, res) => {
  let filePath = '';
  try {
    if (!req.file) return res.status(400).json({error: 'AI görsel analizi için bir görsel gerekli.'});
    filePath = req.file.path;

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
    console.log('[AI MEDIA]', {
      originalName: req.file.originalname,
      mimetype: req.file.mimetype,
      kind,
      size: req.file.size || 0,
      visionMime: visionMime || '-',
      hasImageDataUrl: Boolean(imageDataUrl)
    });

    const result = await generateContentPack({
      title: req.body?.title || req.file.originalname,
      context: req.body?.context || '',
      tone: req.body?.tone || settings.aiTone,
      goal: 'WhatsApp mesajı',
      adTargeting: adTargetingPrompt(settings),
      language: req.body?.language || settings.aiLanguage,
      mediaType: req.body?.mediaType || (kind === 'VIDEO' ? 'REELS' : 'AUTO'),
      imageUrl: '',
      imageDataUrl: kind === 'IMAGE' ? imageDataUrl : '',
      tenantId: req.user.tenantId,
      filePath: req.file.path,
      mimeType: kind === 'IMAGE' ? (visionMime || req.file.mimetype) : (req.file.mimetype || 'video/mp4'),
      timezone: config.timezone,
      history,
      mediaNote: kind === 'VIDEO'
        ? 'Video Gemini tarafından içerik, sahne ve görünen bilgiler açısından analiz edilecek.'
        : visionMime ? '' : 'Görsel dosyası kabul edildi; Gemini uygun medya tipini mümkün olduğunca kendisi analiz eder.'
    });

    if (result.source !== 'GEMINI') {
      console.error('[AI MEDIA NOT GEMINI]', result.source, result.error || 'Gemini anahtarı/çağrısı kullanılamadı.');
      return res.status(502).json({
        error: result.error || 'Gemini görsel analizi çalışmadı.',
        source: result.source
      });
    }

    await addLog(req.user.tenantId, {
      type: 'AI_CONTENT_GENERATED',
      source: result.source,
      mediaType: req.body?.mediaType || 'AUTO',
      visualAnalysis: true
    });
    const generation = await learnFromGeneration(req.user.tenantId, result, {postId: String(req.body?.postId || '').trim(), mediaType: kind});

    res.json({...result, visualAnalysis: true, memoryGenerationId: generation.id});
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
    res.json(await generateCaption({...req.body,tone:req.body?.tone||settings.aiTone,goal:'WhatsApp mesajı',adTargeting:adTargetingPrompt(settings),language:req.body?.language||settings.aiLanguage,timezone:config.timezone,tenantId:req.user.tenantId,history}));
  } catch(e) { res.status(400).json({error:e.message}); }
});
app.post('/api/ai/caption-variants', async (req,res)=>{ try { res.json(await generateCaptionVariants(req.body||{})); } catch(e) { res.status(400).json({error:e.message}); } });
app.post('/api/ai/creative-score', async (req,res)=>{ try { res.json(await scoreCreative(req.body||{})); } catch(e) { res.status(400).json({error:e.message}); } });

app.get('/api/settings', async (req, res) => res.json(await getSettings(req.user.tenantId)));
app.put('/api/settings', allowRoles('ADMIN', 'CUSTOMER_ADMIN'), async (req, res) => {
  try {
    const current=await getSettings(req.user.tenantId);
    const nextAuto=Object.prototype.hasOwnProperty.call(req.body||{},'geminiAdsAuto') ? Boolean(req.body.geminiAdsAuto) : Boolean(current.geminiAdsAuto);
    const nextCap=Number(Object.prototype.hasOwnProperty.call(req.body||{},'geminiAdsDailyCap') ? req.body.geminiAdsDailyCap : current.geminiAdsDailyCap);
    const nextEnabled=Object.prototype.hasOwnProperty.call(req.body||{},'enabled')?req.body.enabled===true:current.enabled===true;
    if((nextAuto||nextEnabled) && (!Number.isFinite(nextCap)||nextCap<1)) return res.status(400).json({error:'Otomatik reklam yönetimi için hesap günlük bütçe sınırını belirleyin.'});
    res.json(await saveSettings(req.user.tenantId, req.body || {}));
  }
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
app.get('/api/pro/agency', allowRoles('ADMIN'), async (_req,res)=>{ try{res.json(await agencyOverview());}catch(e){res.status(500).json({error:e.message});} });

app.post('/api/automation/run', async (req, res) => {
  try {
    const tenant = await getTenant(req.user.tenantId);
    const credentials = req.user.tenantId === 'system' ? {systemAccount:true} : (tenant?.meta || {});
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
    const memoryGenerationId=String(req.body?.memoryGenerationId || '').trim();
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
      memoryGenerationId,
      aiGenerated:false,
      performanceScore:0,
      createdAt:new Date().toISOString()
    };
    if(useAI && settings.aiEnabled!==false && !post.caption) {
      const history=await getLogs(tenantId, 20);
      const pack=await generateContentPack({title:post.title,context:req.body?.aiContext||'',tone:settings.aiTone,goal:'WhatsApp mesajı',adTargeting:adTargetingPrompt(settings),language:settings.aiLanguage,mediaType,timezone:config.timezone,tenantId,history,imageUrl:mediaType==='POST' && /^https:\/\//i.test(post.publicUrl)?post.publicUrl:'',
        filePath:post.filePath,
        mimeType:post.mimeType});
      post.aiGenerated=true;
      post.aiMemoryPack=pack;
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
      ].filter(Boolean).join('\n\n');
    }
    if(post.autoPublish || req.body?.scheduleAt) {
      await scheduleUploadedPost(post,tenantId,req.body?.scheduleAt||'');
      if (!post.autoPublish) post.publishStatus='READY';
    } else post.publishStatus='MANUAL';
    const memoryPack = post.aiMemoryPack;
    delete post.aiMemoryPack;
    posts.unshift(post);
    await savePosts(tenantId,posts);
    await addLog(tenantId,{type:'POST_UPLOADED',postId:post.id,title:post.title,mediaType,aiGenerated:post.aiGenerated});
    if (post.aiGenerated && memoryPack && memoryPack.source === 'GEMINI') await learnFromGeneration(tenantId, memoryPack, {postId:post.id});
    else if (memoryGenerationId) await linkGenerationToPost(tenantId, memoryGenerationId, post.id, {caption:post.caption});
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
            goal:'WhatsApp mesajı',
            adTargeting:adTargetingPrompt(settings),
            language:settings.aiLanguage,
            mediaType,
            timezone:config.timezone,
            tenantId,
            history:aiHistory,
            imageUrl:mediaType==='POST' && /^https:\/\//i.test(post.publicUrl) ? post.publicUrl : '',
            filePath:post.filePath,
            mimeType:post.mimeType
          });
          post.aiGenerated=true;
          post.aiMemoryPack=pack;
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

    const memoryPacks = new Map();
    for (const post of accepted) {
      if (post.aiMemoryPack) memoryPacks.set(post.id, post.aiMemoryPack);
      delete post.aiMemoryPack;
    }
    const nextPosts=[...accepted,...existing];
    await savePosts(tenantId,nextPosts);

    for(const post of accepted) {
      const memoryPack = memoryPacks.get(post.id);
      await addLog(tenantId,{type:'POST_UPLOADED',postId:post.id,title:post.title,mediaType:post.mediaType,aiGenerated:post.aiGenerated,bulk:true});
      if (post.aiGenerated && memoryPack && memoryPack.source === 'GEMINI') await learnFromGeneration(tenantId, memoryPack, {postId:post.id});
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

app.patch('/api/posts/:id', async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const posts = await getPosts(tenantId);
    const post = posts.find(x => x.id === req.params.id);
    if (!post) return res.status(404).json({error:'İçerik bulunamadı.'});
    if (['PUBLISHED','PUBLISHING','RECONCILE'].includes(post.publishStatus)) return res.status(409).json({error:'Yayınlanmış içerik bu ekrandan düzenlenemez.'});
    if (Object.prototype.hasOwnProperty.call(req.body || {}, 'title')) post.title = String(req.body.title || '').trim().slice(0,180);
    if (Object.prototype.hasOwnProperty.call(req.body || {}, 'caption')) post.caption = String(req.body.caption || '').trim().slice(0,2200);
    if (Object.prototype.hasOwnProperty.call(req.body || {}, 'linkUrl')) post.linkUrl = String(req.body.linkUrl || '').trim().slice(0,1200);
    post.updatedAt = new Date().toISOString();
    await savePosts(tenantId, posts);
    if (post.memoryGenerationId) await linkGenerationToPost(tenantId, post.memoryGenerationId, post.id, {caption:post.caption});
    await addLog(tenantId, {type:'POST_EDITED',postId:post.id,title:post.title});
    res.json(post);
  } catch (e) { res.status(400).json({error:e.message}); }
});

app.post('/api/posts/:id/queue', async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const settings = await getSettings(tenantId);
    const posts = await getPosts(tenantId);
    const post = posts.find(x => x.id === req.params.id);
    if (!post) return res.status(404).json({error:'İçerik bulunamadı.'});
    if (post.publishStatus === 'PUBLISHED') return res.status(409).json({error:'Yayınlanmış içerik tekrar kuyruğa alınamaz.'});
    const requestedTime = String(req.body?.scheduleAt || '').trim();
    await scheduleUploadedPost(post, tenantId, requestedTime);
    post.autoPublish = settings.autoPublish !== false;
    if (!post.autoPublish) post.publishStatus = 'READY';
    if (requestedTime && post.autoPublish) {
      let cursor = new Date(post.nextPublishAt).getTime();
      const later = posts
        .filter(item => item.id !== post.id && ['QUEUED','RETRY'].includes(item.publishStatus))
        .map(item => ({item, time:new Date(item.nextPublishAt || '').getTime()}))
        .filter(entry => Number.isFinite(entry.time) && entry.time >= cursor)
        .sort((a,b) => a.time-b.time);
      for (const entry of later) {
        const nextTime = Math.max(entry.time, cursor + 86400000);
        entry.item.nextPublishAt = new Date(nextTime).toISOString();
        if (entry.item.selectedTime) entry.item.selectedTime = {...entry.item.selectedTime, scheduledAt:entry.item.nextPublishAt};
        cursor = nextTime;
      }
    }
    await savePosts(tenantId, posts);
    await addLog(tenantId, {type:'POST_QUEUED',postId:post.id,nextPublishAt:post.nextPublishAt});
    res.json(post);
  } catch (e) { res.status(400).json({error:e.message}); }
});

app.post('/api/posts/reorder', async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const posts = await getPosts(tenantId);
    const queued = posts.filter(x => ['QUEUED','RETRY'].includes(x.publishStatus));
    const ids = Array.isArray(req.body?.postIds) ? req.body.postIds.map(String) : [];
    if (ids.length !== queued.length || new Set(ids).size !== ids.length || ids.some(id => !queued.some(post => post.id === id))) {
      return res.status(400).json({error:'Sıralama, bekleyen kuyruk içeriklerinin tamamını içermeli.'});
    }
    const byId = new Map(queued.map(post => [post.id, post]));
    const slots = [...queued].sort((a,b) => new Date(a.nextPublishAt || 0) - new Date(b.nextPublishAt || 0));
    const reordered = ids.map((id, index) => {
      const post = byId.get(id);
      post.nextPublishAt = slots[index].nextPublishAt;
      if (post.selectedTime) post.selectedTime = {...post.selectedTime, scheduledAt:post.nextPublishAt};
      return post;
    });
    const pendingIds = new Set(ids);
    const next = [...reordered, ...posts.filter(post => !pendingIds.has(post.id))];
    await savePosts(tenantId, next);
    await addLog(tenantId, {type:'POST_QUEUE_REORDERED',postIds:ids});
    res.json({data:reordered});
  } catch (e) { res.status(400).json({error:e.message}); }
});

app.post('/api/posts/:id/publish', async (req,res)=>{
  try {res.json(await publishPost(req.user.tenantId,req.params.id,{manual:true}));}
  catch(error){res.status(409).json({error:error.message});}
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

if(process.env.ADVISE_NO_LISTEN!=='true')app.listen(config.port, '0.0.0.0', () => console.log(`AdVise AI backend: http://0.0.0.0:${config.port}`));
startScheduler();
