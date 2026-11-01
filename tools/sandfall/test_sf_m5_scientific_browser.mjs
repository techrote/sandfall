import test from 'node:test';
import assert from 'node:assert/strict';
import {CELLS,TUPLES,inspectedSample,assertSampleEpoch,assertExactHistory,
  assertChemicalFirstStep,assertChemicalConversion,assertChemicalReset} from './sf_m5_scientific_browser_assertions.mjs';

// These synthetic records exercise fail-closed readers, never physics.
const a='a'.repeat(64),b='b'.repeat(64);
function state(){return {schema:'sandfall-host-v1',app_ready:true,ready:true,entry:'sandbox',scene_id:'blank',
  mode:'edit',paused:true,menu:false,fault:false,workers:1,tick:0,rapier_steps:0,rapier_active:false,generation:1,
  frame:10,actor_count:0,paint_commands:0,mutation_count:0,render_rejections:0,pending_steps:0,initial_hash:a,
  current_hash:a,definition_hash:a,body_poses:[],initial_body_poses:[],simulation_interest:{origin:[0,0],size:[1024,1024]},
  native:{native_revision:1},pristine:true,intervention_count:0,history_retired:false,
  document:{valid:true,cells_sha256:a,revision:0,undo_depth:0,redo_depth:0,history_bytes:0,locked:false,retired:false,can_undo:false,can_redo:false},
  editor:{inspected:{...TUPLES.steam,x:CELLS.steam[0],y:CELLS.steam[1]}}};}
function sample(s,cell,tuple){return {cell:[...cell],tuple:{...tuple},generation:s.generation,tick:s.tick,
  native_revision:s.native.native_revision,current_hash:s.current_hash,frame:s.frame};}
function first(){
  const before=state();before.mode='run';before.document.locked=true;
  const after=structuredClone(before);Object.assign(after,{tick:1,current_hash:b,frame:20,history_retired:true});
  after.document.retired=true;after.native.native_revision=2;
  const samples={steam:sample(after,CELLS.steam,TUPLES.steamFirst),hotSource:sample(after,CELLS.hot,TUPLES.empty),hotDestination:sample(after,CELLS.fallen,TUPLES.hot)};
  return {before,after,samples};
}

test('native picker demands all four exact tuple fields and the exact cell',()=>{
  const s=state();assert.deepEqual(inspectedSample(s,CELLS.steam,TUPLES.steam).tuple,TUPLES.steam);
  for(const [field,value] of [['id',3],['state_a',179],['state_b',1],['temperature',1499],['x',201],['y',111],['temperature',NaN]]){
    const bad=structuredClone(s);bad.editor.inspected[field]=value;assert.throws(()=>inspectedSample(bad,CELLS.steam,TUPLES.steam));
  }
});

test('a stale picker dictionary cannot be attached to another native state',()=>{
  const s=state(),p=sample(s,CELLS.steam,TUPLES.steam);assertSampleEpoch(p,s,CELLS.steam,TUPLES.steam);
  for(const [field,value] of [['generation',2],['tick',1],['native_revision',2],['current_hash',b],['frame',11]])
    assert.throws(()=>assertSampleEpoch({...p,[field]:value},s,CELLS.steam,TUPLES.steam));
  assert.throws(()=>assertSampleEpoch(p,s,CELLS.hot,TUPLES.steam));
});

test('first native Step requires actual one-tick counters and both chemical and thermal changes',()=>{
  const {before,after,samples}=first();assertChemicalFirstStep(before,after,samples);
  for(const delta of [{tick:2},{tick:0},{rapier_steps:1},{paused:false},{initial_hash:b},{intervention_count:1},{current_hash:a}])
    assert.throws(()=>assertChemicalFirstStep(before,{...after,...delta},samples));
  for(const [key,tuple] of [['steam',TUPLES.steam],['hotSource',TUPLES.hot],['hotDestination',TUPLES.empty]]){
    const bad=structuredClone(samples);bad[key].tuple=tuple;assert.throws(()=>assertChemicalFirstStep(before,after,bad));
  }
});

test('first advancement cannot retain chemical Edit history or change frozen authored cells',()=>{
  const {before,after,samples}=first();
  for(const delta of [{undo_depth:1},{redo_depth:1},{can_undo:true},{retired:false},{cells_sha256:b}])
    assert.throws(()=>assertChemicalFirstStep(before,{...after,document:{...after.document,...delta}},samples));
});

test('conversion needs an executed lifetime, real Water product and no intervention',()=>{
  const {after}=first();after.tick=180;
  const p=sample(after,CELLS.steam,TUPLES.water);assertChemicalConversion(state(),after,p);
  for(const delta of [{tick:179},{paused:false},{rapier_steps:1},{intervention_count:1},{initial_hash:b}])
    assert.throws(()=>assertChemicalConversion(state(),{...after,...delta},p));
  assert.throws(()=>assertChemicalConversion(state(),after,{...p,tuple:TUPLES.steam}));
  assert.throws(()=>assertChemicalConversion(state(),after,{...p,tick:179}));
});

test('Undo/Redo must restore complete payload hashes with one exact history transition',()=>{
  const before=state();before.current_hash=b;before.document={...before.document,cells_sha256:b,revision:3,undo_depth:2,can_undo:true};
  const after=structuredClone(before);after.current_hash=a;Object.assign(after.document,{cells_sha256:a,revision:4,undo_depth:1,redo_depth:1,can_redo:true});
  assertExactHistory(before,after,'undo',a);
  for(const delta of [{current_hash:b},{tick:1},{generation:2}])assert.throws(()=>assertExactHistory(before,{...after,...delta},'undo',a));
  for(const delta of [{revision:5},{undo_depth:0},{redo_depth:0},{cells_sha256:b}])
    assert.throws(()=>assertExactHistory(before,{...after,document:{...after.document,...delta}},'undo',a));
});

test('Reset cannot keep evolved tuples, a stale generation or resurrect previous history',()=>{
  const authored=state(),before=first().after;before.tick=180;
  const after=state();after.generation=2;after.frame=25;
  const samples={steam:sample(after,CELLS.steam,TUPLES.steam),hotSource:sample(after,CELLS.hot,TUPLES.hot),hotDestination:sample(after,CELLS.fallen,TUPLES.empty)};
  assertChemicalReset(authored,before,after,samples);
  for(const delta of [{generation:1},{current_hash:b},{initial_hash:b},{history_retired:true},{pristine:false},{intervention_count:1},{tick:1}])
    assert.throws(()=>assertChemicalReset(authored,before,{...after,...delta},samples));
  for(const delta of [{undo_depth:1},{redo_depth:1},{history_bytes:14}])
    assert.throws(()=>assertChemicalReset(authored,before,{...after,document:{...after.document,...delta}},samples));
  const bad=structuredClone(samples);bad.steam.tuple=TUPLES.water;
  assert.throws(()=>assertChemicalReset(authored,before,after,bad));
});
