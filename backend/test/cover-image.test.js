import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {normalizeCover,coverMime,MAX_COVER_BYTES} from '../src/cover-image.js';

for(const format of ['jpeg','png','webp'])test(`real ${format} decode yields consistent JPEG cover bytes`,async()=>{
  const source=await sharp({create:{width:64,height:48,channels:4,background:{r:20,g:100,b:200,alpha:0.5}}}).toFormat(format).toBuffer();
  const result=await normalizeCover(source);assert.equal(result.inputMime,`image/${format}`);assert.equal(result.mime,'image/jpeg');assert.equal(coverMime(result.bytes),'image/jpeg');
  const decoded=await sharp(result.bytes).metadata();assert.equal(decoded.width,64);assert.equal(decoded.height,48);assert.equal(decoded.hasAlpha,false);assert.equal(decoded.orientation,undefined);
});
test('progressive JPEG is decoded and correctly normalized',async()=>{
  const source=await sharp({create:{width:32,height:40,channels:3,background:'#123456'}}).jpeg({progressive:true}).toBuffer();
  assert.equal((await sharp(source).metadata()).isProgressive,true);assert.equal(coverMime((await normalizeCover(source)).bytes),'image/jpeg');
});
test('corrupt, empty, unsupported and oversized covers have distinct safe failures',async()=>{
  await assert.rejects(normalizeCover(Buffer.alloc(0)),{code:'COVER_EMPTY'});
  await assert.rejects(normalizeCover(Buffer.from('%PDF-fixture')),{code:'COVER_UNSUPPORTED'});
  await assert.rejects(normalizeCover(Buffer.from([255,216,255,0,0])),{code:'COVER_CORRUPT'});
  await assert.rejects(normalizeCover(Buffer.alloc(MAX_COVER_BYTES+1)),{code:'COVER_TOO_LARGE'});
  const jpeg=await sharp({create:{width:32,height:32,channels:3,background:'#123456'}}).jpeg().toBuffer();
  await assert.rejects(normalizeCover(jpeg.subarray(0,jpeg.length-50)),{code:'COVER_CORRUPT'});
});
test('EXIF rotation is applied without stretching the cover',async()=>{
  const source=await sharp({create:{width:32,height:64,channels:3,background:'#123456'}}).jpeg().withMetadata({orientation:6}).toBuffer();
  const result=await normalizeCover(source),metadata=await sharp(result.bytes).metadata();
  assert.equal(metadata.width,64);assert.equal(metadata.height,32);assert.equal(metadata.orientation,undefined);
});
