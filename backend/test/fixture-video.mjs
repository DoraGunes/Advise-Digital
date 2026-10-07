// Dependency-free, deterministic media fixture. Never used by the application.
// AVI RIFF headers follow https://learn.microsoft.com/en-us/windows/win32/directshow/avi-riff-file-reference
import {Buffer} from 'node:buffer';

function jpegDimensions(jpeg) {
  if(jpeg.readUInt16BE(0)!==0xffd8)throw new Error('Fixture requires JPEG');
  for(let at=2;at+4<=jpeg.length;) {
    if(jpeg[at]!==0xff)throw new Error('Invalid JPEG marker');
    while(jpeg[at]===0xff)at++;
    const marker=jpeg[at++];
    if(marker===0xd9||marker===0xda)break;
    if(marker===0x01||(marker>=0xd0&&marker<=0xd7))continue;
    const size=jpeg.readUInt16BE(at);
    if(size<2||at+size>jpeg.length)throw new Error('Invalid JPEG length');
    if([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker)) {
      const height=jpeg.readUInt16BE(at+3),width=jpeg.readUInt16BE(at+5);
      if(!width||!height||width>32767||height>32767)throw new Error('Unsupported fixture dimensions');
      return {width,height};
    }
    at+=size;
  }
  throw new Error('JPEG frame dimensions missing');
}

function chunk(id,data) {
  const header=Buffer.alloc(8);header.write(id,0,4,'ascii');header.writeUInt32LE(data.length,4);
  return Buffer.concat([header,data,...(data.length%2?[Buffer.alloc(1)]:[])]);
}
const list=(type,parts)=>chunk('LIST',Buffer.concat([Buffer.from(type,'ascii'),...parts]));

export function fixtureVideoFromJpeg(jpeg) {
  const {width,height}=jpegDimensions(jpeg),fps=10,frameCount=20;
  const avih=Buffer.alloc(56);
  [100000,jpeg.length*fps,0,0x10,frameCount,0,1,jpeg.length,width,height].forEach((value,i)=>avih.writeUInt32LE(value,i*4));
  const strh=Buffer.alloc(56);strh.write('vids',0,4,'ascii');strh.write('MJPG',4,4,'ascii');
  strh.writeUInt32LE(1,20);strh.writeUInt32LE(fps,24);strh.writeUInt32LE(frameCount,32);strh.writeUInt32LE(jpeg.length,36);strh.writeUInt32LE(0xffffffff,40);
  strh.writeInt16LE(width,52);strh.writeInt16LE(height,54);
  const strf=Buffer.alloc(40);strf.writeUInt32LE(40,0);strf.writeInt32LE(width,4);strf.writeInt32LE(height,8);strf.writeUInt16LE(1,12);strf.writeUInt16LE(24,14);strf.write('MJPG',16,4,'ascii');strf.writeUInt32LE(jpeg.length,20);
  const header=list('hdrl',[chunk('avih',avih),list('strl',[chunk('strh',strh),chunk('strf',strf)])]);
  const frame=chunk('00dc',jpeg),index=Buffer.alloc(frameCount*16);
  for(let i=0;i<frameCount;i++) {
    const at=i*16;index.write('00dc',at,4,'ascii');index.writeUInt32LE(0x10,at+4);index.writeUInt32LE(4+i*frame.length,at+8);index.writeUInt32LE(jpeg.length,at+12);
  }
  const video=chunk('RIFF',Buffer.concat([Buffer.from('AVI ','ascii'),header,list('movi',Array(frameCount).fill(frame)),chunk('idx1',index)]));
  return {video,metadata:{format:'AVI_MJPEG',width,height,fps,frameCount,durationSeconds:frameCount/fps,bytes:video.length,synthetic:true,audio:false}};
}
