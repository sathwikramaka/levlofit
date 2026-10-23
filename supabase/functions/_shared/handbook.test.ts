// Run: node --test supabase/functions/_shared/handbook.test.ts
// Grounded Handbook retrieval: passage data, relevance, source references, missing evidence and citation checks.
// Deterministic: a small fixture corpus plus the real generated passages file. No network, no database.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  type Corpus, evidenceNote, HANDBOOK, handbookBlock, MIN_SCORE, type Passage, retrieve, SYNONYMS, tokens, TOPICS, validateCitations,
} from './handbook.ts';

const passage = (id: string, text: string, over: Partial<Passage> = {}): Passage => ({
  id, chapter: id.split(':')[0], chapterTitle: over.chapterTitle ?? 'Fixture', blockType: 'text', text, sources: ['srcA'],
  unknownSources: [], chapterSources: ['srcA'], evidence: 'unreviewed', clinicalReview: false, claimIds: [`${id}:text`], ...over,
});
const FIXTURE: Corpus = {
  sources: { srcA: 'Author A. A made-up source for tests. 2020.' },
  passages: [
    passage('rest:b00', 'Rest two to three minutes between sets of heavy compound lifts.', { chapterTitle: 'Rest between sets' }),
    passage('rest:b01', 'Shorter rest of about ninety seconds works for accessory lifts.', { chapterTitle: 'Rest between sets', evidence: 'checked' }),
    passage('food:b00', 'Paneer and curd are easy protein sources for vegetarians.', { chapterTitle: 'Protein foods' }),
    passage('food:b01', 'Dal, chana and rajma give plant protein for vegetarians.', { chapterTitle: 'Protein foods' }),
    passage('pain:b00', 'Chest pain during exercise means stop and see a doctor.', { chapterTitle: 'Safe to start', clinicalReview: true }),
    passage('label:b00', 'Rest table', { chapterTitle: 'Rest between sets', evidence: 'no_claims' }),
    passage('bad:b00', 'Rest is never needed between sets.', { chapterTitle: 'Rest between sets', evidence: 'disputed' }),
  ],
};
const ids = (hits: { passage: Passage }[]) => hits.map((h) => h.passage.id);

// ---- passage data -------------------------------------------------------------------------------------------------

test('passages file: one entry per Handbook block, stable ids, real citations only', () => {
  assert.ok(HANDBOOK.passages.length > 100);
  const seen = new Set<string>();
  for (const p of HANDBOOK.passages) {
    assert.match(p.id, /^[a-z0-9-]+:b\d{2}$/, p.id);
    assert.ok(!seen.has(p.id), `duplicate ${p.id}`);
    seen.add(p.id);
    assert.ok(p.claimIds.length > 0 && p.claimIds.every((c) => c.startsWith(`${p.id}:`)), `${p.id}: claim ids must share the passage id`);
    for (const k of p.sources) assert.ok(HANDBOOK.sources[k], `${p.id}: source ${k} has no citation`);
    assert.ok(['checked', 'partly_checked', 'unreviewed', 'unsourced', 'editorial', 'disputed', 'no_claims'].includes(p.evidence), p.id);
  }
});

/** Minimal RFC 4180 reader for the register (quoted fields may hold commas, quotes and newlines). */
function readCsv(text: string): Record<string, string>[] {
  const rows: string[][] = [];
  let row: string[] = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; } else if (ch === '"') quoted = false; else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(field); field = ''; }
    else if (ch === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (ch !== '\r') field += ch;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  const [head, ...body] = rows;
  return body.map((r) => Object.fromEntries(head.map((h, i) => [h, r[i] ?? ''])));
}

test('passages file: every claim id is in the evidence register, and each evidence label agrees with the register', () => {
  const register = new Map(readCsv(readFileSync(new URL('../../../data/evidence/claims_register.csv', import.meta.url), 'utf8')).map((r) => [r.claim_id, r]));
  for (const p of HANDBOOK.passages) {
    for (const c of p.claimIds) assert.ok(register.has(c), `${c} not in register`);
    const claims = p.claimIds.map((c) => register.get(c)!).filter((r) => r.auto_kind !== 'label');
    const st = claims.map((r) => r.evidence_status);
    if (p.evidence === 'checked') assert.ok(st.length && st.every((s) => s === 'verified'), `${p.id}: checked needs every claim verified`);
    if (p.evidence === 'disputed') assert.ok(st.some((s) => s === 'unsupported' || s === 'contradicted'), p.id);
    if (p.evidence === 'unreviewed') assert.ok(!claims.some((r) => r.supporting_passage), `${p.id}: has a quoted passage but is labelled unreviewed`);
    if (p.evidence === 'partly_checked') assert.ok(claims.some((r) => r.supporting_passage), `${p.id}: partly checked without any quoted passage`);
    if (p.evidence === 'editorial') assert.ok(st.every((s) => ['editorial', 'non_claim', 'auto_label'].includes(s)), `${p.id}: editorial needs every claim editorial`);
    if (p.evidence === 'unsourced') assert.ok(st.some((s) => s === 'needs_source' || s === 'needs_better_source') && !st.some((s) => s === 'unreviewed' || s === 'stale'), p.id);
    const pendingClinical = p.claimIds.some((c) => /\bclinical_review\b/.test(register.get(c)!.flags) && !register.get(c)!.review_needs.includes('clinical_done'));
    assert.equal(p.clinicalReview, pendingClinical, `${p.id}: clinical flag`);
  }
});

