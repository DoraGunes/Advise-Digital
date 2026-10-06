import {analyzeAdPerformance} from './ai.js';
import {getAdSets,insights,setStatus,updateAdSetBudget,updateAdSetTargeting,resolveAdGeoTargeting} from './meta.js';
import {getSettings,getTenant,getLogs,addLog} from './store.js';
import {config} from './config.js';
import {withTenantLock} from './persistence.js';
import {tenantCredentials,metaReady,budgetGuard,assertAutomaticReactivation,withAdAccountLock} from './automation-safety.js';

const num = value => Number.isFinite(Number(value)) ? Number(value) : 0;
const messageTypes = new Set(config.messageActionTypes.map(value => String(value).toLowerCase()));

function credentialsFor(tenantId, tenant) {
  return tenantCredentials(tenantId,tenant);
}

function hasMeta(credentials) {
  return metaReady(credentials);
}

function stable(value) {
  if (Array.isArray(value)) return `[${value.map(stable).sort().join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${key}:${stable(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function actionMetrics(row) {
  let messages = 0;
  for (const action of row?.actions || []) {
    if (messageTypes.has(String(action.action_type || '').toLowerCase())) messages = Math.max(messages,num(action.value));
  }
  const spend = num(row?.spend);
  const impressions = num(row?.impressions);
  return {
    spend7d: spend,
    impressions7d: impressions,
    clicks7d: num(row?.clicks),
    ctr7d: num(row?.ctr),
    messages7d: messages,
    messageCost7d: messages > 0 ? spend / messages : null
  };
}

async function reviewInputs(tenantId, {includeInsights=true}={}) {
  const tenant = await getTenant(tenantId);
  const credentials = credentialsFor(tenantId, tenant);
  if (!hasMeta(credentials)) {
    return {mode:'PLANNING', reason:'Önce bu hesaba Meta reklam hesabı bağlanmalı.', settings:await getSettings(tenantId)};
  }
  const settings = await getSettings(tenantId);
  const [response, preferred] = await Promise.all([
    getAdSets(credentials),
    resolveAdGeoTargeting(settings.adTargetingMode, settings.adTargetingLocations, credentials)
  ]);
  const rows = (Array.isArray(response?.data) ? response.data : []).slice(0, 50);
  const ads = [];
  for (let offset = 0; offset < rows.length; offset += 5) {
    const group = rows.slice(offset, offset + 5);
    const summaries = await Promise.all(group.map(async adset => {
      let metricsAvailable=false;
      let metrics = {spend7d:null, impressions7d:null, clicks7d:null, ctr7d:null, messages7d:null, messageCost7d:null};
      if (includeInsights) {
        try {
          const result = await insights(adset.id, 'adset', 7, credentials);
          const row = (result?.data || [])[0];
          metrics = actionMetrics(row||{});
          metricsAvailable=true;
        } catch {}
      }
      return {
        adSetId:String(adset.id || ''),
        name:String(adset.name || 'Adsız reklam grubu').slice(0,120),
        status:String(adset.effective_status || adset.status || 'UNKNOWN').toUpperCase(),
        dailyBudget:num(adset.daily_budget) / 100,
        ...metrics,
        metricsAvailable,
        audienceMode:String(settings.adTargetingMode || 'COUNTRY'),
        usesSavedAudience:stable(adset.targeting?.geo_locations || {}) === stable(preferred.geo_locations || {})
      };
    }));
    ads.push(...summaries);
  }
  return {mode:'CONNECTED', tenant, credentials, settings, adSets:rows, preferred, summaries:ads};
}

function savedAudienceLabel(settings) {
  const mode = String(settings.adTargetingMode || 'COUNTRY').toUpperCase();
  const locations = Array.isArray(settings.adTargetingLocations) ? settings.adTargetingLocations : [];
  if (mode === 'COUNTRY') return 'Türkiye geneli';
  return `${mode === 'REGION' ? 'Bölgeler' : 'İller'}: ${locations.join(', ')}`;
}

export function canAutomateAdDecision(item,settings={}) {
  return Number(item?.confidence)>=85 && item?.adSet?.metricsAvailable===true &&
    num(item.adSet.spend7d)>=num(settings.earlyMinSpendBeforeDecision);
}

async function runGeminiAdReviewLocked(tenantId='system', {force=false}={}) {
  const settings = await getSettings(tenantId);
  if (!force && !settings.geminiAdsAuto) return {enabled:false, mode:'DISABLED', decisions:[]};

  const logs = await getLogs(tenantId, 1000);
  if (!force) {
    const lastRun = logs.find(item => item.type === 'GEMINI_AD_AUTOMATION');
    if (lastRun && Date.now() - new Date(lastRun.at || lastRun.createdAt || 0).getTime() < 12 * 60 * 60 * 1000) {
      return {enabled:true, skipped:true, reason:'Son Gemini reklam kontrolü 12 saat içinde tamamlandı.', decisions:[]};
    }
  }

  try {
    const input = await reviewInputs(tenantId);
    if (input.mode !== 'CONNECTED') {
      const result = {enabled:!force, mode:input.mode, reason:input.reason, source:'NONE', decisions:[]};
      if (!force) await addLog(tenantId,{type:'GEMINI_AD_AUTOMATION',at:new Date().toISOString(),...result});
      return result;
    }
    const analysis = await analyzeAdPerformance({
      adSets:input.summaries,
      savedAudience:savedAudienceLabel(input.settings),
      minDailyBudget:input.settings.minDailyBudget,
      maxDailyBudget:input.settings.maxDailyBudget,
      dailyBudgetCap:input.settings.geminiAdsDailyCap
    });
    const byId = new Map(input.summaries.map(row => [row.adSetId,row]));
    const decisions = analysis.decisions
      .filter(item => byId.has(item.adSetId))
      .map(item => ({...item, adSet:byId.get(item.adSetId)}));
    const result = {
      enabled:!force,
      mode:'CONNECTED',
      source:analysis.source,
      model:analysis.model,
      summary:analysis.summary,
      error:analysis.error || '',
      ranAt:new Date().toISOString(),
      decisions,
      applied:[]
    };

    if (!force && analysis.source === 'GEMINI') {
      for (const item of decisions.slice(0,10)) {
        if (!canAutomateAdDecision(item,input.settings)) continue;
        if (item.action === 'ACTIVATE') {
          const lastAutoPause = logs.find(row => row.type === 'GEMINI_AD_ACTION' &&
            row.adSetId === item.adSetId && row.automatic === true && row.action === 'PAUSE');
          const lastManualStatus = logs.find(row => row.type === 'META_STATUS_CHANGED' && row.id === item.adSetId);
          if (item.adSet.status !== 'PAUSED' || !lastAutoPause ||
              (lastManualStatus && new Date(lastManualStatus.at).getTime() > new Date(lastAutoPause.at).getTime())) continue;
        } else if (item.adSet.status !== 'ACTIVE') continue;
        if (!['PAUSE','ACTIVATE','INCREASE_BUDGET','DECREASE_BUDGET','APPLY_SAVED_AUDIENCE'].includes(item.action)) continue;
        try {
          result.applied.push(await applyGeminiAdDecision(tenantId, {
            adSetId:item.adSetId,
            action:item.action,
            automatic:true
          }));
        } catch (error) {
          result.applied.push({adSetId:item.adSetId,action:item.action,applied:false,reason:error.message});
        }
      }
    }

    const logType = force ? 'GEMINI_AD_REVIEW' : 'GEMINI_AD_AUTOMATION';
    await addLog(tenantId,{type:logType,at:result.ranAt,source:result.source,model:result.model,summary:result.summary,applied:result.applied.length,mode:result.mode});
    return result;
  } catch (error) {
    const result = {enabled:!force,mode:'ERROR',source:'NONE',error:error.message,decisions:[],applied:[]};
    if (!force) await addLog(tenantId,{type:'GEMINI_AD_AUTOMATION',at:new Date().toISOString(),source:'ERROR',error:error.message});
    return result;
  }
}

async function applyGeminiAdDecisionLocked(tenantId='system', {adSetId,action,automatic=false}={}) {
  const allowed = new Set(['PAUSE','ACTIVATE','INCREASE_BUDGET','DECREASE_BUDGET','APPLY_SAVED_AUDIENCE']);
  const decision = String(action || '').toUpperCase();
  if (!allowed.has(decision)) throw new Error('Bu reklam kararı uygulanabilir değil.');

  const input = await reviewInputs(tenantId,{includeInsights:false});
  if (input.mode !== 'CONNECTED') throw new Error(input.reason);
  const adset = input.adSets.find(item => String(item.id) === String(adSetId));
  if (!adset) throw new Error('Reklam grubu artık bu Meta hesabında bulunmuyor.');
  const status = String(adset.effective_status || adset.status || '').toUpperCase();
  if (automatic && decision === 'ACTIVATE') {
    await assertAutomaticReactivation(tenantId,adset);
    const logs = await getLogs(tenantId, 1000);
    const lastAutoPause = logs.find(row => row.type === 'GEMINI_AD_ACTION' && row.adSetId === String(adSetId) && row.automatic === true && row.action === 'PAUSE');
    const lastManualStatus = logs.find(row => row.type === 'META_STATUS_CHANGED' && row.id === String(adSetId));
    if (status !== 'PAUSED' || !lastAutoPause ||
        (lastManualStatus && new Date(lastManualStatus.at).getTime() > new Date(lastAutoPause.at).getTime())) {
      throw new Error('Otomatik yönetim yalnızca kendi durdurduğu reklam grubunu yeniden açabilir.');
    }
  }
  let response = null;
  let appliedValue = '';

  if (decision === 'PAUSE') {
    if (status !== 'ACTIVE') throw new Error('Bu reklam grubu zaten aktif değil.');
    response = await setStatus(adset.id, 'PAUSED', input.credentials);
  } else if (decision === 'ACTIVATE') {
    if (status === 'ACTIVE') throw new Error('Bu reklam grubu zaten açık.');
    await budgetGuard(input.credentials,input.settings,{adSetId:adset.id,activate:true});
    response = await setStatus(adset.id, 'ACTIVE', input.credentials);
  } else if (decision === 'INCREASE_BUDGET' || decision === 'DECREASE_BUDGET') {
    const current = num(adset.daily_budget) / 100;
    const min = Math.max(1, num(input.settings.minDailyBudget));
    const max = Math.max(min, num(input.settings.maxDailyBudget));
    if (decision === 'DECREASE_BUDGET' && current <= min) throw new Error(`Ad set günlük minimum bütçesi ${min} TL.`);
    if (decision === 'INCREASE_BUDGET' && current >= max) throw new Error(`Ad set günlük üst bütçe sınırı ${max} TL.`);
    let next = decision === 'INCREASE_BUDGET'
      ? Math.min(max, current * 1.15)
      : Math.max(min, current * 0.85);
    if (decision === 'INCREASE_BUDGET') {
      const cap = num(input.settings.geminiAdsDailyCap);
      if (cap <= 0) throw new Error('Önce Reklam Karar Merkezi ayarlarından günlük AI bütçe sınırı belirlenmeli.');
      const activeTotal = input.adSets
        .filter(item => String(item.effective_status || item.status || '').toUpperCase() === 'ACTIVE')
        .reduce((sum,item) => sum + num(item.daily_budget) / 100, 0);
      const available = Math.max(0, cap - activeTotal);
      next = Math.min(next, current + available);
      if (next <= current) throw new Error(`Günlük toplam bütçe sınırı (${cap} TL) artışa izin vermiyor.`);
    }
    next = Math.round(next * 100) / 100;
    if (Math.abs(next-current) < 0.01) throw new Error('Günlük bütçe zaten belirlenen sınırda.');
    await budgetGuard(input.credentials,input.settings,{adSetId:adset.id,nextBudget:next});
    response = await updateAdSetBudget(adset.id, next, input.credentials);
    appliedValue = `${next} TL/gün`;
  } else if (decision === 'APPLY_SAVED_AUDIENCE') {
    const mode = String(input.settings.adTargetingMode || 'COUNTRY').toUpperCase();
    if (!['CITY','REGION'].includes(mode) || !input.settings.adTargetingLocations?.length) {
      throw new Error('Önce bu Instagram hesabı için şehir veya bölge hedef kitlesi seçilmeli.');
    }
    const desired = await resolveAdGeoTargeting(mode,input.settings.adTargetingLocations,input.credentials);
    if (stable(adset.targeting?.geo_locations || {}) === stable(desired.geo_locations || {})) {
      throw new Error('Bu reklam grubu zaten kaydedilmiş hedef kitleyi kullanıyor.');
    }
    const targeting = {...(adset.targeting || {}),geo_locations:desired.geo_locations};
    response = await updateAdSetTargeting(adset.id,targeting,input.credentials);
    appliedValue = `${mode}: ${input.settings.adTargetingLocations.join(', ')}`;
  }

  const record = {
    type:'GEMINI_AD_ACTION',
    adSetId:String(adset.id),
    action:decision,
    automatic:Boolean(automatic),
    appliedValue,
    status:String(response?.status || 'APPLIED')
  };
  await addLog(tenantId,record);
  return {...record,applied:true};
}

export async function runGeminiAdReview(tenantId='system',options={}) { return withTenantLock(tenantId,()=>runGeminiAdReviewLocked(tenantId,options)); }
export async function applyGeminiAdDecision(tenantId='system',options={}) { return withTenantLock(tenantId,()=>withAdAccountLock(tenantId,()=>applyGeminiAdDecisionLocked(tenantId,options))); }
