import sharp from 'sharp';
export const MAX_COVER_BYTES=10*1024*1024;
const fail=(code,message)=>Object.assign(new Error(message),{code});
export function coverMime(bytes) {
  if(bytes.length>=3&&bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff)return 'image/jpeg';
  if(bytes.length>=8&&bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))return 'image/png';
  if(bytes.length>=12&&bytes.toString('ascii',0,4)==='RIFF'&&bytes.toString('ascii',8,12)==='WEBP')return 'image/webp';
  return null;
}
export async function normalizeCover(bytes) {
  if(!bytes?.length)throw fail('COVER_EMPTY','Kapak dosyası okunamadı veya boş.');
  if(bytes.length>MAX_COVER_BYTES)throw fail('COVER_TOO_LARGE','Kapak görseli en fazla 10 MB olabilir.');
  const mime=coverMime(bytes);
  if(!mime)throw fail('COVER_UNSUPPORTED','Reels kapağı JPEG, PNG veya WebP olmalı.');
  try {
    const image=sharp(bytes,{failOn:'warning',limitInputPixels:40000000,animated:false});
    const metadata=await image.metadata();
    if(!metadata.width||!metadata.height||(metadata.pages||1)>1)throw new Error('Invalid image dimensions or animation');
    // toBuffer performs the real pixel decode; metadata alone accepts truncation.
    // Instagram cover URLs consistently serve JPEG, with orientation corrected,
    // alpha flattened and metadata stripped. Preserve aspect ratio.
    const jpeg=await image.rotate().resize({width:2160,height:2160,fit:'inside',withoutEnlargement:true}).flatten({background:'#ffffff'}).jpeg({quality:92}).toBuffer();
    return {bytes:jpeg,inputMime:mime,mime:'image/jpeg',extension:'.jpg'};
  } catch {throw fail('COVER_CORRUPT','Kapak görseli açılamadı veya bozuk. Başka bir görsel seçin.');}
}