test('tokens: lower case, stop words dropped, simple plural and -ing stems', () => {
  assert.deepEqual(tokens('How many Sets should I do?'), ['set']);
  assert.deepEqual(tokens('Squatting with sore knees'), ['squatt', 'sore', 'knee']);
  assert.deepEqual(tokens('the and of'), []);
  assert.deepEqual(tokens('2 to 3 minutes'), ['2', '3', 'minute']);
});

// ---- relevance --------------------------------------------------------------------------------------------------

test('relevance (fixture): the best passage comes first; label-only and disputed blocks are never returned', () => {
  const hits = retrieve('How long should I rest between sets?', FIXTURE, { minScore: 0.1 });
  assert.equal(hits[0].passage.chapterTitle, 'Rest between sets');
  assert.ok(!ids(hits).includes('label:b00'));
  assert.ok(!ids(hits).includes('bad:b00'));
});

test('relevance (real Handbook): questions land on the chapter that covers them', () => {
  const top = (q: string) => retrieve(q)[0]?.passage.chapter;
  assert.equal(top('How long should I rest between sets?'), 'rest-between-sets');
  assert.equal(top('How much water should I drink?'), 'water');
  assert.equal(top('How do I get better sleep?'), 'sleep-recovery');
  assert.equal(top('how to lose fat'), 'fat-loss');
  assert.equal(top('Does creatine have health risks?'), 'supplements');
  assert.equal(top('Is creatine safe?'), 'supplements');
});

// ---- synonyms, paraphrases and the specific-word rule ----------------------------------------------------------

test('synonyms: "safe" and "dangerous" reach the creatine safety passage, which never says "safe"', () => {
  for (const q of ['Is creatine safe?', 'Is creatine dangerous?', 'Is creatine harmful?']) {
    const first = retrieve(q)[0].passage;
    assert.equal(first.id, 'supplements:b04', q);
    assert.doesNotMatch(first.text, /\bsafe\b/i, 'the corrected wording stays as it is');
    assert.match(first.text, /adverse health risks/);
  }
});

test('paraphrases: everyday wording lands on the chapter that covers it', () => {
  const top = (q: string) => retrieve(q)[0]?.passage.chapter;
  assert.equal(top('How much creatine should I take?'), 'supplements');
  assert.equal(top('How much caffeine should I take?'), 'supplements');
  assert.equal(top('Does exercise help when I feel depressed?'), 'mind-motivation');
  assert.equal(top('Can I exercise while pregnant?'), 'women');
  for (const q of ['How much creatine should I take?', 'Is creatine safe?']) {
    assert.ok(retrieve(q).every((h) => h.passage.chapter === 'supplements'), q);
  }
});

test('specific-word rule: a passage with the question\'s rarest word outranks a generic match with a higher score', () => {
  const corpus: Corpus = {
    sources: FIXTURE.sources,
    passages: [
      passage('gen:b00', 'Safe training starts slowly. Safe habits and safe progress keep you safe.', { chapterTitle: 'Safe to start' }),
      passage('gen:b01', 'Warm up first and stay safe.', { chapterTitle: 'Safe to start' }),
      passage('cr:b00', 'Creatine monohydrate at 3 to 5 grams a day.', { chapterTitle: 'Supplements' }),
    ],
  };
  const hits = retrieve('Is creatine safe?', corpus, { minScore: 0.1 });
  assert.equal(hits[0].passage.id, 'cr:b00');
  assert.ok(hits.some((h) => h.passage.id.startsWith('gen:')), 'generic matches still follow');
});

