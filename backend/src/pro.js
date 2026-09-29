import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {getTenant, getPosts, getLogs, addLog, getSettings, planDefinition} from './store.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data');
const file = path.join(root, 'pro.json');

const DEFAULT = {
  alerts: [],
  leads: [],
  creatives: [],
  experiments: [],
  utmTemplates: [],
  notificationCenter: [],
  agencyNotes: [],
};

const clone = v => JSON.parse(JSON.stringify(v));

async function read() {
  await fs.mkdir(root, {recursive: true});
  try { return JSON.parse(await fs.readFile(file, 'utf8')); }
  catch { await fs.writeFile(file, JSON.stringify(DEFAULT, null, 2)); return clone(DEFAULT); }
}
async function write(data) { await fs.mkdir(root, {recursive: true}); await fs.writeFile(file, JSON.stringify(data, null, 2)); }
function tenantRows(db, key, tenantId) { return (db[key] || []).filter(x => x.tenantId === tenantId); }
function id(prefix) { return `${prefix}_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`; }
function scoreFromSignals({cost=0, ctr=0, messages=0, spend=0}) {
  const costScore = cost > 0 ? Math.max(0, Math.min(100, 100 - cost * 8)) : 50;
  const ctrScore = Math.min(100, ctr * 20);
  const msgScore = Math.min(100, messages * 8);
  const spendPenalty = spend > 2000 ? 5 : 0;
  return Math.round((costScore * .55 + ctrScore * .2 + msgScore * .2 + 5) - spendPenalty);
}

export async function performanceSummary(tenantId) {
  const posts = await getPosts(tenantId);
  const logs = await getLogs(tenantId, 200);
  const metaActions = logs.filter(x => ['AD_PAUSED','AD_ACTIVATED','BUDGET_UPDATED','AUTOMATION_DECISION'].includes(x.type));
  const paused = metaActions.filter(x => x.type === 'AD_PAUSED').length;
  const budgetChanges = metaActions.filter(x => x.type === 'BUDGET_UPDATED').length;
  const automation = metaActions.filter(x => x.type === 'AUTOMATION_DECISION').length;
  return {posts: posts.length, logCount: logs.length, paused, budgetChanges, automation, activeSignals: Math.max(0, posts.length + automation - paused)};
}

export async function aiAdvisor(tenantId) {
  const settings = await getSettings(tenantId);
  const summary = await performanceSummary(tenantId);
  const lines = [];
  if (summary.paused > 0) lines.push(`${summary.paused} reklam için durdurma işlemi kaydı var; yeni kreatifleri küçük bütçeyle test etmek mantıklı olabilir.`);
  if (summary.budgetChanges === 0) lines.push('Son dönemde kayıtlı bütçe yönlendirmesi yok. Yeterli veri oluştuğunda serbest kapasiteyi iyi performanslı ad setlere kaydırabilirsin.');
  if (settings.earlyMessageCostLimit >= 8) lines.push(`Erken karar hedefi ${settings.earlyMessageCostLimit} TL. Yeterli harcama oluşmadan sert karar verme.`);
  if (summary.posts === 0) lines.push('İlk kreatifini yükle; saat modeli ve kreatif karşılaştırması için geçmiş veri oluşmaya başlayacak.');
  if (!summary.posts && !summary.paused) lines.push('Planlama modunda başlayabilirsin; Meta bağlantısı sonrası gerçek veriler karar motoruna eklenecek.');
  return {title:'Advise AI', mode:'RULE_BASED', generatedAt:new Date().toISOString(), score: Math.max(35, Math.min(98, 60 + summary.posts * 4 - summary.paused * 2)), summary: lines.slice(0,5), metrics: summary};
}

