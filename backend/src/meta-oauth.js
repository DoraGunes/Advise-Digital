import jwt from 'jsonwebtoken';
import {randomUUID} from 'node:crypto';
import {config} from './config.js';
import {getTenant,updateTenant,getUserById,isTenantActive,addLog} from './store.js';
import {withDataLock} from './persistence.js';

const base=`https://graph.facebook.com/${config.metaApiVersion}`;
const escape=value=>String(value||'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const html=(res,title,body)=>res.type('html').send(`<!doctype html><html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${escape(title)}</title><style>body{font-family:system-ui;background:#f5f7fb;padding:36px}main{max-width:600px;margin:auto;background:white;padding:32px;border-radius:20px}h1{color:#17223e}p{line-height:1.6}</style><main><h1>${escape(title)}</h1><p>${escape(body)}</p><p>AdVise Digital uygulamasına dönüp bağlantı ekranını yenileyin.</p></main></html>`);

async function graph(path,token,query={}) {
  const url=new URL(`${base}/${path}`);
  for(const [key,value] of Object.entries(query))url.searchParams.set(key,String(value));
  if(token)url.searchParams.set('access_token',token);
  const response=await fetch(url,{signal:AbortSignal.timeout(30000)});
  const data=await response.json();
  if(!response.ok||data.error)throw new Error('Meta yetkilendirmesi tamamlanamadı. Bağlantıyı yeniden başlatın.');
  return data;
}

export async function startMetaOAuth(req,res) {
  if(!config.metaAppId||!config.metaAppSecret||!config.metaRedirectUri)return res.status(503).json({error:'Meta bağlantı kurulumu sunucuda henüz tamamlanmamış. Hesap yöneticisine başvurun.'});
  const nonce=randomUUID();
  await updateTenant(req.user.tenantId,{meta:{oauthNonce:nonce,oauthUserId:req.user.id,oauthStartedAt:new Date().toISOString()}});
  const state=jwt.sign({sub:req.user.id,tenantId:req.user.tenantId,purpose:'meta-oauth',nonce},config.jwtSecret,{expiresIn:'10m'});
  const url=new URL(`https://www.facebook.com/${config.metaApiVersion}/dialog/oauth`);
  url.searchParams.set('client_id',config.metaAppId);url.searchParams.set('redirect_uri',config.metaRedirectUri);url.searchParams.set('state',state);url.searchParams.set('response_type','code');
  if(config.metaLoginConfigId)url.searchParams.set('config_id',config.metaLoginConfigId);
  else url.searchParams.set('scope',config.metaOAuthScopes.join(','));
  return res.json({url:url.toString(),authUrl:url.toString(),source:'OAUTH',connected:false});
}

export async function metaOAuthCallback(req,res) {
  try {
    const payload=jwt.verify(String(req.query.state||''),config.jwtSecret);
    if(payload.purpose!=='meta-oauth'||!payload.nonce)throw new Error('Bağlantı isteği geçersiz veya süresi dolmuş.');
    await withDataLock(async()=>{
      const [user,tenant]=await Promise.all([getUserById(payload.sub),getTenant(payload.tenantId)]);
      if(!user||user.active===false||user.tenantId!==payload.tenantId||!['ADMIN','CUSTOMER_ADMIN'].includes(user.role)||!tenant||!isTenantActive(tenant)||tenant.meta.oauthNonce!==payload.nonce)throw new Error('Bağlantı isteği geçersiz veya kullanılmış.');
      // One-time state is consumed before exchange; a browser replay cannot reconnect another session.
      await updateTenant(tenant.id,{meta:{oauthNonce:'',oauthUserId:''}});
      if(req.query.error)throw new Error('Meta yetkilendirmesi iptal edildi.');
      const code=String(req.query.code||'');if(!code)throw new Error('Meta yetkilendirme kodu alınamadı.');
      const token=await graph('oauth/access_token','',{client_id:config.metaAppId,client_secret:config.metaAppSecret,redirect_uri:config.metaRedirectUri,code});
      let accessToken=token.access_token;if(!accessToken)throw new Error('Meta yetkilendirmesi tamamlanamadı.');
      try { const extended=await graph('oauth/access_token','',{grant_type:'fb_exchange_token',client_id:config.metaAppId,client_secret:config.metaAppSecret,fb_exchange_token:accessToken});if(extended.access_token)accessToken=extended.access_token; } catch {}
      const [pages,accounts]=await Promise.all([graph('me/accounts',accessToken,{fields:'id,name,instagram_business_account',limit:100}),graph('me/adaccounts',accessToken,{fields:'id,name,account_id,account_status',limit:100})]);
      await updateTenant(tenant.id,{meta:{oauthAssets:{accessToken,pages:pages.data||[],adAccounts:accounts.data||[],expiresAt:new Date(Date.now()+15*60000).toISOString()},source:'OAUTH_PENDING_SELECTION'}});
      await addLog(tenant.id,{type:'META_AUTHORIZED',source:'USER_ACTION',actorId:user.id});
    });
    return html(res,'Meta yetkilendirmesi tamamlandı','Uygulamadaki bağlantı ekranından Facebook sayfanızı, Instagram hesabınızı ve reklam hesabınızı seçin.');
  } catch { return html(res,'Meta bağlantısı tamamlanamadı','Bağlantı isteği geçersiz, iptal edilmiş veya süresi dolmuş olabilir. Uygulamadan yeniden başlatın.'); }
}

export async function metaAssets(req,res) {
  const tenant=await getTenant(req.user.tenantId),assets=tenant?.meta?.oauthAssets;
  if(!assets||Date.parse(assets.expiresAt)<Date.now())return res.json({available:false,pages:[],adAccounts:[],error:'Meta yetkilendirmesini başlatın veya yeniden deneyin.'});
  return res.json({available:true,pages:assets.pages.map(row=>({id:row.id,name:row.name,instagramUserId:row.instagram_business_account?.id||''})),adAccounts:assets.adAccounts.map(row=>({id:String(row.account_id||row.id||'').replace(/^act_/,''),name:row.name,status:row.account_status}))});
}

export async function selectMetaAssets(req,res) {
  const tenant=await getTenant(req.user.tenantId),assets=tenant?.meta?.oauthAssets;
  if(!assets||Date.parse(assets.expiresAt)<Date.now())throw new Error('Meta yetkilendirmesi süresi doldu. Yeniden bağlayın.');
  const account=assets.adAccounts.find(row=>String(row.account_id||row.id||'').replace(/^act_/,'')===String(req.body.adAccountId||'').replace(/^act_/,''));
  const page=assets.pages.find(row=>String(row.id)===String(req.body.pageId));
  if(!account||!page?.instagram_business_account?.id)throw new Error('Yetkilendirdiğiniz reklam hesabını ve Instagram bağlı Facebook sayfasını seçin.');
  const instagramUserId=String(page.instagram_business_account.id);
  const profile=await graph(instagramUserId,assets.accessToken,{fields:'id,username'});
  await updateTenant(tenant.id,{meta:{connected:true,source:'OAUTH',accessToken:assets.accessToken,metaAccessToken:assets.accessToken,instagramAccessToken:assets.accessToken,instagramApi:'FACEBOOK',adAccountId:String(account.account_id||account.id).replace(/^act_/,''),pageId:String(page.id),instagramUserId,instagramUsername:profile.username||'',oauthAssets:null,connectedAt:new Date().toISOString()}});
  await addLog(tenant.id,{type:'META_CONNECTED',source:'USER_ACTION',actorId:req.user.id});
  return res.json({connected:true,source:'OAUTH',instagramUsername:profile.username||'',adAccountId:String(account.account_id||account.id).replace(/^act_/,''),pageId:page.id,instagramUserId});
}
