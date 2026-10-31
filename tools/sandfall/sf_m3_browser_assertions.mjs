// SF-M3 acceptance oracles consume copied observations only. These helpers do
// not run physics; their negatives test evidence rejection, not the application.
import assert from 'node:assert/strict';
import {assertOrdinaryState,assertEdit,assertHistoryLocked,samePhysicalValue,
  assertPausedStable} from './sf_m2_browser_assertions.mjs';
import {mapGodotRect} from './sf_m0_geometry.mjs';

// A newly visible Godot Container can publish a Control rectangle before its
// deferred layout has run. Repeated reads of that same application frame are
// not evidence that the rectangle is ready for genuine browser input.
export function sampleControlLayout(state,metrics,layout,name) {
  if(!state?.app_ready||!Number.isSafeInteger(state.frame)||state.frame<0||
    !Number.isSafeInteger(state.generation)||state.generation<0||
    typeof state.entry!=='string'||typeof state.mode!=='string'||typeof state.menu!=='boolean'||
    !Array.isArray(state.viewport)||state.viewport.length!==2||
    state.viewport[0]!==layout?.width||state.viewport[1]!==layout?.height) return null;
  const rect=state.buttons?.[name]??state.editor_controls?.[name];
  if(!rect) return null;
  try {
    const mapped=mapGodotRect(rect,metrics,layout);
    if(metrics.canvasStyle?.transform&&metrics.canvasStyle.transform!=='none') return null;
    const geometry={name,generation:state.generation,entry:state.entry,mode:state.mode,menu:state.menu,
      tool_group:state.editor?.tool_group??null,tools_visible:state.editor?.tools_visible??null,
      inspector_tab:state.editor?.object_inspector?.tab??null,rect,layout,logical_viewport:state.viewport,
      canvas:metrics.canvas,backing:metrics.backing,viewport:metrics.viewport,
      devicePixelRatio:metrics.devicePixelRatio,visualViewport:metrics.visualViewport??null,
      canvasStyle:metrics.canvasStyle??null};
    return structuredClone({frame:state.frame,geometry,mapped});
  } catch { return null; }
}
export function sameControlLayout(before,after) {
  return Boolean(before?.geometry&&after?.geometry&&Array.isArray(before.geometry.rect)&&
    Array.isArray(after.geometry.rect)&&JSON.stringify(before.geometry)===JSON.stringify(after.geometry));
}
export function controlLayoutSettled(before,after) {
  return Boolean(before&&after&&Number.isSafeInteger(before.frame)&&Number.isSafeInteger(after.frame)&&
    before.frame>=0&&after.frame>=before.frame+2&&sameControlLayout(before,after));
}

