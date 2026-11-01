// Independently decode screenshot bytes and score the interior of every actual
// Rapier body. Bright UI or three visible shader slots cannot satisfy this gate.
import assert from 'node:assert/strict';
import {inflateSync} from 'node:zlib';
import {pngDimensions} from './sf_m0_png_stats.mjs';
import {mapGodotRect} from './sf_m0_geometry.mjs';

export function decodeRgb(buffer) {
  const {width,height}=pngDimensions(buffer);
  let channels,kind,ended=false,header=false;const chunks=[];
  for(let p=8;p<buffer.length;) {
    assert.ok(p+12<=buffer.length,'Truncated PNG chunk header');
    const size=buffer.readUInt32BE(p),type=buffer.toString('ascii',p+4,p+8);
    assert.ok(size<=buffer.length-p-12,'Truncated PNG chunk data');
    const data=buffer.subarray(p+8,p+8+size);
    if(type==='IHDR') {
      assert.equal(header,false,'Repeated PNG header');header=true;
      assert.equal(size,13);kind=data[9];channels=({0:1,2:3,4:2,6:4})[kind];
      assert.ok(channels&&data[8]===8&&data[10]===0&&data[11]===0&&data[12]===0,'Unsupported PNG layout');
    }
    if(type==='IDAT')chunks.push(data);
    p+=size+12;
    if(type==='IEND'){assert.equal(size,0);assert.equal(p,buffer.length);ended=true;break;}
  }
  assert.ok(ended&&chunks.length>0,'Truncated PNG or missing image payload');
  const stride=width*channels,raw=inflateSync(Buffer.concat(chunks),{maxOutputLength:(stride+1)*height});
  assert.equal(raw.length,(stride+1)*height,'PNG row length mismatch');
  const pixels=Buffer.alloc(width*height*3),previous=Buffer.alloc(stride),row=Buffer.alloc(stride);
  for(let y=0;y<height;y++) {
    const offset=y*(stride+1),filter=raw[offset];assert.ok(filter<=4,'Unsupported PNG filter');
    for(let x=0;x<stride;x++) {
      const a=x>=channels?row[x-channels]:0,b=previous[x],c=x>=channels?previous[x-channels]:0;
      let value=raw[offset+1+x];
      if(filter===1)value+=a;
      if(filter===2)value+=b;
      if(filter===3)value+=Math.floor((a+b)/2);
      if(filter===4){const p=a+b-c,da=Math.abs(p-a),db=Math.abs(p-b),dc=Math.abs(p-c);value+=da<=db&&da<=dc?a:db<=dc?b:c;}
      row[x]=value&255;
    }
    for(let x=0;x<width;x++) {
      const i=x*channels,o=(y*width+x)*3,alpha=(kind===4||kind===6)?row[i+channels-1]/255:1;
      pixels[o]=Math.round(row[i]*alpha);
      pixels[o+1]=Math.round(row[i+(kind===0||kind===4?0:1)]*alpha);
      pixels[o+2]=Math.round(row[i+(kind===0||kind===4?0:2)]*alpha);
    }
    row.copy(previous);
  }
  return {width,height,pixels};
}
function localAt(world,pose) {
  const dx=world[0]-pose[0],dy=world[1]-pose[1],c=Math.cos(pose[2]),s=Math.sin(pose[2]);
  return [c*dx+s*dy,-s*dx+c*dy];
}
export function analyzeBodies(buffer,state,metrics,layout) {
  assert.equal(state.menu,false,'Modal pixels cannot qualify bodies');
  assert.equal(state.editor?.object_gesture_active,false,'Object preview obscures physical rendering');
  assert.ok(!state.editor?.selected_object_id,'Selection must be cleared before scoring actual body pixels');
  const decoded=decodeRgb(buffer),{width,height,pixels}=decoded;
  const view=mapGodotRect(state.view,metrics,layout).css,origin=state.camera.camera_origin,size=state.camera.view_size;
  const ids=state.native.body_ids,poses=state.native.body_states,sizes=state.native.body_sizes;
  assert.ok(Array.isArray(ids)&&ids.length===poses.length&&ids.length===sizes.length,'Incomplete render geometry');
  const bodyResults=ids.map((id,i)=>({id,slot:i,pose:poses[i].slice(0,3),size:sizes[i],samples:0,body_colour:0,occluded_samples:0}));
  const sx=width/metrics.viewport.width,sy=height/metrics.viewport.height;
  const x0=Math.max(0,Math.ceil(view.x*sx)),x1=Math.min(width,Math.floor((view.x+view.width)*sx));
  const y0=Math.max(0,Math.ceil(view.y*sy)),y1=Math.min(height,Math.floor((view.y+view.height)*sy));
  assert.ok(x0<x1&&y0<y1,'No actual world pixels are visible');
  let bodyColourPixels=0;
  for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++) {
    const pixelOffset=(y*width+x)*3,red=pixels[pixelOffset],green=pixels[pixelOffset+1],blue=pixels[pixelOffset+2];
    const isBodyColour=red>=210&&red<=255&&green>=35&&green<=90&&blue>=25&&blue<=85&&red-green>=125;
    if(isBodyColour)bodyColourPixels++;
    // Match the native cell raster contract, using measured CSS/screenshot
    // dimensions. Geometry alone never supplies a colour or a pass.
    const world=[Math.floor(origin[0]+((x+.5)/sx-view.x)/view.width*size[0])+.5,
      Math.floor(origin[1]+((y+.5)/sy-view.y)/view.height*size[1])+.5];
    for(let i=0;i<ids.length;i++) {
      const local=localAt(world,poses[i]);
      if(Math.abs(local[0])>=sizes[i][0]*.28||Math.abs(local[1])>=sizes[i][1]*.28)continue;
      const r=bodyResults[i];
      // A covered box is not independently visible. Never count another
      // object's red pixels as this object's evidence.
      const overlapped=poses.some((pose,j)=>{if(j===i)return false;const p=localAt(world,pose);return Math.abs(p[0])<sizes[j][0]*.5&&Math.abs(p[1])<sizes[j][1]*.5;});
      if(overlapped){r.occluded_samples++;continue;}
      r.samples++;
      if(isBodyColour)r.body_colour++;
    }
  }
  if(ids.length===0)assert.equal(bodyColourPixels,0,'Zero-body Wall/Water workload rendered phantom body-colour pixels');
  for(const result of bodyResults) {
    result.body_colour_fraction=result.samples?result.body_colour/result.samples:0;
    assert.ok(result.samples>=4,`Body ${result.id} has fewer than four independently visible world pixels`);
    assert.ok(result.body_colour_fraction>=.8,`Body ${result.id} (slot ${result.slot}) is not rendered at its real geometry: ${JSON.stringify(result)}`);
  }
  return {schema:'sandfall-body-pixels-v1',region:{x0,x1,y0,y1},body_count:ids.length,
    expected_shader_colour:[.95,.22,.18],body_colour_pixels:bodyColourPixels,core_fraction_of_half_size:.56,minimum_independent_samples:4,
    minimum_body_colour_fraction:.8,bodies:bodyResults};
}