test('synonyms are explicit, point at Handbook words, and only add half weight', () => {
  const vocab = new Set(HANDBOOK.passages.flatMap((p) => [...tokens(p.text), ...tokens(p.chapterTitle)]));
  for (const [word, targets] of Object.entries(SYNONYMS)) {
    for (const t of targets) assert.ok(vocab.has(t), `${word} -> ${t}: not a Handbook word`);
    assert.ok(!targets.includes(word));
  }
  // A synonym alone scores half of the same word typed directly.
  const corpus: Corpus = { sources: FIXTURE.sources, passages: [passage('r:b00', 'Low risk for most adults.'), passage('x:b00', 'Unrelated text here.')] };
  const direct = retrieve('risk', corpus, { minScore: 0 })[0].score;
  const viaSynonym = retrieve('safe', corpus, { minScore: 0 })[0].score;
  assert.ok(Math.abs(viaSynonym - direct / 2) < 0.002, `${viaSynonym} vs ${direct}`);
});

test('unsupported and label-only passages are never returned, even through a synonym', () => {
  const corpus: Corpus = {
    sources: FIXTURE.sources,
    passages: [
      passage('bad:b00', 'Creatine has no risk at any dose.', { evidence: 'disputed' }),
      passage('lab:b00', 'Creatine risk', { evidence: 'no_claims' }),
      passage('ok:b00', 'Creatine at 3 to 5 grams a day has been studied with no adverse health risks found.'),
    ],
  };
  assert.deepEqual(ids(retrieve('Is creatine safe?', corpus, { minScore: 0.1 })), ['ok:b00']);
});

test('clinically flagged passages keep their flag when found through a synonym or paraphrase', () => {
  const hits = retrieve('Does exercise help when I feel depressed?');
  assert.ok(hits.length > 0);
  assert.ok(hits.every((h) => h.passage.clinicalReview), 'depression passages are flagged for clinical review');
  assert.match(handbookBlock(hits), /needs clinical review/);
  const creatine = retrieve('Is creatine safe?')[0].passage;
  assert.equal(creatine.clinicalReview, true);
  assert.equal(creatine.evidence, 'partly_checked', 'retrieval does not change evidence status');
});

test('unrelated questions: still nothing for clearly unrelated text', () => {
  for (const q of ['What is the capital of France?', 'hi', '']) assert.deepEqual(retrieve(q), [], q);
  // Known limit: an off-topic question sharing an everyday word ("night", "list", "match") still pulls a weak passage;
  // the scope rule, not retrieval, handles those.
  assert.ok(retrieve('Is it safe to drive at night?').every((h) => h.passage.chapter !== 'supplements'));
});

test('deterministic: the same question gives the same passages and scores', () => {
  assert.deepEqual(retrieve('How much protein do I need?'), retrieve('How much protein do I need?'));
});

test('exclusions: passages naming a food this person must avoid are not retrieved', () => {
  const all = ids(retrieve('protein for vegetarians', FIXTURE, { minScore: 0.1 }));
  assert.ok(all.includes('food:b00'));
  const safe = ids(retrieve('protein for vegetarians', FIXTURE, { minScore: 0.1, exclude: ['paneer', 'curd'] }));
  assert.ok(!safe.includes('food:b00'));
  assert.ok(safe.includes('food:b01'));
});

// ---- missing evidence -----------------------------------------------------------------------------------------

test('missing evidence: off-topic or empty questions retrieve nothing, and the prompt says the Handbook does not cover it', () => {
  for (const q of ['What is the capital of France?', 'hi', '', '???']) assert.deepEqual(retrieve(q), [], q);
  // Known limit of keyword matching: everyday words still match. "list" (a levels chapter) and "match" (a sets
  // chapter) pull in weak, unrelated passages for off-topic requests. They score low and are labelled, and the scope
  // rule, not retrieval, keeps such requests out (see the eval off-topic case).
  for (const q of ['Write me a Python function that sorts a list.', 'Who won the cricket match yesterday?']) {
    assert.ok(retrieve(q).every((h) => h.score < 5), q);
  }
  const block = handbookBlock([]);
  assert.match(block, /none matched this question/);
  assert.match(block, /Do not cite the Handbook/);
  assert.ok(MIN_SCORE > 0);
});

// ---- source references -----------------------------------------------------------------------------------------

test('prompt block: each passage carries its id, chapter, evidence status and cited sources, and says it is not a clinical review', () => {
  const hits = retrieve('How long should I rest between sets?', FIXTURE, { minScore: 0.1 });
  const block = handbookBlock(hits, FIXTURE);
  assert.match(block, /not a clinical review/);
  assert.match(block, /\[H:rest:b00\] Rest between sets\. Evidence: not yet checked against its source\. Sources: srcA: Author A/);
  assert.match(block, /\[H:rest:b01\] Rest between sets\. Evidence: checked against its cited source\./);
  const none = handbookBlock([{ passage: passage('x:b00', 'text', { sources: [] }), score: 5 }], FIXTURE);
  assert.match(none, /Sources: none cited in this block/);
});

