import sharp from 'sharp';

// Feed images must be publicly downloadable JPEGs. Keep the full image visible:
// add a neutral margin when its original proportions fall outside Instagram's range.
export async function normalizeInstagramImage(bytes) {
  if(!bytes?.length) throw new Error('Instagram görseli boş.');
  let metadata;
  try {
    metadata=await sharp(bytes,{animated:false,limitInputPixels:40000000,failOn:'warning'}).metadata();
  } catch {
    throw new Error('Görsel okunamadı. Geçerli bir fotoğraf yükleyin.');
  }
  if(!metadata.width||!metadata.height||(metadata.pages||1)>1)
    throw new Error('Instagram için tek karelik bir görsel yükleyin.');
  const swap=[5,6,7,8].includes(Number(metadata.orientation));
  const sourceWidth=swap?metadata.height:metadata.width;
  const sourceHeight=swap?metadata.width:metadata.height;
  // Instagram feed accepts ratios from 4:5 to 1.91:1.
  const aspect=sourceWidth/sourceHeight;
  let canvasWidth=sourceWidth,canvasHeight=sourceHeight;
  if(aspect<0.8) canvasWidth=Math.ceil(sourceHeight*0.8);
  if(aspect>1.91) canvasHeight=Math.ceil(sourceWidth/1.91);
  const width=Math.max(320,Math.min(1440,Math.round(canvasWidth)));
  const height=Math.max(1,Math.round(canvasHeight*width/canvasWidth));
  try {
    const image=sharp(bytes,{animated:false,limitInputPixels:40000000,failOn:'warning'})
      .rotate()
      .resize({width,height,fit:'contain',background:{r:255,g:255,b:255,alpha:1}})
      .flatten({background:'#ffffff'});
    let result=await image.clone().jpeg({quality:88,mozjpeg:true}).toBuffer();
    if(result.length>8*1024*1024) result=await image.clone().jpeg({quality:70,mozjpeg:true}).toBuffer();
    if(result.length>8*1024*1024) throw new Error('Görsel JPEG formatında 8 MB sınırına indirilemedi.');
    return {bytes:result,width,height,mime:'image/jpeg'};
  } catch(error) {
    if(String(error?.message||'').includes('8 MB')) throw error;
    throw new Error('Görsel Instagram için JPEG formatına dönüştürülemedi.');
  }
}
