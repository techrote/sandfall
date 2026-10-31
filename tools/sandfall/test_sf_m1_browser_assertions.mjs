import test from "node:test";
import assert from "node:assert/strict";
import {
  assertOrdinaryState, assertEdit, assertPausedStable, assertStep, assertReset,
  assertGallery600, assertTrustedDelivery, assertInputClear,
} from "./sf_m1_browser_assertions.mjs";

const hash = "a".repeat(64);
const evolvedHash = "b".repeat(64);
function state(overrides = {}) {
  return {schema:"sandfall-host-v1",app_ready:true,ready:true,fault:false,
    entry:"sandbox",mode:"run",paused:true,menu:false,workers:1,tick:12,
    rapier_steps:12,rapier_active:true,rapier_available:true,generation:3,
    scene_id:"physics_pit",definition_hash:hash,initial_hash:hash,current_hash:evolvedHash,
    body_poses:[[1,2,0,0,0,0,false],[3,4,0,0,0,0,false],[5,6,0,0,0,0,false]],
    initial_body_poses:[[1,1,0,0,0,0,false],[3,3,0,0,0,0,false],[5,5,0,0,0,0,false]],
    actor_count:0,paint_commands:0,render_rejections:0,pending_steps:0,
    native:{native_revision:41},
    input:{held_keys:[],pointer_buttons:0,gesture_active:false,pending_ui_gestures:0,clear_serial:2},
    camera:{origin:[0,0],zoom:1},simulation_interest:{origin:[0,0],size:[480,270]},
    moves:10,contacts_total:3,displaced_total:5,...overrides};
}

test("exact Step accepts active and inactive bridges with their distinct counts", () => {
  const active = state();
  assertStep(active,state({tick:13,rapier_steps:13}),true);
  const inactive = state({rapier_active:false,rapier_steps:0,body_poses:[],initial_body_poses:[]});
  assertStep(inactive,{...inactive,tick:13},false);
});

test("Step rejects additional native work and missing or forbidden Rapier work", () => {
  assert.throws(()=>assertStep(state(),state({tick:14,rapier_steps:13}),true),/exactly one native/);
  assert.throws(()=>assertStep(state(),state({tick:13}),true),/one Rapier step/);
  const inactive = state({rapier_active:false,rapier_steps:0});
  assert.throws(()=>assertStep(inactive,{...inactive,tick:13,rapier_steps:1},false),/one Rapier step/);
  assert.throws(()=>assertStep(state(),state({tick:13,rapier_steps:13,paused:false}),true),/remain paused/);
});

test("paused camera may move presentation but cannot mutate cells, bodies or interest", () => {
  const before = state();
  assertPausedStable(before,state({camera:{origin:[20,0],zoom:1.2}}));
  assert.throws(()=>assertPausedStable(before,state({current_hash:hash})),/Material payload changed/);
  assert.throws(()=>assertPausedStable(before,state({native:{native_revision:42}})),/Live native revision changed/);
  assert.throws(()=>assertPausedStable(before,state({simulation_interest:{origin:[20,0],size:[480,270]}})),/simulation interest/);
  const changed = structuredClone(before);
  changed.body_poses[0][0] += 1;
  assert.throws(()=>assertPausedStable(before,changed),/paused body poses/);
  assert.throws(()=>assertPausedStable(before,state({camera:{origin:[20,0],zoom:1.2}}),{camera:true}),/camera without a fresh gesture/);
});

test("reset reconstructs source initial materials and body poses in a new generation", () => {
  const initial = state({tick:0,rapier_steps:0,current_hash:hash});
  initial.body_poses = structuredClone(initial.initial_body_poses);
  const after = {...structuredClone(initial),generation:4};
  assertReset(initial,state(),after);
  assertReset(initial,state(),{...after,mode:"edit"},{mode:"edit"});
  assert.throws(()=>assertReset(initial,state(),{...after,current_hash:evolvedHash}),/retained evolved/);
  assert.throws(()=>assertReset(initial,state(),{...after,generation:3}),/retired session/);
  assert.throws(()=>assertReset(initial,state(),{...after,pending_steps:1}),/pending Step/);
});

test("Edit refuses solver advancement and actor authority is always a failure", () => {
  const edit = state({mode:"edit",tick:0,rapier_steps:0,current_hash:hash});
  edit.body_poses = structuredClone(edit.initial_body_poses);
  assertEdit(edit);
  assert.throws(()=>assertEdit({...edit,tick:1}),/advanced in Edit/);
  assert.throws(()=>assertEdit({...edit,rapier_steps:1}),/Rapier advanced in Edit/);
  assert.throws(()=>assertOrdinaryState(state({actor_count:1})),/actor\/controller/);
  assert.throws(()=>assertOrdinaryState(state({native:{}})),/live native revision/);
  assert.throws(()=>assertOrdinaryState(state({rapier_test:{success:true}})),/Special Rapier/);
});

test("600 coupled run cannot pass with unequal counters or absent physical effects", () => {
  const good = state({entry:"gallery",tick:600,rapier_steps:600});
  assertGallery600(good);
  assert.throws(()=>assertGallery600({...good,rapier_steps:599}),/counters diverged/);
  assert.throws(()=>assertGallery600({...good,contacts_total:0}),/positive.*contact/);
  assert.throws(()=>assertGallery600({...good,displaced_total:0}),/positive.*displacement/);
  assert.throws(()=>assertGallery600({...good,moves:0}),/material movement/);
});

test("focus, gesture and queued-step retirement are individually required", () => {
  assertInputClear(state());
  for (const input of [{held_keys:["KeyP"]},{pointer_buttons:4},{gesture_active:true},{pending_ui_gestures:1}]) {
    assert.throws(()=>assertInputClear(state({input:{...state().input,...input}})),/survived/);
  }
  assert.throws(()=>assertInputClear(state({pending_steps:1})),/pending Step/);
});

test("trusted input oracle rejects coordinate scaling drift and missing keyboard delivery", () => {
  const pointer = {type:"pointerdown",button:0,isTrusted:true,target:"CANVAS",focused:true,x:123,y:210};
  const key = {type:"keydown",code:"KeyP",repeat:false,isTrusted:true,target:"CANVAS",focused:true};
  const expected = [
    {action:"Continue",type:"pointerdown",button:0,start_index:0,end_index:1,x:123,y:210},
    {action:"Pause",type:"keydown",code:"KeyP",repeat:false,start_index:1,end_index:2},
  ];
  assertTrustedDelivery([pointer,key],expected);
  assert.throws(()=>assertTrustedDelivery([{...pointer,x:61.5,y:105},key],expected),/CSS coordinate/);
  assert.throws(()=>assertTrustedDelivery([{...pointer,isTrusted:false},key],expected),/Untrusted/);
  assert.throws(()=>assertTrustedDelivery([pointer,{...key,focused:false}],expected),/unfocused/);
  assert.throws(()=>assertTrustedDelivery([pointer],expected),/Missing DOM keydown/);
  assert.throws(()=>assertTrustedDelivery([pointer,{...key,repeat:true}],expected),/repeat flag/);
});
