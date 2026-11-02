// Read-only M5-A02/B01 chemistry oracles. Synthetic unit fixtures qualify
// rejection behavior only; browser receipts must come from the real app.
import assert from 'node:assert/strict';
import {assertEdit,assertStep,assertHistoryLocked} from './sf_m2_browser_assertions.mjs';

export const CELLS={steam:[200,110],hot:[260,110],fallen:[260,111],sentinel:[220,120]};
export const TUPLES={empty:{id:0,state_a:0,state_b:0,temperature:200},
  wall:{id:1,state_a:0,state_b:0,temperature:200},
  steam:{id:22,state_a:180,state_b:0,temperature:1500},
  steamFirst:{id:22,state_a:179,state_b:0,temperature:1500},
  water:{id:3,state_a:255,state_b:0,temperature:1500},
  hot:{id:2,state_a:0,state_b:0,temperature:777}};

export function inspectedSample(state,cell,expected) {
  const actual=state.editor?.inspected;
  assert.ok(actual,'Real native picker observation is missing');
  assert.equal(actual.x,cell[0],'Picker observed a different native x');
  assert.equal(actual.y,cell[1],'Picker observed a different native y');
  const tuple={};
  for(const key of ['id','state_a','state_b','temperature']) {
    assert.ok(Number.isSafeInteger(actual[key]),'Picker tuple is non-integer: '+key);
    tuple[key]=actual[key];
  }
  assert.deepEqual(tuple,expected,'Full native material/state/temperature tuple differs');
  return {cell:[...cell],tuple,generation:state.generation,tick:state.tick,
    native_revision:state.native.native_revision,current_hash:state.current_hash,frame:state.frame};
}

export function assertSampleEpoch(sample,state,cell,tuple) {
  assert.ok(sample,'Missing executed picker sample');
  assert.deepEqual(sample.cell,cell,'Picker sample belongs to another cell');
  assert.deepEqual(sample.tuple,tuple,'Picker sample has a different complete tuple');
  for(const field of ['generation','tick','current_hash'])
    assert.equal(sample[field],state[field],'Picker sample is stale: '+field);
  assert.equal(sample.native_revision,state.native.native_revision,'Picker sample is stale: native revision');
  assert.ok(Number.isSafeInteger(sample.frame)&&sample.frame<=state.frame,'Picker sample frame is invalid');
}

export function assertExactHistory(before,after,direction,expectedHash) {
  assertEdit(before);assertEdit(after);
  assert.ok(['undo','redo'].includes(direction));
  assert.equal(after.generation,before.generation);
  assert.equal(after.current_hash,expectedHash,'Undo/Redo did not restore exact authoritative bytes');
  assert.equal(after.document.cells_sha256,expectedHash);
  assert.equal(after.document.revision,before.document.revision+1,'History command committed more than once');
  const sign=direction==='undo'?-1:1;
  assert.equal(after.document.undo_depth,before.document.undo_depth+sign);
  assert.equal(after.document.redo_depth,before.document.redo_depth-sign);
  assert.deepEqual(after.body_poses,before.body_poses,'History command changed actual physical objects');
}

export function assertChemicalFirstStep(before,after,samples) {
  assertStep(before,after,false);
  assert.equal(before.tick,0,'Chemical control must start at the real reset tick zero');
  assertHistoryLocked(after);
  assert.equal(after.initial_hash,before.initial_hash);
  assert.equal(after.document.cells_sha256,before.initial_hash);
  assert.equal(after.intervention_count,0,'Observed reaction came from an intervention');
  assert.notEqual(after.current_hash,before.current_hash,'Actual first tick did not change cells');
  assertSampleEpoch(samples.steam,after,CELLS.steam,TUPLES.steamFirst);
  assertSampleEpoch(samples.hotSource,after,CELLS.hot,TUPLES.empty);
  assertSampleEpoch(samples.hotDestination,after,CELLS.fallen,TUPLES.hot);
}

export function assertChemicalConversion(authored,after,sample) {
  assertHistoryLocked(after);
  assert.equal(after.paused,true);
  assert.ok(Number.isSafeInteger(after.tick)&&after.tick>=180,'Steam conversion lacks 180 actual lifetime updates');
  assert.equal(after.rapier_steps,0,'Zero-body chemistry acquired a Rapier owner');
  assert.equal(after.initial_hash,authored.current_hash);
  assert.equal(after.document.cells_sha256,authored.current_hash);
  assert.equal(after.intervention_count,0,'Conversion used an intervention');
  assertSampleEpoch(sample,after,CELLS.steam,TUPLES.water);
}

export function assertChemicalReset(authored,before,after,samples) {
  assertEdit(after);
  assert.equal(after.generation,before.generation+1,'Reset did not install exactly one fresh generation');
  assert.equal(after.current_hash,authored.current_hash,'Reset kept evolved chemical/thermal cells');
  assert.equal(after.initial_hash,authored.current_hash);
  assert.equal(after.document.cells_sha256,authored.current_hash);
  assert.equal(after.document.undo_depth,0);
  assert.equal(after.document.redo_depth,0);
  assert.equal(after.document.history_bytes,0);
  assert.equal(after.history_retired,false);
  assert.deepEqual(after.body_poses,[]);
  assert.equal(after.pristine,true);
  assert.equal(after.intervention_count,0);
  assertSampleEpoch(samples.steam,after,CELLS.steam,TUPLES.steam);
  assertSampleEpoch(samples.hotSource,after,CELLS.hot,TUPLES.hot);
  assertSampleEpoch(samples.hotDestination,after,CELLS.fallen,TUPLES.empty);
}
