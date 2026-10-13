// Compatibility tombstones for older modules/clients. No SDK, credentials or provider requests.
function removed() {
  return Object.assign(new Error('AI kaldırıldı. İçeriği ve reklamı elle hazırlayın.'),{code:'AI_REMOVED',status:410});
}
export function aiStatus() {
  return {configured:false,enabled:false,model:null,provider:'NONE',mode:'MANUAL',code:'AI_REMOVED'};
}
export async function generateContentPack() { throw removed(); }
export async function generateCaption() { throw removed(); }
export async function generateCaptionVariants() { throw removed(); }
export async function scoreCreative() { throw removed(); }
export async function analyzeAdPerformance() { throw removed(); }
export async function generateCampaignStrategy() { throw removed(); }
export async function callGemini() { throw removed(); }
export async function fileToGeminiInputPart() { throw removed(); }
