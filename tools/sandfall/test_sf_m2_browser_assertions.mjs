import test from 'node:test';
import assert from 'node:assert/strict';
import {assertEdit,assertEditMutation,assertPausedStable,assertHistoryLocked,assertRunIntervention,assertGallery600,assertTrustedDelivery,gestureAcknowledged} from './sf_m2_browser_assertions.mjs';
const a='a'.repeat(64), b='b'.repeat(64);
function state() {return {schema:'sandfall-host-v1',app_ready:true,ready:true,entry:'sandbox',scene_id:'blank',mode:'edit',paused:true,menu:false,fault:false,workers:1,tick:0,rapier_steps:0,rapier_active:false,rapier_available:true,generation:1,definition_hash:a,initial_hash:a,current_hash:a,body_poses:[],initial_body_poses:[],actor_count:0,paint_commands:0,mutation_count:0,render_rejections:0,pending_steps:0,native:{native_revision:1},simulation_interest:{origin:[0,0],size:[1024,1024]},document:{valid:true,cells_sha256:a,revision:0,undo_depth:0,redo_depth:0,history_bytes:0,locked:false,retired:false,can_undo:false,can_redo:false},input:{held_keys:[],pointer_buttons:0,gesture_active:false,pending_ui_gestures:0,clear_serial:0},camera:{origin:[0,0],zoom:1},pristine:true,intervention_count:0};}
function edited() {const s=state(); return {...s,current_hash:b,paint_commands:1,mutation_count:1,native:{native_revision:2},document:{...s.document,cells_sha256:b,revision:1,undo_depth:1,can_undo:true},last_edit:{accepted:true,mode:'edit',kind:'pencil_stroke',cells:11}};}
function run() {const s=state(); return {...s,mode:'run',tick:1,history_retired:true,document:{...s.document,locked:true,retired:true}};}
test('authored Edit accepts changed initial cells but demands actual document equality and zero ticks',()=>{assertEdit(edited());assert.throws(()=>assertEdit({...edited(),current_hash:a}),/authoritative authored/);assert.throws(()=>assertEdit({...edited(),tick:1}),/advanced in Edit/);assert.throws(()=>assertEdit({...edited(),rapier_steps:1}),/Rapier advanced/);});
test('one stroke demands exactly one revision and undo entry and exact changed-cell count',()=>{assertEditMutation(state(),edited(),'pencil_stroke',11);for(const field of ['revision','undo_depth']){const s=edited();s.document[field]=2;assert.throws(()=>assertEditMutation(state(),s,'pencil_stroke',11));}assert.throws(()=>assertEditMutation(state(),edited(),'pencil_stroke',10));});
test('observer cannot hide accepted mutations or keep stale native/document hashes',()=>{assert.throws(()=>assertEdit({...edited(),paint_commands:0}),/counts disagree/);assert.throws(()=>assertPausedStable(state(),edited()),/Material payload changed/);assert.throws(()=>assertPausedStable(state(),{...state(),native:{native_revision:2}}),/Live native revision/);const s=state();s.document.redo_depth=1;assert.throws(()=>assertPausedStable(state(),s),/document\/history/);});
test('Run is locked before tick one; either actual solver counter retires all prior history',()=>{assertHistoryLocked(run());assertHistoryLocked({...run(),tick:0,document:{...run().document,retired:false,undo_depth:1,history_bytes:14}});for(const counters of [{tick:1,rapier_steps:0},{tick:0,rapier_steps:1}]){const s={...run(),...counters,document:{...run().document,undo_depth:1}};assert.throws(()=>assertHistoryLocked(s));}assert.throws(()=>assertHistoryLocked({...run(),document:{...run().document,can_undo:true}}));});
test('Run intervention must be physically accepted, journalled and leave frozen document intact',()=>{const before=run(),after={...run(),current_hash:b,mutation_count:1,paint_commands:1,pristine:false,intervention_count:1,last_edit:{accepted:true,mode:'run',kind:'pencil_stroke'}};assertRunIntervention(before,after,'pencil_stroke');for(const delta of [{tick:2},{pristine:true},{intervention_count:0},{initial_hash:b},{document:{...after.document,cells_sha256:b}}])assert.throws(()=>assertRunIntervention(before,{...after,...delta},'pencil_stroke'));});
test('Gallery still requires 600 real coupled ticks and positive contact/displacement',()=>{const s={...run(),entry:'gallery',scene_id:'physics_pit',rapier_active:true,tick:600,rapier_steps:600,body_poses:[[],[],[]],moves:1,contacts_total:1,displaced_total:1};assertGallery600(s);for(const delta of [{tick:599},{rapier_steps:599},{moves:0},{contacts_total:0},{displaced_total:0},{actor_count:1}])assert.throws(()=>assertGallery600({...s,...delta}));});
test('genuine pointer evidence rejects synthetic events and scaled/incorrect coordinates',()=>{const expected=[{action:'pencil',type:'pointerdown',button:0,x:200,y:150,start_index:0,end_index:1}],event={type:'pointerdown',button:0,x:200,y:150,target:'CANVAS',focused:true,isTrusted:true};assertTrustedDelivery([event],expected);for(const delta of [{x:100},{y:75},{isTrusted:false},{target:'BODY'},{focused:false}])assert.throws(()=>assertTrustedDelivery([{...event,...delta}],expected));});