test('topics (coach plan item 4): paraphrased rest and running questions rank their chapter first; others are unchanged', () => {
  const top = (q: string) => retrieve(q).map((h) => h.passage.chapter);
  for (const q of [
    'How many minutes should I wait between sets?',
    'How long should I chill between sets?',
    'How long a break between sets?',
    'Should I pause longer between sets?',
    'How long should I chill before my next set of squats?',
    'How long should I rest between sets?',
  ]) assert.equal(top(q)[0], 'rest-between-sets', q);
  for (const q of ['Does cardio kill muscle growth?', 'Will running ruin my gains?']) assert.equal(top(q)[0], 'one-step-at-a-time', q);
  // The questions an earlier attempt broke: creatine stays in its chapter, an off-topic safety question never lands there.
  for (const q of ['Is creatine safe?', 'How much creatine should I take?']) assert.ok(top(q).every((c) => c === 'supplements'), q);
  assert.ok(!top('Is it safe to drive at night?').includes('supplements'));
  // A single everyday word is not a topic: both halves are needed.
  assert.ok(!TOPICS.some((t) => t.match.test('should i take a break from training this week?')));
  assert.ok(!TOPICS.some((t) => t.match.test('can i go running tomorrow morning?')));
  assert.ok(!TOPICS.some((t) => t.match.test('how many sets should i do for squats?')));
});

test('coach plan item 4: every shipped passage the coach can cite has been reviewed (none is "unreviewed")', () => {
  const open = HANDBOOK.passages.filter((p) => p.evidence === 'unreviewed').map((p) => p.id);
  assert.deepEqual(open, [], 'review these in data/evidence/claims_register.csv before shipping');
  // The 2026-10-24 abstract-level review: partly checked (never "checked"), and the HYROX tip cites no source.
  const by = (id: string) => HANDBOOK.passages.find((p) => p.id === id)!;
  for (const id of ['one-step-at-a-time:b04', 'one-step-at-a-time:b05', 'rest-between-sets:b01', 'rest-between-sets:b04']) assert.equal(by(id).evidence, 'partly_checked', id);
  assert.equal(by('hyrox:b04').evidence, 'editorial');
  assert.deepEqual(by('hyrox:b04').sources, []);
});

test('evidence notes never overstate: unreviewed says so, clinical flags stay visible', () => {
  assert.equal(evidenceNote(passage('a:b00', 't')), 'not yet checked against its source');
  assert.equal(evidenceNote(passage('a:b00', 't', { evidence: 'partly_checked' })), 'partly checked against its cited source');
  assert.equal(evidenceNote(passage('a:b00', 't', { clinicalReview: true })), 'not yet checked against its source; needs clinical review');
  assert.equal(evidenceNote(passage('a:b00', 't', { evidence: 'editorial' })), "Levlofit's own guidance, no source claimed");
  assert.equal(evidenceNote(passage('a:b00', 't', { evidence: 'unsourced' })), 'no source cited; general guidance only');
});

// ---- citation validation ---------------------------------------------------------------------------------------

test('citations: a retrieved id becomes a readable reference with its evidence status', () => {
  const hits = retrieve('chest pain while exercising', FIXTURE, { minScore: 0.1 });
  const g = validateCitations('Stop and see a doctor [H:pain:b00].', hits);
  assert.equal(g.text, 'Stop and see a doctor (Handbook: Safe to start, not yet checked against its source; needs clinical review).');
  assert.deepEqual(g.cited.map((c) => c.id), ['pain:b00']);
  assert.equal(g.cited[0].clinicalReview, true);
  assert.deepEqual(g.invalid, []);
});

test('citations: invented, unretrieved, empty and malformed markers are removed and counted', () => {
  const hits = retrieve('How long should I rest between sets?', FIXTURE, { minScore: 0.1 });
  const g = validateCitations('Rest 2 minutes [H:rest:b00]. Studies agree [H:made-up:b99]. Also [H:food:b01]. [H:] [H: rest:b00 ]', hits);
  assert.deepEqual(g.cited.map((c) => c.id), ['rest:b00'], 'a repeated id is shown once');
  assert.deepEqual(g.invalid, ['made-up:b99', 'food:b01', '']);
  assert.ok(!g.text.includes('[H:'));
  assert.match(g.text, /^Rest 2 minutes \(Handbook: Rest between sets, not yet checked against its source\)\. Studies agree\. Also\.$/);
});

test('citations: with nothing retrieved every Handbook citation is invalid; other brackets are left alone', () => {
  const g = validateCitations('Do 3 sets [H:sets-reps-progress:b01] [1] (see notes).', []);
  assert.equal(g.text, 'Do 3 sets [1] (see notes).');
  assert.deepEqual(g.invalid, ['sets-reps-progress:b01']);
  assert.deepEqual(g.cited, []);
});
