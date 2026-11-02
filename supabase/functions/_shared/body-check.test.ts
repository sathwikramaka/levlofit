import { test } from 'node:test';
import assert from 'node:assert/strict';
import { base64Bytes, BODY_CHECK_SYSTEM, FOCUS_AREAS, imageMatches, MAX_IMAGE_BYTES, MAX_REQUEST_BYTES, parseBodyCheck, readCapped, visionRequest } from './body-check.ts';

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

/** A POST whose body arrives in chunks, with no Content-Length (or a false one), like a chunked upload. */
function streamed(chunks: Uint8Array[], headers: Record<string, string> = {}) {
  let pulled = 0;
  const body = new ReadableStream<Uint8Array>({
    pull(c) {
      if (pulled < chunks.length) c.enqueue(chunks[pulled++]);
      else c.close();
    },
  });
  const req = new Request('http://localhost/body-check', { method: 'POST', body, headers, duplex: 'half' } as RequestInit);
  return { req, pulled: () => pulled };
}

test('readCapped counts real bytes: a streamed body over the cap is refused without reading the rest', async () => {
  const chunk = new Uint8Array(1024).fill(65);
  const s = streamed(Array.from({ length: 100 }, () => chunk));
  assert.equal(s.req.headers.get('content-length'), null);
  assert.equal(await readCapped(s.req, 10 * 1024), null);
  assert.ok(s.pulled() <= 12, `stopped after ${s.pulled()} chunks`);
});

test('readCapped ignores a false Content-Length that understates the body', async () => {
  const s = streamed([new Uint8Array(4096).fill(65)], { 'content-length': '10' });
  assert.equal(await readCapped(s.req, 1024), null);
});

test('readCapped returns a body exactly at the cap, joined across chunks; empty body is empty text', async () => {
  const enc = new TextEncoder();
  const s = streamed([enc.encode('{"a":'), enc.encode('"bc"}')]);
  assert.equal(await readCapped(s.req, 10), '{"a":"bc"}');
  assert.equal(await readCapped(new Request('http://localhost', { method: 'POST' }), 10), '');
});

test('cap sizes: the request cap fits the largest allowed photo as base64 plus JSON', () => {
  assert.ok(MAX_REQUEST_BYTES >= Math.ceil(MAX_IMAGE_BYTES / 3) * 4 + 100);
  assert.ok(MAX_REQUEST_BYTES < MAX_IMAGE_BYTES * 1.4);
});

test('imageMatches checks the file signature against the declared type', () => {
  const b64 = (bytes: number[]) => btoa(String.fromCharCode(...bytes));
  const jpeg = b64([0xff, 0xd8, 0xff, 0xe0, 0, 16, 74, 70, 73, 70, 0, 1]);
  const png = b64([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13]);
  const webp = btoa('RIFF\x10\x00\x00\x00WEBPVP8 ');
  assert.ok(imageMatches('image/jpeg', jpeg));
  assert.ok(imageMatches('image/png', png));
  assert.ok(imageMatches('image/webp', webp));
  assert.ok(!imageMatches('image/png', jpeg), 'declared PNG, sent JPEG');
  assert.ok(!imageMatches('image/jpeg', btoa('<svg xmlns=...')), 'not an image');
  assert.ok(!imageMatches('image/jpeg', '!!!!'), 'not base64');
  assert.ok(!imageMatches('image/gif', jpeg), 'type outside the list');
});
