import {getAdSets,getCampaigns,getAds,getMetaAccount,resolveCredentials} from './meta.js';
import {getLogs,getTenant} from './store.js';
import {withTenantLock} from './persistence.js';

export const minorToMoney=value=>Math.round((Number(value)||0))/100;
export const money=value=>Math.round(Number(value)*100)/100;
export function tenantCredentials(tenantId,tenant) {
  return tenantId==='system' ? {systemAccount:true} : {...(tenant?.meta||{}),systemAccount:false};
}
export function metaReady(credentials) {
  const c=resolveCredentials(credentials);
  return Boolean(c.accessToken&&c.adAccountId);
}

// Separate tenants may legitimately authorize the same external ad account.
// Their local writes stay independent, while financial mutations share one account gate.
export async function withAdAccountLock(tenantId,task,options={}) {
  const tenant=await getTenant(tenantId);
  const credentials=resolveCredentials(tenantCredentials(tenantId,tenant));
  if(!credentials.adAccountId)return task();
  return withTenantLock(`meta-account:${credentials.adAccountId}`,task,options);
}
export async function budgetGuard(credentials,settings,{adSetId='',nextBudget=0,activate=false,creating=false}={}) {
  const [sets,campaigns,account]=await Promise.all([getAdSets(credentials),getCampaigns(credentials),getMetaAccount(credentials)]);
  if (String(account.currency||'').toUpperCase()!=='TRY') throw new Error('Bütçe otomasyonu yalnızca TRY para birimindeki hesaplarda kullanılabilir.');
  if ((campaigns.data||[]).some(row=>Number(row.daily_budget)>0||Number(row.lifetime_budget)>0)) {
    throw new Error('Kampanya bütçesi kullanılan hesapta otomatik bütçe değişimi desteklenmiyor. Önce Meta bütçe yapısını kontrol edin.');
  }
  const rows=sets.data||[];
  const current=adSetId ? rows.find(row=>String(row.id)===String(adSetId)) : null;
  if (adSetId&&!current) throw new Error('Reklam grubu seçili hesaba ait değil.');
  const currentBudget=minorToMoney(current?.daily_budget);
  const next=money(nextBudget||currentBudget);
  if (!Number.isFinite(next)||next<=0) throw new Error('Geçersiz günlük bütçe.');
  if (next>Number(settings.maxDailyBudget)) throw new Error(`Reklam grubu günlük sınırı ${settings.maxDailyBudget} TL.`);
  if (creating || next>currentBudget || activate) {
    const cap=Number(settings.geminiAdsDailyCap||0);
    if (!(cap>0)) throw new Error('Önce hesap günlük bütçe sınırını belirleyin.');
    const total=rows.filter(row=>String(row.status).toUpperCase()==='ACTIVE').reduce((sum,row)=>sum+minorToMoney(row.daily_budget),0);
    const counted=current&&String(current.status).toUpperCase()==='ACTIVE' ? currentBudget : 0;
    const projected=total-counted+((activate||creating||counted>0)?next:0);
    if (projected>cap+0.001) throw new Error(`Hesap günlük bütçe sınırı (${cap} TL) aşılacağı için işlem uygulanmadı.`);
  }
  return {current,rows,next};
}
export async function assertAutomaticReactivation(tenantId,adset) {
  const logs=await getLogs(tenantId,1000);
  const pause=logs.find(row=>row.type==='GEMINI_AD_ACTION'&&row.adSetId===String(adset.id)&&row.automatic===true&&row.action==='PAUSE');
  const manual=logs.find(row=>row.type==='META_STATUS_CHANGED'&&[String(adset.id),String(adset.campaign_id)].includes(String(row.id)));
  if (!pause || (manual&&Date.parse(manual.at)>=Date.parse(pause.at))) throw new Error('Elle durdurulmuş reklam otomatik açılamaz.');
}

export async function activationGuard(credentials,settings,id) {
  const [sets,campaigns,ads]=await Promise.all([getAdSets(credentials),getCampaigns(credentials),getAds(credentials)]);
  const set=(sets.data||[]).find(row=>String(row.id)===String(id));
  if(set)return budgetGuard(credentials,settings,{adSetId:id,activate:true});
  const ad=(ads.data||[]).find(row=>String(row.id)===String(id));
  if(ad)return budgetGuard(credentials,settings,{adSetId:ad.adset_id,activate:true});
  const campaign=(campaigns.data||[]).find(row=>String(row.id)===String(id));
  if(!campaign)throw new Error('Bu reklam seçili hesaba ait değil.');
  const cap=Number(settings.geminiAdsDailyCap||0);
  if(!(cap>0))throw new Error('Önce hesap günlük bütçe sınırını belirleyin.');
  if(Number(campaign.daily_budget)>0||Number(campaign.lifetime_budget)>0)throw new Error('Kampanya bütçesi kullanılan reklamı Meta hesabınızdan kontrol edin.');
  const total=(sets.data||[]).filter(row=>String(row.status)==='ACTIVE').reduce((sum,row)=>sum+minorToMoney(row.daily_budget),0);
  if(total>cap)throw new Error('Hesap günlük bütçe sınırı bu reklamı açmaya izin vermiyor.');
}
