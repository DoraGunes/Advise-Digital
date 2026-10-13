import {learnManualHistory} from './memory-learning.js';
import {researchMemory} from './memory-research.js';
// Provider-independent history. No inference, fabricated outcomes or remote writes.
export function buildManualMemory(posts=[],logs=[],performance={},timing={}) {
  const rows=Array.isArray(posts)?posts:[];
  return {
    source:'LOCAL_HISTORY',mode:'MANUAL',research:researchMemory(),learning:learnManualHistory(rows),
    postCount:rows.length,publishedCount:rows.filter(row=>row.publishStatus==='PUBLISHED').length,
    performance,timing,
    posts:[...rows].sort((a,b)=>String(b.createdAt||'').localeCompare(String(a.createdAt||''))).slice(0,50).map(row=>({
      id:row.id,title:String(row.title||''),caption:String(row.caption||''),mediaType:row.mediaType||row.format,
      status:row.publishStatus,createdAt:row.createdAt,publishedAt:row.publishedAt||null,
      selectedTime:row.selectedTime||null,
      instagramMediaId:row.instagramPublishResult?.id||row.instagramMediaId||null
    })),
    adHistory:(Array.isArray(logs)?logs:[]).filter(row=>row.type==='WEEKLY_LAUNCH'&&row.source==='APP_AD_CREATE').slice(0,30).map(row=>({
      at:row.at,adId:row.adId,adSetId:row.adSetId,instagramMediaId:row.instagramMediaId,
      dailyBudget:row.dailyBudget??null,destination:row.destination??null,
      locationMode:row.locationMode??null,locations:row.locations??[],
      status:row.adStatus??'UNKNOWN'
    }))
  };
}
export const MANUAL_DISABLED_ROUTES=Object.freeze([
  '/product/strategy','/ads/gemini-review','/ads/gemini-apply','/automation/run',
  '/ai/content-pack','/ai/content-pack-from-file','/ai/caption','/ai/caption-variants',
  '/ai/creative-score','/ai/style-recommendation','/ai/hashtags'
]);
