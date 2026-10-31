import test from 'node:test';
import assert from 'node:assert/strict';
import {deflateSync} from 'node:zlib';
import {analyzeBodies,decodeRgb} from './sf_m3_pixels.mjs';
import {mapGodotRect} from './sf_m0_geometry.mjs';
function chunk(name,payload){const tag=Buffer.from(name),bytes=Buffer.concat([tag,payload]);let crc=0xffffffff;for(const byte of bytes){crc^=byte;for(let i=0;i<8;i++)crc=crc&1?(crc>>>1)^0xedb88320:crc>>>1;}const out=Buffer.alloc(payload.length+12);out.writeUInt32BE(payload.length);bytes.copy(out,4);out.writeUInt32BE((crc^0xffffffff)>>>0,out.length-4);return out;}
function png(width,height,pixel,{filter=0,alpha=255}={}){
  const rows=[],previous=Buffer.alloc(width*4);
  for(let y=0;y<height;y++){const raw=Buffer.alloc(width*4),row=Buffer.alloc(width*4+1);row[0]=filter;
    for(let x=0;x<width;x++){const rgb=pixel(x,y);raw[x*4]=rgb[0];raw[x*4+1]=rgb[1];raw[x*4+2]=rgb[2];raw[x*4+3]=alpha;}
    for(let x=0;x<raw.length;x++){const a=x>=4?raw[x-4]:0,b=previous[x],c=x>=4?previous[x-4]:0;let predictor=0;
      if(filter===1)predictor=a;if(filter===2)predictor=b;if(filter===3)predictor=Math.floor((a+b)/2);
      if(filter===4){const p=a+b-c,da=Math.abs(p-a),db=Math.abs(p-b),dc=Math.abs(p-c);predictor=da<=db&&da<=dc?a:db<=dc?b:c;}
      row[x+1]=(raw[x]-predictor+256)%256;}
    raw.copy(previous);rows.push(row);}
  const header=Buffer.alloc(13);header.writeUInt32BE(width);header.writeUInt32BE(height,4);header[8]=8;header[9]=6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(Buffer.concat(rows))),chunk('IEND',Buffer.alloc(0))]);
}
const layout={width:1280,height:800,stretch_mode:'canvas_items',stretch_aspect:'keep'};
function fixture({width=800,height=450,dpr=1,count=16}={}){
  const metrics={canvas:{x:0,y:0,width,height},backing:{width:width*dpr,height:height*dpr},viewport:{width,height},devicePixelRatio:dpr};
  const ids=Array.from({length:count},(_,i)=>'box-'+i),poses=ids.map((_,i)=>[48+(i%8)*52,65+Math.floor(i/8)*60,i%3===1?.25:0,0,0,0,false]);
  const state={menu:false,editor:{object_gesture_active:false,selected_object_id:''},view:[80,110,1120,630],camera:{camera_origin:[0,0],view_size:[480,270]},native:{body_ids:ids,body_states:poses,body_sizes:ids.map(()=>[16,18])}};
  const mapped=mapGodotRect(state.view,metrics,layout).css;
  function image(visible=count,options={}){return png(width*dpr,height*dpr,(x,y)=>{
    const css={x:(x+.5)/dpr,y:(y+.5)/dpr};
    if(css.x<mapped.x||css.x>=mapped.x+mapped.width||css.y<mapped.y||css.y>=mapped.y+mapped.height)return[255,180,80];
    const world=[Math.floor((css.x-mapped.x)/mapped.width*480)+.5,Math.floor((css.y-mapped.y)/mapped.height*270)+.5];
    for(let i=0;i<visible;i++){const p=poses[i],dx=world[0]-p[0],dy=world[1]-p[1],c=Math.cos(p[2]),s=Math.sin(p[2]);
      if(Math.abs(c*dx+s*dy)<8&&Math.abs(-s*dx+c*dy)<9)return[242,56,46];}
    return[4,8,12];
  },options);}
  return {state,metrics,image};
}
test('all 16 bodies require independent red pixels at measured transforms in both profiles',()=>{
  for(const profile of [{width:800,height:450,dpr:1},{width:640,height:400,dpr:2}]){
    const f=fixture(profile),e=analyzeBodies(f.image(),f.state,f.metrics,layout);
    assert.equal(e.body_count,16);assert.ok(e.bodies.every(b=>b.samples>=4&&b.body_colour_fraction===1));
  }
});
test('a surviving three-slot shader and missing last body fail despite bright surrounding UI',()=>{
  const f=fixture();for(const count of [0,3,8,15])assert.throws(()=>analyzeBodies(f.image(count),f.state,f.metrics,layout),/not rendered/);
});
test('body colour in the wrong place and an overlapping hidden body cannot count twice',()=>{
  const f=fixture(),bytes=f.image();f.state.native.body_states[15][0]-=24;
  assert.throws(()=>analyzeBodies(bytes,f.state,f.metrics,layout),/not rendered/);
  const overlapping=fixture();overlapping.state.native.body_states[15]=[...overlapping.state.native.body_states[0]];
  assert.throws(()=>analyzeBodies(overlapping.image(),overlapping.state,overlapping.metrics,layout),/independently visible/);
});
test('transparent or selected/preview/modal pixels cannot qualify the physical object renderer',()=>{
  const f=fixture();assert.throws(()=>analyzeBodies(f.image(16,{alpha:0}),f.state,f.metrics,layout),/not rendered/);
  for(const change of [s=>s.menu=true,s=>s.editor.object_gesture_active=true,s=>s.editor.selected_object_id='box-1']){
    const s=structuredClone(f.state);change(s);assert.throws(()=>analyzeBodies(f.image(),s,f.metrics,layout));}
});
test('independent PNG decoder reconstructs all five scanline filters and rejects corrupt streams',()=>{
  const f=fixture({count:1}),expected=decodeRgb(f.image());
  for(const filter of [1,2,3,4])assert.deepEqual(decodeRgb(f.image(1,{filter})),expected);
  for(const cut of [8,32,expected.pixels.length]){
    const data=f.image();if(cut<data.length)assert.throws(()=>decodeRgb(data.subarray(0,cut)));}
  const data=f.image();assert.throws(()=>decodeRgb(data.subarray(0,data.length-1)));
});

test('zero-body physical workload cannot hide a phantom red body behind an empty registry',()=>{
  const f=fixture({count:0});assert.equal(analyzeBodies(f.image(),f.state,f.metrics,layout).body_colour_pixels,0);
  const one=fixture({count:1});assert.throws(()=>analyzeBodies(one.image(),f.state,f.metrics,layout),/phantom/);
});
