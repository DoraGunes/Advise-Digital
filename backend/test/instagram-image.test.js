import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {normalizeInstagramImage} from '../src/instagram-image.js';

test('feed PNG is converted to JPEG without cropping tall content',async()=>{
  const source=await sharp({
    create:{width:400,height:900,channels:4,background:{r:14,g:54,b:90,alpha:1}}
  }).png().toBuffer();
  const result=await normalizeInstagramImage(source);
  const metadata=await sharp(result.bytes).metadata();
  assert.equal(result.mime,'image/jpeg');
  assert.equal(metadata.format,'jpeg');
  assert.ok(metadata.width>=320&&metadata.width<=1440);
  const ratio=metadata.width/metadata.height;
  assert.ok(ratio>=0.79&&ratio<=1.92,'Ratio should be within the Instagram feed range');
  assert.ok(result.bytes.length<8*1024*1024);
});

test('feed WEBP is converted to JPEG',async()=>{
  const source=await sharp({
    create:{width:1200,height:600,channels:3,background:{r:100,g:50,b:10}}
  }).webp().toBuffer();
  const result=await normalizeInstagramImage(source);
  assert.equal((await sharp(result.bytes).metadata()).format,'jpeg');
});
