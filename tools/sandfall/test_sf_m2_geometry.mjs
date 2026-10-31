import test from 'node:test';
import assert from 'node:assert/strict';
import {mapWorldCell} from './sf_m2_geometry.mjs';
const layout = {width:1280,height:800,stretch_mode:'canvas_items',stretch_aspect:'keep'};
const view = [306,130.5625,958,538.875];
const camera = {camera_origin:[0,0],view_size:[480,270]};
const metrics = (width,height,dpr) => ({canvas:{x:0,y:0,width,height},
  backing:{width:width*dpr,height:height*dpr},viewport:{width,height},devicePixelRatio:dpr});
const cellAt = (point, mapped, view, camera) => ['x','y'].map((axis,i) => {
  const logical=(point[axis]-mapped.transform.offset[axis])/mapped.transform.scale[axis];
  return Math.floor(camera.camera_origin[i]+(logical-view[i])/view[i+2]*camera.view_size[i]);
});

test('retained DPR1 fractional centre lands in column9; integral target selects10 on both paths',()=>{
  const m=mapWorldCell([10,10],view,camera,metrics(800,450,1),layout);
  assert.deepEqual(cellAt({x:Math.floor(m.center.x),y:Math.floor(m.center.y)},m,view,camera),[9,10]);
  assert.deepEqual(m.point,{x:224,y:85});
  assert.deepEqual(cellAt(m.point,m,view,camera),[10,10]);
});
test('retained DPR2 centre truncates into row9; integral target selects10 on both paths',()=>{
  const m=mapWorldCell([10,10],view,camera,metrics(640,400,2),layout);
  assert.deepEqual(cellAt({x:Math.floor(m.center.x),y:Math.floor(m.center.y)},m,view,camera),[10,9]);
  assert.deepEqual(m.point,{x:163,y:76});
  assert.deepEqual(cellAt(m.point,m,view,camera),[10,10]);
});
test('all current editor fixture cells resolve exactly at both aspect/DPR profiles',()=>{
  const cells=[[10,10],[20,10],[15,10],[100,40],[120,60],[80,80],[100,80],[50,40],[52,42],
    [110,50],[105,45],[108,48],[150,45],[151,46],[153,46],[400,200],[240,50],[260,50],
    [400,20],[250,50],[350,50],[352,50]];
  for(const [w,h,d] of [[800,450,1],[640,400,2]]) for(const cell of cells) {
    const m=mapWorldCell(cell,view,camera,metrics(w,h,d),layout);
    assert.deepEqual(cellAt(m.point,m,view,camera),cell);
    assert.ok(Number.isInteger(m.point.x)&&Number.isInteger(m.point.y));
  }
});
test('offset canvas and panned/zoomed camera use measured transforms, not DPR guesses',()=>{
  const c={camera_origin:[100,20],view_size:[240,135]};
  const browser={...metrics(800,450,1),canvas:{x:30,y:20,width:800,height:450},viewport:{width:900,height:500}};
  const m=mapWorldCell([200,70],view,c,browser,layout);
  assert.deepEqual(cellAt(m.point,m,view,c),[200,70]);
});
test('subpixel cells with no interior integer are refused, never silently shifted',()=>{
  assert.throws(()=>mapWorldCell([0,0],view,camera,metrics(640,400,2),layout),/no interior integer/);
  assert.throws(()=>mapWorldCell([10,10],view,camera,metrics(160,100,1),layout),/no interior integer/);
});
test('off-camera, invalid and nonfinite input cannot produce a hit target',()=>{
  for(const cell of [[-1,10],[1024,10],[1.5,10],[NaN,10],[500,20],[10,270]])
    assert.throws(()=>mapWorldCell(cell,view,camera,metrics(800,450,1),layout));
  assert.throws(()=>mapWorldCell([10,10],view,{...camera,view_size:[0,270]},metrics(800,450,1),layout));
});
