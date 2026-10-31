// Negative evidence controls, not substitutes for the real browser matrix.
import assert from 'node:assert/strict';
import {assertRejectedImport,assertSameLogicalProject,assertFrozenSave,assertProjectSource,assertBrowserFileDelivery,assertMassOnlyPhysicsPreserved,assertBodiesContainedInViewport,unexpectedConsoleErrors} from './sf_m4_browser_assertions.mjs';

const clone=x=>structuredClone(x);
const before={generation:7,mode:'run',paused:true,tick:190,rapier_steps:190,current_hash:'live',definition_hash:'initial',
  initial_hash:'cells',pristine:false,intervention_count:2,mutation_count:6,document:{revision:5,undo_depth:0},
  object_definitions:[{id:'stable-a',mass:2}],native:{body_ids:['stable-a'],body_states:[[12,34,.2,1,2,.3,false]],
    body_sizes:[[8,16]],slot_mapping:{epoch:9,sample_serial:191,project_ids:['stable-a'],slots:1}}};
assertRejectedImport(before,clone(before));
for(const key of ['generation','tick','rapier_steps','current_hash','definition_hash','initial_hash','pristine','intervention_count','mutation_count']){
  const after=clone(before);after[key]=typeof after[key]==='number'?after[key]+1:String(after[key])+'changed';
  assert.throws(()=>assertRejectedImport(before,after),/Refused archive/);
}
for(const change of [s=>s.object_definitions[0].mass=4,s=>s.native.body_ids[0]='other',s=>s.native.body_states[0][0]+=2,
  s=>s.native.body_sizes[0][0]+=2,s=>s.native.slot_mapping.epoch++,s=>s.document.revision++]){
  const after=clone(before);change(after);assert.throws(()=>assertRejectedImport(before,after));
}
const zip={scene:{seed:0},objects:{objects:[]},style:{theme:'default'},annotations:[],world_sha256:'a'.repeat(64),
  world_bytes:5242880,manifest:{project:{id:'test',title:'Test'},source:{source_commit:'a'.repeat(40)}},
  logical_files:{'world/cells.bin':{sha256:'a'.repeat(64),bytes:5242880}}};
assertSameLogicalProject(zip,clone(zip));assertFrozenSave(zip,clone(zip));
for(const key of ['scene','objects','style','annotations','world_sha256','world_bytes','logical_files']){
  const next=clone(zip);next[key]='changed';assert.throws(()=>assertSameLogicalProject(zip,next));
}
const identity={source_commit:'a'.repeat(40),native_runtime_sha256:'b'.repeat(64)};
assertProjectSource(identity,{project_source_identity:clone(identity)});
assert.throws(()=>assertProjectSource({...identity,native_runtime_sha256:'c'.repeat(64)},{project_source_identity:identity}));
const delivered={type:'change',targetId:'sandfall-project-file',isTrusted:true,files:[{name:'current.sandfall',size:100}]};
const transfer={start_index:1,end_index:2,name:'current.sandfall',bytes:100};
assert.deepEqual(assertBrowserFileDelivery([clone(delivered),clone(delivered)],transfer),delivered);
// An earlier equal-name/equal-size upload cannot qualify the current attempt.
assert.throws(()=>assertBrowserFileDelivery([clone(delivered),{type:'mousemove'}],transfer));
for(const current of [{...delivered,isTrusted:false},{...delivered,files:[{name:'previous.sandfall',size:100}]},
  {...delivered,files:[{name:'current.sandfall',size:101}]},{...delivered,files:[]}])
  assert.throws(()=>assertBrowserFileDelivery([clone(delivered),current],transfer));
assert.throws(()=>assertBrowserFileDelivery([clone(delivered),clone(delivered),clone(delivered)],{...transfer,end_index:3}));
for(const altered of [{...transfer,end_index:1},{...transfer,start_index:-1},{...transfer,end_index:3}])
  assert.throws(()=>assertBrowserFileDelivery([clone(delivered),clone(delivered)],altered));