export async function getAlerts(tenantId) { const db = await read(); return tenantRows(db,'alerts',tenantId).slice(0,100); }
export async function createAlert(tenantId, input) {
  const db = await read(); const alert = {id:id('alert'), tenantId, title:String(input.title||'Uyarı'), body:String(input.body||''), severity:String(input.severity||'INFO').toUpperCase(), read:false, createdAt:new Date().toISOString()};
  db.alerts = [alert, ...(db.alerts||[])].slice(0,2000); await write(db); return alert;
}
export async function markAlert(tenantId, alertId, read=true) { const db=await read(); const a=(db.alerts||[]).find(x=>x.tenantId===tenantId&&x.id===alertId); if(!a) throw new Error('Uyarı bulunamadı.'); a.read=Boolean(read); await write(db); return a; }

export async function getLeads(tenantId) { const db=await read(); return tenantRows(db,'leads',tenantId).slice(0,500); }
export async function createLead(tenantId,input) {
  const db=await read(); const lead={id:id('lead'),tenantId,name:String(input.name||''),phone:String(input.phone||''),email:String(input.email||''),source:String(input.source||'META'),status:String(input.status||'NEW').toUpperCase(),notes:String(input.notes||''),value:Number(input.value||0),createdAt:new Date().toISOString(),updatedAt:new Date().toISOString()};
  if(!lead.name) throw new Error('Lead adı gerekli.'); db.leads=[lead,...(db.leads||[])]; await write(db); await addLog(tenantId,{type:'LEAD_CREATED',leadId:lead.id}); return lead;
}
export async function updateLead(tenantId,leadId,input){ const db=await read(); const l=(db.leads||[]).find(x=>x.tenantId===tenantId&&x.id===leadId); if(!l) throw new Error('Lead bulunamadı.'); Object.assign(l,{...input,status: input.status ? String(input.status).toUpperCase() : l.status,value: input.value == null ? l.value : Number(input.value),updatedAt:new Date().toISOString()}); await write(db); return l; }
export async function deleteLead(tenantId,leadId){ const db=await read(); const before=db.leads?.length||0; db.leads=(db.leads||[]).filter(x=>!(x.tenantId===tenantId&&x.id===leadId)); if(db.leads.length===before) throw new Error('Lead bulunamadı.'); await write(db); return {deleted:true}; }

export async function analyzeCreative(tenantId,input){
  const title=String(input.title||'Kreatif'); const type=String(input.type||'IMAGE').toUpperCase(); const copy=String(input.copy||'');
  const db=await read(); const prior=tenantRows(db,'creatives',tenantId); const flags=[];
  if(copy.length>180) flags.push('Metin uzun; daha kısa CTA denenebilir.');
  if(copy.length<25) flags.push('Metin kısa; fayda ve CTA eklemek test edilebilir.');
  if(type==='VIDEO') flags.push('Video için ilk 2-3 saniyede ürün/faydayı görünür kıl.');
  else flags.push('Statik görsel için ürünün kadrajda erken görünmesini test et.');
  const baseScore=Math.max(50,Math.min(94,70 + (type==='VIDEO'?6:0) - (copy.length>180?8:0)));
  const item={id:id('creative'),tenantId,title,type,copy,score:baseScore,flags,createdAt:new Date().toISOString()};
  db.creatives=[item,...(db.creatives||[])].slice(0,1000); await write(db); return {...item,previousCount:prior.length};
}
export async function getCreatives(tenantId){const db=await read();return tenantRows(db,'creatives',tenantId).slice(0,200);}

export async function simulateBudget(tenantId,input){
  const total=Math.max(0,Number(input.totalBudget||0));
  const items=Array.isArray(input.items)?input.items:[];
  const reservePct=Math.max(0,Math.min(50,Number(input.reservePercent??10)));
  const pool=total*(1-reservePct/100);
  const scored=items.map((x,i)=>{const cost=Number(x.messageCost||0); const ctr=Number(x.ctr||0); const messages=Number(x.messages||0); const spend=Number(x.spend||0); return {...x,_score:scoreFromSignals({cost,ctr,messages,spend}),_index:i};}).sort((a,b)=>b._score-a._score);
  const denom=scored.reduce((s,x)=>s+Math.max(1,x._score),0)||1;
  const rows=scored.map(x=>({...x,allocation:Math.round(pool*Math.max(1,x._score)/denom)}));
  return {totalBudget:total,reservePercent:reservePct,reserve:Math.round(total*reservePct/100),allocations:rows.map(x=>({name:x.name||`Reklam ${x._index+1}`,score:x._score,allocation:x.allocation,messageCost:Number(x.messageCost||0)}))};
}

