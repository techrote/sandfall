import test from 'node:test';
import assert from 'node:assert/strict';
import {assertRegistry,assertObjectEdit,assertObjectRefusal,authoredState,assertAuthoredState,
  assertObjectIntervention,assertObjectReset,assertPhysicalWorkload} from './sf_m3_browser_assertions.mjs';
import {assertTrustedDelivery} from './sf_m2_browser_assertions.mjs';
const hash='a'.repeat(64),changed='b'.repeat(64);
function definition(i){return {schema_version:1,id:'object-'+i,creation_order:i,shape:'box',name:'',passive_subject:false,
  position:[40+i*25,80],size:[16,18],rotation:0,mass:1,friction:.78,restitution:0,gravity_scale:.094,
  linear_damp:.15,angular_damp:.35,linear_velocity:[0,0],angular_velocity:0,fixed:false,frozen:false};}
function state(n=0){const definitions=Array.from({length:n},(_,i)=>definition(i+1)),body_states=definitions.map(d=>[...d.position,d.rotation,...d.linear_velocity,d.angular_velocity,false]);
  return {schema:'sandfall-host-v1',app_ready:true,ready:true,entry:'sandbox',scene_id:'blank',mode:'edit',paused:true,menu:false,fault:false,
    workers:1,tick:0,rapier_steps:0,rapier_active:n>0,rapier_available:n>0,generation:1,definition_hash:hash,initial_hash:hash,current_hash:hash,
    body_poses:body_states.map(a=>a.slice(0,3)),initial_body_poses:body_states.map(a=>a.slice(0,3)),actor_count:0,paint_commands:0,mutation_count:0,
    render_rejections:0,pending_steps:0,native:{native_revision:1,body_ids:definitions.map(d=>d.id),body_states,initial_body_states:structuredClone(body_states),body_sizes:definitions.map(d=>d.size),logical_objects:definitions,object_definitions:definitions,
      bridge_active:n>0,rapier_available:n>0,rapier_probe_deferred:n===0,rapier_probe:n?{ok:true,reason:'Manual-step/CCD probe passed',y:72.5}:{},
      slot_mapping:{epoch:n?1:0,project_ids:definitions.map(d=>d.id),sample_serial:0,slots:n},object_feedback:{},body_body_pairs:[]},
    rendering:{body_count:n,body_ids:definitions.map(d=>d.id),body_capacity:16},simulation_interest:{origin:[0,0],size:[1024,1024]},
    document:{valid:true,cells_sha256:hash,revision:0,undo_depth:0,redo_depth:0,history_bytes:0,locked:false,retired:false,can_undo:false,can_redo:false},
    input:{held_keys:[],pointer_buttons:0,gesture_active:false,pending_ui_gestures:0,clear_serial:0},camera:{origin:[0,0],zoom:1},pristine:true,intervention_count:0};}
