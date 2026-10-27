import { test } from 'node:test';
import assert from 'node:assert/strict';
import { base64Bytes, BODY_CHECK_SYSTEM, FOCUS_AREAS, parseBodyCheck, visionRequest } from './body-check.ts';

test('a well-formed, neutral reply is accepted; focus limited to the fixed list, deduplicated, at most 3', () => {
  const r = parseBodyCheck('```json\n{"observations": ["Shoulders sit level and the stance is balanced."], "focus": ["core", "core", "legs", "upper body", "conditioning", "lower body"]}\n```');
  assert.deepEqual(r, { observations: ['Shoulders sit level and the stance is balanced.'], focus: ['core', 'upper body', 'conditioning'] });
});

test('replies that judge weight, fat, BMI, looks or health are refused', () => {
  for (const bad of ['You carry some belly fat.', 'Estimated body fat 22%.', 'You look overweight.', 'BMI looks high.', 'Possible scoliosis diagnosis.', 'About 70 kg.']) {
    assert.equal(parseBodyCheck(JSON.stringify({ observations: [bad], focus: ['core'] })), null, bad);
  }
});

test('malformed or empty replies are refused', () => {
  assert.equal(parseBodyCheck('not json'), null);
  assert.equal(parseBodyCheck('{"observations": [], "focus": []}'), null);
  assert.equal(parseBodyCheck('{"observations": "one", "focus": []}'), null);
  assert.equal(parseBodyCheck(JSON.stringify({ observations: ['a', 'b', 'c', 'd', 'e'], focus: [] })), null);
});

test('request carries the photo as a data URL and the strict prompt; base64 size', () => {
  const body = visionRequest('m', 'image/jpeg', 'QUJD');
  assert.equal(body.messages[0].content, BODY_CHECK_SYSTEM);
  assert.match(JSON.stringify(body.messages[1]), /data:image\/jpeg;base64,QUJD/);
  assert.equal(base64Bytes('QUJD'), 3);
  assert.equal(base64Bytes('QUI='), 2);
  for (const f of FOCUS_AREAS) assert.ok(BODY_CHECK_SYSTEM.includes(f));
});