export async function createExperiment(tenantId,input){
  const db=await read(); const e={id:id('exp'),tenantId,name:String(input.name||'A/B Test'),status:'DRAFT',budget:Number(input.budget||0),variants:Array.isArray(input.variants)?input.variants.map((v,i)=>({id:`v${i+1}`,name:String(v.name||`Varyant ${i+1}`),goal:String(v.goal||'MESSAGE_COST'),target:Number(v.target||0)})):[],createdAt:new Date().toISOString()};
  if(e.variants.length<2) throw new Error('En az 2 varyant gerekli.'); db.experiments=[e,...(db.experiments||[])]; await write(db); return e;
}
export async function getExperiments(tenantId){const db=await read();return tenantRows(db,'experiments',tenantId).slice(0,100);}
export async function updateExperiment(tenantId,idValue,status){const db=await read(); const e=(db.experiments||[]).find(x=>x.tenantId===tenantId&&x.id===idValue); if(!e) throw new Error('A/B test bulunamadı.'); e.status=String(status||'DRAFT').toUpperCase(); e.updatedAt=new Date().toISOString(); await write(db); return e;}

export function buildUtm(input){
  const clean=s=>String(s||'').trim().toLowerCase().replace(/[^a-z0-9_-]+/g,'-').replace(/-+/g,'-').replace(/^-|-$/g,'');
  const source=clean(input.source||'meta'), medium=clean(input.medium||'paid-social'), campaign=clean(input.campaign||'campaign'), content=clean(input.content||'creative'), term=clean(input.term||'');
  const params={utm_source:source,utm_medium:medium,utm_campaign:campaign,utm_content:content}; if(term) params.utm_term=term;
  return {params,query:Object.entries(params).map(([k,v])=>`${k}=${encodeURIComponent(v)}`).join('&')};
}

export async function reportPack(tenantId){
  const [tenant,summary,ai,logs,posts]=await Promise.all([getTenant(tenantId),performanceSummary(tenantId),aiAdvisor(tenantId),getLogs(tenantId,100),getPosts(tenantId)]);
  const date=new Date();
  const rows=[
    ['ADVISE DIGITAL RAPORU'],['Firma',tenant?.companyName||tenantId],['Paket',tenant?.plan||'-'],['Tarih',date.toLocaleString('tr-TR')],[],
    ['KPI','Değer'],['İçerik',summary.posts],['İşlem kaydı',summary.logCount],['Durdurulan reklam',summary.paused],['Bütçe değişimi',summary.budgetChanges],['Otomasyon kararı',summary.automation],[],
    ['ADVISE AI ÖZETİ'],...ai.summary.map(x=>['•',x]),[],['SON LOG KAYITLARI'],...logs.slice(0,20).map(x=>[x.type,x.at])
  ];
  const csv=rows.map(r=>r.map(v=>`"${String(v??'').replaceAll('"','""')}"`).join(';')).join('\r\n');
  return {tenant,summary,ai,generatedAt:date.toISOString(),csv,postCount:posts.length};
}

export async function agencyOverview(){
  const db=await read();
  const tenants=[...new Set((db.leads||[]).map(x=>x.tenantId)),...(db.alerts||[]).map(x=>x.tenantId)];
  return {managedTenantHints:[...new Set(tenants)].slice(0,100),features:['multi_tenant','role_based_access','crm','reports','alerts','white_label','ab_testing','utm','ai_advisor']};
}

export async function addSystemNotification(tenantId,title,body,severity='INFO'){return createAlert(tenantId,{title,body,severity});}