const massBefore=clone(before);massBefore.frame=100;
massBefore.native.body_states[0][6]=true;
massBefore.object_definitions.push({id:'stable-b',mass:4});massBefore.native.body_ids.push('stable-b');
massBefore.native.body_states.push([80,90,-.4,3,-2,-.5,true]);massBefore.native.body_sizes.push([10,12]);
const massAfter=clone(massBefore);massAfter.frame=104;massAfter.object_definitions[0].mass=3;
assertMassOnlyPhysicsPreserved(massBefore,massAfter,'stable-a',3);
const woken=clone(massAfter);woken.native.body_states[0][6]=false;
assertMassOnlyPhysicsPreserved(massBefore,woken,'stable-a',3);
const unrelatedWake=clone(massAfter);unrelatedWake.native.body_states[1][6]=false;
assert.throws(()=>assertMassOnlyPhysicsPreserved(massBefore,unrelatedWake,'stable-a',3),/unrelated body sleeping/);
const awakeBefore=clone(massBefore);awakeBefore.native.body_states[0][6]=false;
assert.throws(()=>assertMassOnlyPhysicsPreserved(awakeBefore,massAfter,'stable-a',3),/put the changed body to sleep/);
for(let body=0;body<2;body++)for(let component=0;component<6;component++){
  const changed=clone(massAfter);changed.native.body_states[body][component]+=1;
  assert.throws(()=>assertMassOnlyPhysicsPreserved(massBefore,changed,'stable-a',3),/after idle frames/);
}
for(const change of [s=>s.frame=101,s=>s.tick++,s=>s.rapier_steps++,s=>s.native.body_ids.reverse(),
  s=>s.object_definitions[1].mass++,s=>s.native.body_sizes[1][0]++]){
  const changed=clone(massAfter);change(changed);
  assert.throws(()=>assertMassOnlyPhysicsPreserved(massBefore,changed,'stable-a',3));
}
const visible=clone(massBefore);visible.camera={camera_origin:[0,0],view_size:[480,270]};
assert.equal(assertBodiesContainedInViewport(visible).body_count,2);
const clipped=clone(visible);clipped.native.body_states[0]=[200,0.393,0,0,-20.9,0,false];
clipped.native.body_sizes[0]=[14,14];
assert.throws(()=>assertBodiesContainedInViewport(clipped),/clipped outside/);
for(const [x,y,rotation] of [[1,40,0],[479,40,0],[200,269,0],[200,6,Math.PI/4]]){
  const changed=clone(visible);changed.native.body_states[0]=[x,y,rotation,0,0,0,false];
  changed.native.body_sizes[0]=[14,14];assert.throws(()=>assertBodiesContainedInViewport(changed),/clipped outside/);
}
const zoomed=clone(visible);zoomed.camera={camera_origin:[10,30],view_size:[100,100]};
assert.throws(()=>assertBodiesContainedInViewport(zoomed),/clipped outside/);
const empty=clone(visible);empty.native.body_ids=[];empty.native.body_states=[];empty.native.body_sizes=[];
assert.equal(assertBodiesContainedInViewport(empty).body_count,0);
const diagnostic=[{type:'log',text:'normal'},{type:'error',text:'ERROR: Decompression failed.\n   at: func_PackedByteArray_decompress_dynamic (core/variant/variant_call.cpp:844)'}];
const witness={case:'external_crc',fixture_sha256:'a'.repeat(64),refusal:'zip_decompression_size_or_crc',old_world_preserved:true,start_index:1,end_index:2};
assert.deepEqual(unexpectedConsoleErrors(diagnostic,[witness]),[]);
assert.equal(unexpectedConsoleErrors(diagnostic,[]).length,1);
for(const altered of [{...witness,old_world_preserved:false},{...witness,refusal:'other'},{...witness,fixture_sha256:'missing'}])
  assert.throws(()=>unexpectedConsoleErrors(diagnostic,[altered]));
assert.throws(()=>unexpectedConsoleErrors([{type:'log',text:'normal'},{type:'error',text:'ERROR: Another failure'}],[witness]));
assert.equal(unexpectedConsoleErrors([...diagnostic,{type:'error',text:'ERROR: Decompression failed.'}],[witness]).length,1);
console.log('SF_M4_BROWSER_ASSERTIONS passed: exact refusal, canonical round-trip, frozen save, source identity, current trusted file delivery, idle-frame property invariance and complete-body visibility negatives');