const count=(n,label)=>assert.ok(Number.isSafeInteger(n)&&n>=0,`${label} is not an actual nonnegative counter`);
const finite=(n,label)=>assert.ok(typeof n==='number'&&Number.isFinite(n),`${label} is not finite`);
const pair=(a,label)=>{assert.ok(Array.isArray(a)&&a.length===2,`${label} must be a numeric pair`);a.forEach(n=>finite(n,label));};
export const objects=s=>s.object_definitions ?? s.native?.logical_objects;
export const ids=s=>s.native?.body_ids;
export function objectState(s) {
  return structuredClone({ids:ids(s),definitions:objects(s),states:s.native?.body_states,
    sizes:s.native?.body_sizes,slot_mapping:s.native?.slot_mapping});
}
export function assertRegistry(s,expectedCount) {
  assertOrdinaryState(s);
  assert.ok(Number.isSafeInteger(expectedCount)&&expectedCount>=0&&expectedCount<=16,'Invalid expected capacity');
  const definitions=objects(s),projectIds=ids(s),states=s.native?.body_states,sizes=s.native?.body_sizes;
  for(const [name,value] of Object.entries({definitions,projectIds,states,sizes})) {
    assert.ok(Array.isArray(value),`${name} missing from live owner`);
    assert.equal(value.length,expectedCount,`${name} has the wrong body count`);
  }
  assert.equal(new Set(projectIds).size,expectedCount,'Stable IDs are duplicated');
  for(let i=0;i<expectedCount;i++) {
    const d=definitions[i];
    assert.equal(typeof projectIds[i],'string','Stable ID must be a string');
    assert.ok(projectIds[i].length>0,'Empty stable ID');
    assert.equal(d.id,projectIds[i],'Logical definition was mapped into another sampling slot');
    assert.equal(d.schema_version,1,'Unsupported logical object schema');assert.equal(d.shape,'box','Unsupported physical geometry');
    assert.ok(Number.isSafeInteger(d.creation_order)&&d.creation_order>0&&(i===0||d.creation_order>definitions[i-1].creation_order),'Creation order is not stable and strictly increasing');
    assert.equal(typeof d.name,'string','Logical object name is missing');
    for(const key of ['fixed','frozen','passive_subject'])assert.equal(typeof d[key],'boolean',`Missing typed ${key} metadata`);
    pair(d.position,'position');pair(d.size,'size');pair(d.linear_velocity,'linear velocity');
    assert.ok(d.size.every(n=>n>0),'Object has invalid dimensions');
    for(const key of ['rotation','mass','friction','restitution','linear_damp','angular_damp','angular_velocity','gravity_scale']) finite(d[key],key);
    assert.ok(d.mass>0,'Object has nonpositive mass');
    assert.ok(Array.isArray(states[i])&&states[i].length===7,'Missing actual Rapier state');
    states[i].slice(0,6).forEach(n=>finite(n,'actual Rapier state'));
    assert.equal(typeof states[i][6],'boolean','Missing sleeping state');
    pair(sizes[i],'actual body size');samePhysicalValue(sizes[i],d.size,'actual body geometry');
  }
  const map=s.native?.slot_mapping;
  assert.ok(map&&typeof map==='object','Sampling mapping receipt is absent');
  count(map.epoch,'mapping epoch');count(map.sample_serial,'sampling serial');
  assert.deepEqual(map.project_ids,projectIds,'Stable identity to sampling-slot map diverged');
  assert.equal(map.slots,expectedCount,'Sampling slot count does not match the dense 1..N mapping');
  assert.equal(s.rapier_active,expectedCount>0,'Bridge activity does not match the live graph');
  assert.equal(s.native.bridge_active,s.rapier_active,'Native/session bridge activity differs');
  assert.equal(s.native.rapier_available,s.rapier_available,'Native/session Rapier availability differs');
  assert.deepEqual(s.native.logical_objects,definitions,'Native logical graph disagrees with project definitions');
  assert.deepEqual(s.native.object_definitions,definitions,'Native owner exposes another logical object graph');
  const rendering=s.rendering,probe=s.native.rapier_probe;
  assert.ok(rendering&&typeof rendering==='object','Actual renderer body bindings are absent');
  assert.equal(rendering.body_capacity,16,'Renderer does not expose the admitted capacity');
  assert.equal(rendering.body_count,expectedCount,'Rendered body count disagrees with actual ownership');
  assert.deepEqual(rendering.body_ids,projectIds,'Renderer mapped another graph into its shader slots');
  assert.ok(probe&&typeof probe==='object'&&!Array.isArray(probe),'Rapier capability observation is absent');
  assert.equal(typeof s.native.rapier_probe_deferred,'boolean','Missing explicit Rapier probe ownership');
  if(s.native.rapier_probe_deferred) {
    assert.equal(expectedCount,0,'A nonempty graph deferred its required Rapier capability probe');
    assert.equal(s.rapier_available,false,'Deferred probe falsely claims Rapier availability');
    assert.deepEqual(probe,{},'Deferred zero-body graph contains executed probe results');
    assert.equal(s.rapier_steps,0,'Deferred zero-body graph already performed Rapier steps');
    assert.deepEqual(s.initial_body_poses,[],'Deferred zero-body graph has an authored physical body');
    assert.deepEqual(s.native.initial_body_states,[],'Deferred zero-body graph has initial native body state');
    assert.equal(map.epoch,0,'Deferred zero-body graph already owns a Rapier mapping epoch');
    assert.equal(map.sample_serial,0,'Deferred zero-body graph already sampled Rapier');
  } else {
    assert.equal(s.rapier_available,true,'Actual positive Rapier capability was not observed');
    assert.equal(probe.ok,true,'The real Rapier capability probe did not pass');
    assert.ok(typeof probe.reason==='string'&&probe.reason.length>0,'Positive capability lacks its probe receipt');
    finite(probe.y,'actual Rapier probe displacement');
  }
  return definitions;
}
export function assertObjectEdit(before,after,expectedCount) {
  assertEdit(after);assertRegistry(after,expectedCount);
  assert.equal(after.generation,before.generation,'Object Edit changed session generation');
  assert.equal(after.document.revision,before.document.revision+1,'One Edit must commit one revision');
  assert.equal(after.document.undo_depth,before.document.undo_depth+1,'Object drag/property Edit is not one transaction');
  assert.equal(after.document.redo_depth,0,'Accepted Edit did not retire redo');
  assert.equal(after.mutation_count,before.mutation_count+1,'Object Edit was not accepted exactly once');
  assert.equal(after.last_edit?.accepted,true,'Object Edit lacks an accepted receipt');
  assert.equal(after.last_edit?.mode,'edit');
  assert.equal(after.current_hash,before.current_hash,'Object editing painted native material cells');
  assert.ok(after.document.history_bytes>0&&after.document.history_bytes<=64*1024*1024,'Object history accounting exceeds its logical payload limit');
  assert.ok(after.document.undo_depth<=512,'Object history entry limit exceeded');
}
export function assertObjectRefusal(before,after) {
  assertPausedStable(before,after);
  assert.deepEqual(objectState(after),objectState(before),'Refusal changed live graph, ownership or sampling');
  assert.equal(after.pristine,before.pristine,'Refusal changed pristine/Modified');
  assert.equal(after.intervention_count,before.intervention_count,'Refusal added a journal entry');
}
export function authoredState(s) {
  return structuredClone({cells:s.current_hash,definitions:objects(s),ids:ids(s),
    states:s.native.body_states,sizes:s.native.body_sizes});
}
export function assertAuthoredState(actual,expected) {
  assertEdit(actual);assertRegistry(actual,expected.ids.length);
  assert.equal(actual.current_hash,expected.cells,'Undo/redo lost exact authored material tuples');
  assert.deepEqual(objects(actual),expected.definitions,'Undo/redo lost exact logical object properties/metadata');
  assert.deepEqual(ids(actual),expected.ids,'Undo/redo changed stable IDs or creation order');
  samePhysicalValue(actual.native.body_states,expected.states,'Undo/redo initial Rapier state');
  samePhysicalValue(actual.native.body_sizes,expected.sizes,'Undo/redo geometry');
}
export function assertObjectIntervention(before,after,expectedCount) {
  assertHistoryLocked(after);assertRegistry(after,expectedCount);
  assert.equal(before.paused,true);assert.equal(after.paused,true);
  assert.equal(after.tick,before.tick);assert.equal(after.rapier_steps,before.rapier_steps);
  assert.equal(after.generation,before.generation);
  assert.equal(after.mutation_count,before.mutation_count+1,'Physical intervention was not accepted exactly once');
  assert.equal(after.intervention_count,before.intervention_count+1,'Physical intervention has no one-entry journal receipt');
  assert.equal(after.pristine,false,'Physical intervention did not mark Modified');
  assert.deepEqual(after.document,before.document,'Live object intervention changed frozen authored state/history');
  assert.equal(after.definition_hash,before.definition_hash,'Intervention changed frozen initial definition');
  assert.equal(after.initial_hash,before.initial_hash,'Intervention changed frozen material identity');
  assert.equal(after.current_hash,before.current_hash,'Object intervention painted authoritative material cells');
  assert.equal(after.last_edit?.accepted,true);assert.equal(after.last_edit?.mode,'run');
}
export function assertObjectReset(initial,before,after,{edit=false}={}) {
  assertRegistry(after,initial.ids.length);
  assert.equal(after.mode,edit?'edit':'run');assert.equal(after.paused,true);
  assert.ok(after.generation>before.generation,'Reset did not retire the old generation');
  assert.equal(after.tick,0);assert.equal(after.rapier_steps,0);
  assert.deepEqual(ids(after),initial.ids,'Reset changed stable IDs/order');
  assert.deepEqual(objects(after),initial.definitions,'Reset changed logical initial definitions');
  samePhysicalValue(after.native.body_states,initial.states,'Reset initial state');
  samePhysicalValue(after.native.body_sizes,initial.sizes,'Reset initial size');
  assert.equal(after.current_hash,initial.cells,'Reset failed exact native/thermal reconstruction');
  assert.equal(after.intervention_count,0);assert.equal(after.pristine,true);
  if(edit){assertEdit(after);assert.equal(after.document.undo_depth,0);assert.equal(after.document.redo_depth,0);assert.equal(after.document.history_bytes,0);}
  else assertHistoryLocked(after);
}
export function assertPhysicalWorkload(initial,after,expectedCount,{minimumTicks=600,bodyContacts=false}={}) {
  assertRegistry(after,expectedCount);assertHistoryLocked(after);
  assert.ok(after.tick>=minimumTicks,'Actual native workload did not reach the registered duration');
  assert.equal(after.rapier_steps,expectedCount?after.tick:0,'Actual Rapier/native counters violate active-bridge sequencing');
  assert.deepEqual(ids(after),initial.ids,'Physics changed stable IDs/order');
  assert.deepEqual(objects(after),initial.definitions,'Physics modified logical initial definitions');
  assert.ok(after.moves>0,'Native material simulation did not actually move');
  if(expectedCount===0) {
    assert.equal(after.contacts_total,0,'Zero-body scene has phantom native/body contacts');
    assert.equal(after.displaced_total,0,'Zero-body scene has phantom body displacement');
    assert.deepEqual(after.native.body_body_pairs,[],'Zero-body scene has phantom rigid contacts');
    return;
  }
  assert.ok(after.contacts_total>0,'No actual native-material/body contact occurred');
  assert.ok(after.displaced_total>0,'No actual native material was displaced');
  const feedback=after.native.object_feedback;
  assert.ok(feedback&&typeof feedback==='object','Missing stable-ID native feedback receipt');
  assert.deepEqual(Object.keys(feedback).sort(),initial.ids.toSorted(),'Feedback ownership does not cover exactly the live IDs');
  let applied=0,impulse=0;
  for(let i=0;i<expectedCount;i++) {
    const row=after.native.body_states[i],d=initial.definitions[i],f=feedback[initial.ids[i]];
    assert.ok(Math.hypot(row[0]-initial.states[i][0],row[1]-initial.states[i][1])>2,'A registered body never physically moved');
    assert.ok(row[0]>=15&&row[0]<=465&&row[1]>=15&&row[1]<=225+d.size[1], 'Body escaped the authored hard-terrain enclosure');
    for(const k of ['samples','contacts','displaced','applications'])count(f[k],`feedback ${k}`);
    assert.equal(f.samples,after.tick,'An admitted body was omitted from actual native sampling');
    if(expectedCount===16) {
      assert.ok(f.contacts>0,`Capacity body ${initial.ids[i]} never contacted native material`);
      assert.ok(f.applications>0,`Capacity body ${initial.ids[i]} never received native-material feedback`);
    }
    for(const k of ['accepted_impulse_x','accepted_impulse_y'])finite(f[k],`feedback ${k}`);
    applied+=f.applications;impulse+=Math.abs(f.accepted_impulse_x)+Math.abs(f.accepted_impulse_y);
  }
  assert.ok(applied>0&&impulse>0,'No real native-material feedback reached Rapier');
  if(bodyContacts) {
    assert.ok(Array.isArray(after.native.body_body_pairs)&&after.native.body_body_pairs.length>0,'No actual Rapier body/body contact was reported');
    for(const record of after.native.body_body_pairs) {
      const pair=typeof record==='string'?record.split(':'):record;
      assert.ok(Array.isArray(pair)&&pair.length===2&&pair[0]!==pair[1],'Malformed or self body/body contact');
      assert.ok(pair.every(id=>initial.ids.includes(id)),'Contact was attributed to a retired/unknown stable ID');
    }
  }
}
