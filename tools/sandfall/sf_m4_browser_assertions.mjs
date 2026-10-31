// SF-M4 evidence oracles: copied observations and independently decoded ZIPs.
// These helpers have no application handles and cannot mutate the simulation.
import assert from 'node:assert/strict';
import {assertEdit,samePhysicalValue} from './sf_m2_browser_assertions.mjs';
import {assertRegistry,objects,ids} from './sf_m3_browser_assertions.mjs';

export function assertRejectedImport(before,after) {
  for(const key of ['generation','mode','paused','tick','rapier_steps','current_hash','definition_hash',
    'initial_hash','pristine','intervention_count','mutation_count'])
    assert.deepEqual(after[key],before[key],`Refused archive changed ${key}`);
  assert.deepEqual(after.document,before.document,'Refused archive replaced or edited the authored document');
  assert.deepEqual(objects(after),objects(before),'Refused archive mutated the logical graph');
  assert.deepEqual(ids(after),ids(before),'Refused archive retired or reused a stable ID');
  samePhysicalValue(after.native.body_states,before.native.body_states,'Refused archive live Rapier state');
  samePhysicalValue(after.native.body_sizes,before.native.body_sizes,'Refused archive body geometry');
  assert.deepEqual(after.native.slot_mapping,before.native.slot_mapping,'Refused archive replaced sampling ownership');
}

export function assertProjectInstalled(before,after,initial) {
  assertEdit(after);assertRegistry(after,initial.ids.length);
  assert.ok(after.generation>before.generation,'Import did not retire the old generation');
  assert.equal(after.tick,0);assert.equal(after.rapier_steps,0);
  assert.equal(after.document.undo_depth,0);assert.equal(after.document.redo_depth,0);
  assert.equal(after.document.history_bytes,0,'Archive imported history');
  assert.equal(after.intervention_count,0,'Archive imported a run journal');
  assert.equal(after.pristine,true);
  assert.equal(after.current_hash,initial.cells,'Archive lost exact initial material/thermal tuples');
  assert.deepEqual(objects(after),initial.definitions,'Archive changed stable IDs, metadata or physical parameters');
  assert.deepEqual(ids(after),initial.ids);
  samePhysicalValue(after.native.body_states,initial.states,'Archive initial Rapier poses and velocities');
  samePhysicalValue(after.native.body_sizes,initial.sizes,'Archive initial geometry');
}

export function assertSameLogicalProject(before,after) {
  for(const key of ['scene','objects','style','annotations','world_sha256','world_bytes'])
    assert.deepEqual(after[key],before[key],`Initial project round-trip changed ${key}`);
  assert.deepEqual(after.manifest.project,before.manifest.project,'Project identity/title changed');
  assert.deepEqual(after.manifest.source,before.manifest.source,'Creation source identity changed');
  assert.deepEqual(after.logical_files,before.logical_files,'Canonical logical file identity changed');
}

export function assertFrozenSave(initial,runSave) {
  assertSameLogicalProject(initial,runSave);
  assert.equal(runSave.world_bytes,5242880,'Save did not preserve exact five-byte authored tuples');
}

export function assertProjectSource(identity,verification) {
  assert.ok(identity&&typeof identity==='object','Runtime project source identity is absent');
  assert.deepEqual(identity,verification.project_source_identity,
    'The PCK identity differs from the exact-head source/native/Rapier manifest');
}

export function assertBrowserFileDelivery(events,transfer) {
  const {start_index:start,end_index:end,name,bytes}=transfer;
  assert.ok(Number.isSafeInteger(start)&&Number.isSafeInteger(end)&&start>=0&&end>start&&end<=events.length,
    'File delivery has no bounded current DOM event range');
  assert.ok(typeof name==='string'&&name.length>0&&Number.isSafeInteger(bytes)&&bytes>0);
  const changes=events.slice(start,end).filter(e=>e.type==='change'&&e.targetId==='sandfall-project-file');
  assert.equal(changes.length,1,'The current file transfer must deliver exactly one native input change');
  assert.equal(changes[0].isTrusted,true,'Current file change was not trusted browser input');
  assert.deepEqual(changes[0].files,[{name,size:bytes}],'Current file change delivered another file');
  return structuredClone(changes[0]);
}

export function assertPromotionBoundary(before,after) {
  assertEdit(after);
  assert.ok(after.generation>before.generation,'Promotion did not construct a new authoring generation');
  assert.equal(after.tick,0);assert.equal(after.rapier_steps,0);
  assert.equal(after.document.undo_depth,0);assert.equal(after.document.redo_depth,0);
  assert.equal(after.document.history_bytes,0);assert.equal(after.intervention_count,0);
  assert.equal(after.pristine,true);
  assertRegistry(after,objects(after).length);
}

export function unexpectedConsoleErrors(events,witnesses) {
  const admitted=new Set();
  for(const witness of witnesses) {
    assert.equal(witness.case,'external_crc');assert.match(witness.fixture_sha256,/^[0-9a-f]{64}$/);
    assert.equal(witness.refusal,'zip_decompression_size_or_crc');assert.equal(witness.old_world_preserved,true);
    assert.ok(Number.isSafeInteger(witness.start_index)&&Number.isSafeInteger(witness.end_index)&&
      witness.start_index>=0&&witness.end_index>witness.start_index&&witness.end_index<=events.length);
    const errors=events.slice(witness.start_index,witness.end_index)
      .map((value,index)=>({...value,index:witness.start_index+index})).filter(x=>['error','exception'].includes(x.type));
    assert.ok(errors.length>=1&&errors.length<=16,'Pinned CRC diagnostic count is outside its bounded envelope');
    let failures=0;
    for(const error of errors) {
      assert.equal(error.type,'error','A JS exception cannot be classified as a malformed ZIP diagnostic');
      for(const raw of error.text.split('\n')) {
        const line=raw.replace(/\x1b\[[0-9;]*m/g,'').trim();
        if(!line)continue;
        if(line==='ERROR: Decompression failed.'){failures++;continue;}
        const allowed=line==='WARNING: incorrect data check'||line==='GDScript backtrace (most recent call first):'||
          line==='at: func_PackedByteArray_decompress_dynamic (core/variant/variant_call.cpp:844)'||
          line==='at: decompress_dynamic (core/io/compression.cpp:343)'||
          /^\[\d+\] (unpack|decode_bytes|_on_project_selected|_receive) \(res:\/\/scripts\/sandfall\/(archive_zip|archive_codec|application|browser_file_bridge)\.gd:\d+\)$/.test(line);
        assert.ok(allowed,'Unexpected error inside the CRC refusal boundary: '+line);
      }
      admitted.add(error.index);
    }
    assert.equal(failures,1,'Expected exactly one pinned Decompression failed diagnostic for the CRC fixture');
  }
  return events.filter((event,index)=>['error','exception'].includes(event.type)&&!admitted.has(index));
}