test('material targeting requires actual legacy mouse and pointer coordinates, not one-pixel tolerance',()=>{
  for(const type of ['mousedown','mouseup','pointerdown','pointerup']) {
    const expected=[{action:'exact cell',type,button:0,x:224,y:85,coordinate_tolerance:1e-4,start_index:0,end_index:1}];
    const event={type,button:0,x:224,y:85,target:'CANVAS',focused:true,isTrusted:true};
    assertTrustedDelivery([event],expected);
    assert.throws(()=>assertTrustedDelivery([{...event,x:223.9}],expected),/coordinate/);
    assert.throws(()=>assertTrustedDelivery([{...event,y:84}],expected),/coordinate/);
    assert.throws(()=>assertTrustedDelivery([{...event,isTrusted:false}],expected),/Untrusted/);
  }
});

test('only scoped text field keys may reach the verified Godot IME sibling',()=>{
  const expected=[{action:'temperature',type:'keydown',code:'Digit7',allow_godot_ime:true,start_index:0,end_index:1}];
  const event={type:'keydown',code:'Digit7',isTrusted:true,focused:true,target:'DIV',targetClass:'ime',targetContentEditable:true,targetIsActive:true,targetSharesCanvasParent:true};
  assertTrustedDelivery([event],expected);
  assertTrustedDelivery([{...event,target:'CANVAS'}],expected);
  for (const delta of [{target:'BODY'},{targetClass:'other'},{targetContentEditable:false},{targetIsActive:false},{targetSharesCanvasParent:false},{isTrusted:false},{focused:false}])
    assert.throws(()=>assertTrustedDelivery([{...event,...delta}],expected));
  assert.throws(()=>assertTrustedDelivery([event],[{...expected[0],allow_godot_ime:false}]));
  assert.throws(()=>assertTrustedDelivery([{...event,type:'pointerdown'}],[{...expected[0],type:'pointerdown'}]),/keyboard-only/);
});
test('motion acknowledgement rejects a stale preview even after unrelated process frames',()=>{
  const from=[30,30],to=[40,30];
  const old={frame:1214,editor:{gesture_active:true,preview_first:from,preview_last:from}};
  assert.equal(gestureAcknowledged(old,from,to,1200),false);
  const arrived={...old,editor:{...old.editor,preview_last:to}};
  assert.equal(gestureAcknowledged(arrived,from,to,1200),true);
  assert.equal(gestureAcknowledged({...arrived,frame:1200},from,to,1200),false);
  assert.equal(gestureAcknowledged({...arrived,editor:{...arrived.editor,gesture_active:false}},from,to,1200),false);
  assert.equal(gestureAcknowledged({...arrived,editor:{...arrived.editor,preview_first:[29,30]}},from,to,1200),false);
});