function run(s){return {...structuredClone(s),mode:'run',tick:600,rapier_steps:s.rapier_active?600:0,history_retired:true,moves:10,contacts_total:0,displaced_total:0,document:{...s.document,locked:true,retired:true}};}
function edit(){const s=state(1);return {...s,mutation_count:1,paint_commands:1,last_edit:{accepted:true,mode:'edit'},document:{...s.document,revision:1,undo_depth:1,history_bytes:500}};}
test('actual 0,1,3,8,16 graph requires all aligned IDs, physical state and definitions',()=>{
  for(const n of [0,1,3,8,16])assertRegistry(state(n),n);
  for(const n of [-1,17,NaN])assert.throws(()=>assertRegistry(state(),n));
  const s=state(16);s.native.body_states.pop();assert.throws(()=>assertRegistry(s,16),/body count/);
});
test('duplicate stable IDs, slot permutations and nonfinite logical/physical data cannot pass',()=>{
  for(const corrupt of [s=>s.native.body_ids[1]=s.native.body_ids[0],s=>s.native.slot_mapping.project_ids.reverse(),
    s=>s.native.logical_objects[0].mass=0,s=>s.native.logical_objects[0].size=[NaN,2],s=>s.native.body_states[0][4]=Infinity,
    s=>s.native.body_sizes[0]=[99,99],s=>s.native.logical_objects[0].position='(40,80)',s=>s.native.slot_mapping.slots=3,s=>s.native.logical_objects[0].shape='circle',s=>s.native.logical_objects[1].creation_order=1]) {
    const s=state(8);corrupt(s);assert.throws(()=>assertRegistry(s,8));
  }
});
test('true zero defers all Rapier work while every nonempty graph needs its positive probe',()=>{
  assertRegistry(state(),0);assertRegistry(state(1),1);
  for(const change of [s=>s.native.rapier_probe={ok:true,y:72.5},s=>s.rapier_available=true,
    s=>s.native.body_ids=['phantom'],s=>s.native.body_states=[[1,2,0,0,0,0,false]],
    s=>s.native.logical_objects=[definition(1)],s=>s.native.slot_mapping.project_ids=['phantom'],
    s=>s.rendering.body_count=1,s=>s.rendering.body_ids=['phantom'],s=>s.rapier_steps=1,
    s=>s.native.slot_mapping.sample_serial=1,s=>s.native.initial_body_states=[[1,2,0,0,0,0,false]]]) {
    const value=state();change(value);assert.throws(()=>assertRegistry(value,0));
  }
  for(const change of [s=>s.native.rapier_probe_deferred=true,s=>s.native.rapier_probe={},
    s=>s.native.rapier_probe.ok=false,s=>{s.native.rapier_available=s.rapier_available=false;}]) {
    const value=state(16);change(value);assert.throws(()=>assertRegistry(value,16));
  }
  const retired=state();retired.native.rapier_probe_deferred=false;
  retired.native.rapier_available=retired.rapier_available=true;
  retired.native.rapier_probe={ok:true,reason:'Manual-step/CCD probe passed',y:72.5};
  retired.native.slot_mapping.epoch=3;retired.native.slot_mapping.sample_serial=43;retired.rapier_steps=10;
  assertRegistry(retired,0); // Deletion retains a genuine earlier probe/counter.
});
test('one completed object edit shares history and cannot paint native cells',()=>{
  assertObjectEdit(state(),edit(),1);
  for(const change of [s=>s.document.undo_depth=2,s=>s.document.history_bytes=64*1024*1024+1,s=>s.current_hash=changed,s=>s.tick=1,s=>s.mutation_count=2]) {
    const s=edit();change(s);assert.throws(()=>assertObjectEdit(state(),s,1));
  }
});
test('refusal protects actual object graph, mapping, journal and Modified status',()=>{
  const s=state(16);assertObjectRefusal(s,structuredClone(s));
  for(const change of [x=>x.native.logical_objects[5].mass=2,x=>x.native.slot_mapping.epoch++,x=>x.native.body_ids.reverse(),x=>x.pristine=false,x=>x.intervention_count++]) {
    const changed=structuredClone(s);change(changed);assert.throws(()=>assertObjectRefusal(s,changed));
  }
});
test('mixed exact history requires stable identities, complete properties and actual poses',()=>{
  const s=state(3),original=authoredState(s);assertAuthoredState(s,original);
  for(const change of [x=>x.current_hash=changed,x=>x.native.logical_objects[0].friction=.2,x=>x.native.logical_objects[0].linear_velocity[1]=3,
    x=>x.native.body_states[1][0]+=1,x=>x.native.body_ids.reverse()]){const c=structuredClone(s);change(c);assert.throws(()=>assertAuthoredState(c,original));}
});
test('Run intervention requires acceptance, journal and frozen authored identity',()=>{
  const before=run(state(1)),after=run(state(1));after.native.logical_objects[0].mass=2;after.mutation_count=after.paint_commands=after.intervention_count=1;after.pristine=false;after.last_edit={accepted:true,mode:'run'};
  assertObjectIntervention(before,after,1);
  for(const change of [x=>x.pristine=true,x=>x.tick++,x=>x.document.revision++,x=>x.current_hash=changed,x=>x.intervention_count=0]){
    const c=structuredClone(after);change(c);assert.throws(()=>assertObjectIntervention(before,c,1));
  }
});
test('Reset reconstructs exact body definitions and starts fresh history only in Edit',()=>{
  const initial=authoredState(state(16)),before=run(state(16)),after=state(16);after.generation=2;
  assertObjectReset(initial,before,after,{edit:true});
  const resetRun=run(after);resetRun.tick=resetRun.rapier_steps=0;assertObjectReset(initial,before,resetRun);
  for(const change of [x=>x.generation=1,x=>x.native.logical_objects[15].mass=2,x=>x.native.body_states[15][3]=1,x=>x.document.undo_depth=1]){
    const c=structuredClone(after);change(c);assert.throws(()=>assertObjectReset(initial,before,c,{edit:true}));
  }
});
test('zero-body native workload rejects a single phantom Rapier step/contact',()=>{
  const initial=authoredState(state()),after=run(state());assertPhysicalWorkload(initial,after,0);
  for(const delta of [{rapier_steps:1},{contacts_total:1},{displaced_total:1},{moves:0}])assert.throws(()=>assertPhysicalWorkload(initial,{...after,...delta},0));
});
test('capacity physics needs real motion, native impulses and genuine inter-body contacts',()=>{
  const initial=authoredState(state(16)),after=run(state(16));after.contacts_total=16;after.displaced_total=4;
  after.native.body_states.forEach(r=>r[1]=200);after.native.body_body_pairs=['object-1:object-9'];
  for(const id of after.native.body_ids)after.native.object_feedback[id]={samples:600,contacts:1,displaced:1,applications:1,accepted_impulse_x:.1,accepted_impulse_y:2};
  assertPhysicalWorkload(initial,after,16,{bodyContacts:true});
  for(const change of [x=>x.native.body_body_pairs=[],x=>x.native.body_body_pairs=['object-1:retired'],x=>x.native.body_states[15][1]=80,
    x=>delete x.native.object_feedback['object-2'],x=>x.native.object_feedback['object-16'].samples=599,
    x=>x.native.object_feedback['object-16'].contacts=0,x=>x.native.object_feedback['object-16'].applications=0,
    x=>Object.values(x.native.object_feedback).forEach(f=>{f.applications=0;f.accepted_impulse_x=f.accepted_impulse_y=0;})]){
    const c=structuredClone(after);change(c);assert.throws(()=>assertPhysicalWorkload(initial,c,16,{bodyContacts:true}));
  }
});
test('stale-release invariance needs trusted motion and both releases after refocus',()=>{
  const point={x:438,y:48},types=['pointermove','mousemove','pointerup','mouseup'];
  const events=types.map(type=>({type,...point,button:0,isTrusted:true,target:'CANVAS',focused:true}));
  const expected=types.map(type=>({action:'stale-object-release',type,...point,coordinate_tolerance:1e-4,
    ...(type.endsWith('up')?{button:0}:{}),start_index:0,end_index:events.length}));
  assertTrustedDelivery(events,expected);
  for(const missing of types)assert.throws(()=>assertTrustedDelivery(events.filter(e=>e.type!==missing),expected),/Missing DOM/);
  const earlier=events.concat(events.slice(0,2));
  assert.throws(()=>assertTrustedDelivery(earlier,expected.map(e=>({...e,start_index:4,end_index:6}))),/Missing DOM pointerup/);
  for(const change of [e=>e.isTrusted=false,e=>e.focused=false,e=>e.x+=1]) {
    const altered=structuredClone(events);change(altered[3]);assert.throws(()=>assertTrustedDelivery(altered,expected));
  }
});
