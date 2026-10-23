# AI provider comparison for the Levlofit coach (updated 2026-10-18; for the owner's choice)

Nothing has been selected, configured or called. No real user data has been sent anywhere; no key exists. Every fact
is tagged **[O]** (read on the provider's or licensor's own page on 2026-10-18) or **[S]** (secondary reporting, not
confirmed on an official page). Prices and limits change often: re-check on the day you decide. Not researched:
OpenAI, Mistral, Anthropic beyond what is noted, and Indian GPU clouds for self-hosting.

**Open weights vs open source.** Open weights means the trained model file may be downloaded and run; the licence
decides what you may do with it. Apache-2.0 models (gpt-oss, Qwen3, Sarvam-M) are both open weights and OSI-approved
licences. Gemma (custom "Gemma Terms of Use" with a prohibited-use policy and remote restriction rights) and Llama
(community licence) are open weights but **not** open source. Serving software (vLLM, Apache-2.0) is open source;
hosted APIs (Groq, Gemini, Sarvam) are proprietary services even when the model inside is open.

## Goal: a personalised coach that feels like ChatGPT for fitness (owner, 2026-10-22)

### What the coach already does (read in code, supabase/functions/coach-chat and _shared/coach-context.ts)

- Every message carries the person's profile, food settings and exclusions, current plan (targets, sessions), recent
  training and food logs, lift summaries when the question is about lifting, and step totals only with consent.
- Chat memory: the last 12 messages of the chat (HISTORY_LIMIT). Cross-chat memory: the model writes short notes,
  stored in coach_notes (up to 2,000 characters, oldest dropped); the app shows them ("What Levlofit AI remembers")
  and lets the person delete them.
- Grounding: Handbook passages retrieved per question with checked citations; a food-safety check regenerates any
  reply naming an excluded food; replies that echo private context are rejected; rate limits and the data-use gate.
- Threads, edit and regenerate, duplicate-send protection, a fallback provider and one time budget per message.

### What a different model cannot add (must be built in Levlofit)

1. **Long-chat memory**: anything older than 12 messages is dropped. Needs a rolling summary per chat.
2. **Better long-term memory**: notes are free text, model-written, append-only and capped; no structured facts
   (injuries, schedule, equipment, likes), no per-item edit or expiry, no confirmation before saving.
3. **Actions**: the coach cannot change the plan, swap an exercise, log a workout or meal, or set a reminder from
   chat. "Make tomorrow lighter" today only gets advice. Needs tool calls with the app confirming each change.
4. **Streaming**: the whole reply arrives at once, which feels slower than ChatGPT even at the same speed.
5. **Retrieval**: keyword matching, so paraphrased questions can miss the right Handbook passage.
6. **Proactive check-ins** (missed sessions, plateaus): none.
These are ranked by their effect on "feels personal". 1, 3 and 4 matter most; none depends on the provider.

### Benchmark prepared (not run): Groq gpt-oss-120b vs Gemini 3.8 Flash (paid)

Model choice: Google lists gemini-3.8-flash as stable and tells new projects to use it or 3.5 Flash-Lite
(Gemini 2.5 is limited to existing users) [O: ai.google.dev/gemini-api/docs/models]. Both models run with
reasoning_effort "medium" (adapter change 2026-10-22, tested), because Gemini 3 cannot turn reasoning off and bills it.

- Cases: the same synthetic cases for both (supabase/functions/_eval/cases.ts: 22 cases, 13 marked liveOk for live runs),
  including 4 new multi-turn cases: an injury mentioned earlier (memory-knee), a time limit given earlier (memory-time),
  a stored note (memory-notes) and a follow-up on earlier numbers (memory-targets-follow-up). Personas are synthetic.
- Measures: strict checks (plan numbers, food exclusions, privacy, earlier messages sent) and indicative checks
  (recall of earlier facts, safety, scope); consistency across 3 runs; latency median and p90; tokens; cost from
  measured tokens. Script: `node supabase/functions/_eval/compare.ts groq.json gemini.json --price-a 0.15,0.60
  --price-b 0.75,3.75`.
- Not measured by any script: whether advice is good coaching. Read the replies of both runs side by side for the
  multi-turn and workout cases before deciding; the indicative checks only flag obvious misses.
- Assumptions (not measured): 5,000 input and 600 output tokens per message; Gemini's reasoning tokens are extra.

Commands, after you accept each provider's terms and create the keys yourself (synthetic data only):
```
LLM_PROVIDER=groq LLM_API_KEY=<groq key> node supabase/functions/_eval/run.ts --live --runs 3 --out groq.json
LLM_PROVIDER=gemini LLM_MODEL=gemini-3.8-flash LLM_API_KEY=<gemini key> node supabase/functions/_eval/run.ts --live --runs 3 --out gemini.json
node supabase/functions/_eval/compare.ts groq.json gemini.json --price-a 0.15,0.60 --price-b 0.75,3.75
```

### Re-verified 2026-10-22 (batch 2R, official pages; owner: Groq Free plan, AI Studio Free tier)

| | Groq | Gemini |
|---|---|---|
| Model ID | `openai/gpt-oss-120b`, Production, 131,072 context [O: console.groq.com/docs/models] | `gemini-3.8-flash`, Stable; Google: new projects use 3.8 Flash or 3.5 Flash-Lite [O: ai.google.dev/gemini-api/docs/models] |
| Paid price per 1M in/out | $0.15 / $0.60 | $0.75 / $3.75 to 31 Dec 2026, $1.50 / $7.50 from 1 Jan 2027; output includes thinking [O: .../pricing] |
| Free-tier limits | Not on the public page (Developer plan: 30 RPM, 1K RPD, 8K TPM, 200K TPD); yours are at console.groq.com/settings/limits | Not published; per project, shown in AI Studio (aistudio.google.com/rate-limit) [O: .../rate-limits] |
| Training use | Services Agreement 4.2: "not permitted to use Inputs or Outputs for training"; covers fee-free services by use | Free tier: content used "to provide, improve" products and "human reviewers may read" it; "Do not submit sensitive, confidential, or personal information to the Unpaid Services". Paid: not used to improve; logged for a limited period [O: ai.google.dev/gemini-api/terms] |
| Retention | Not retained by default; ZDR open to all customers (Data Controls) | Paid: limited-period logs; no zero-retention switch in the terms |

Consequence: the Gemini free tier is acceptable only for synthetic data (the benchmark); real users need the paid tier.

### Proposed smallest live test (not run; needs the owner's go)

- 13 live cases (the liveOk set, synthetic personas only, incl. 4 multi-turn) x 2 runs x 2 providers = **52 calls expected**;
  ceiling 208 HTTP requests if every call needed one regeneration and one retry (not expected).
- Measured offline today: 7,000 to 7,600 characters per request, about 1,900 prompt tokens (characters / 4, estimate);
  replies capped at 1,400 tokens.
- Cost on both free tiers with billing off: **$0**. Paid-tier equivalent at the cap: Groq about $0.03, Gemini about
  $0.17 (ceiling $0.12 and $0.69).
- `--pause-ms 30000` (added to run.ts in 2R) keeps Groq under 8K tokens/min; about 15 minutes per provider.
- Risk: Gemini's 1,400-token cap may include its thinking, so some replies can come back short or empty; the run
  reports that as a failure, and it is a real limit of the current adapter setting.
- Latency on free tiers may differ from paid tiers; quality and tokens do not depend on the tier.
- Batch 2S review (code read, offline only): per case-run the handler makes 1 model call, plus at most one rewrite
  (empty or leaked reply) and one food fix, each with 1 retry (LLM_MAX_RETRIES default 1): 1 to 6 HTTP requests.
  The harness now sums tokens over all calls of a reply, records every HTTP request and the wall-clock time
  (before, only the last call counted). Records hold ids, pass/fail, timing and token counts only: no replies,
  prompts, reasons or keys. Owner's Groq limits confirmed from the console: 30 RPM, 8K TPM, 1K RPD, 200K TPD.
  Gemini 3.8 Flash free-tier limits not yet confirmed. Write outputs outside the repo (not git-ignored).

```
LLM_PROVIDER=groq LLM_API_KEY=<groq key> node supabase/functions/_eval/run.ts --live --runs 2 --pause-ms 30000 --out groq.json
LLM_PROVIDER=gemini LLM_MODEL=gemini-3.8-flash LLM_API_KEY=<gemini key> node supabase/functions/_eval/run.ts --live --runs 2 --pause-ms 30000 --out gemini.json
node supabase/functions/_eval/compare.ts groq.json gemini.json --price-a 0.15,0.60 --price-b 0.75,3.75
```

### Groq Zero Data Retention: available, not verified on your account

Official: "All customers may enable Zero Data Retention (ZDR)"; organisation admins switch it on globally or per
feature in the console (Data Controls, console.groq.com/settings/data-controls); no plan restriction is stated; it
disables batch and fine-tuning only, which Levlofit does not use [O: console.groq.com/docs/your-data]. Whether it is
on for your organisation can only be seen in your console; it is **not** assumed on. Developer-plan limits for
gpt-oss-120b: 30 requests/min, 8,000 tokens/min, 1,000 requests/day, 200,000 tokens/day [O: console.groq.com/docs/rate-limits]:
about one coach message a minute in total, so a higher plan is needed before real use.

### Recommendation for your goal (provisional until the benchmark runs)

For a coach that feels personal, the biggest gains come from Levlofit itself (items 1, 3, 4 above), whichever model
is used. Between the two models, quality on multi-turn coaching matters more than price here, and it has not been
measured yet: **run the prepared benchmark on both before choosing.** Expectation, not measurement: Gemini 3.8 Flash
is Google's current stable model and likely the stronger conversationalist; Groq gpt-oss-120b is about 5 to 10
times cheaper per token, far faster [O: 500 tokens/s], contractually barred from training on your data, offers Zero
Data Retention, and its Apache-2.0 weights can later be self-hosted in India. Gemini paid keeps no training use but
may cache data in any country and has no zero-retention switch in its terms. Decision rule: choose Gemini 3.8 Flash
only if it clearly beats gpt-oss-120b on the memory and coaching cases when you read the replies; otherwise choose
Groq for privacy, speed and cost.

Estimated monthly cost at 1,000 coach messages (assumed tokens): Groq gpt-oss-120b about $1.1; Gemini 3.8 Flash
about $6 in 2026 and about $12 from 1 January 2027 [O: price doubles], plus its reasoning tokens.

## The candidates

| | Groq (hosted gpt-oss) | Gemini API, paid tier | Sarvam API | Self-hosted open weights |
|---|---|---|---|---|
| Works in Levlofit today | Yes, preset `groq` (default model openai/gpt-oss-120b) | Yes, preset `gemini` (set `LLM_MODEL`) | Not tested: OpenAI-compatible shape [S], would use `LLM_BASE_URL` + `sarvam@host` approval | Yes if served with an OpenAI-compatible server (vLLM): `LLM_BASE_URL` + `provider@host` approval |
| Model and licence | gpt-oss-120b / 20b, Apache-2.0 [O] | Gemini (closed model) | sarvam-105b (API); Sarvam-M weights Apache-2.0 [O] | gpt-oss-120b/20b Apache-2.0 [O]; Qwen3 Apache-2.0 [O] |
| Price per 1M tokens (in / out) | 120b: $0.15 / $0.60; 20b: $0.075 / $0.30 [O] | 2.5 Flash-Lite $0.10 / $0.40; 3.1 Flash-Lite $0.25 / $1.50; 2.5 Flash $0.30 / $2.50 [O] | sarvam-105b ₹15 / ₹60 [O, docs pricing page]; other Sarvam pages and reports show different figures [S] | GPU rental, paid whether used or not; 120b needs one 80 GB GPU (H100 class) [O]; 20b is smaller |
| Published speed | 120b 500 tokens/s, 20b 1,000 tokens/s [O] | not published | not published | depends on hardware |
| Rate limits | Developer plan base: 30 requests/min, 8,000 tokens/min, 1,000 requests/day, 200,000 tokens/day for both gpt-oss models [O]. **8K tokens/min is about 1 to 2 coach messages a minute for all users together**; higher limits need a plan change | Tier 1 needs a linked billing account; per-model RPM/TPM shown only in AI Studio; spend cap $10 per 10 minutes on Tier 1 [O] | sarvam-105b: 40 / 60 / 120 requests/min (Starter / Pro / Business) [O-docs, pages inconsistent] | your own capacity |
| Training on your data | **Not permitted** unless you instruct it (Services Agreement s.4.2) [O] | Paid: not used to improve products [O]. **Free tier: used for improvement and read by human reviewers; never use with user data** [O] | Terms may allow training on inputs and outputs, with consent where required [S]; official wording not confirmed | none (you hold the data) |
| Retention | None by default; up to 30 days only for reliability or abuse investigation; Zero Data Retention switch for all customers [O] | Paid: may be stored transiently or cached [O] | Retention set by the workspace owner, 0 days available [S] | your choice |
| Where processed | Data retained in US GCP buckets [O]; processing location not stated | "Any country in which Google or its agents maintain facilities" [O] | Azure Central India and Indian GPU providers [S]; no official API residency statement found | wherever you rent the GPU (India possible) |
| Commercial use and other terms | Commercial service; AUP applies | Users must be 18+; may not be used "to provide medical advice" or in clinical practice [O]: legal must confirm fitness coaching fits | Complies with DPDP Act per its terms [O, general statement] | Apache-2.0 allows commercial use; you carry all safety, uptime and security work |
| Integration effort | none (already the default) | set 3 secrets | test compatibility first; small risk | build and run a GPU server, monitoring, scaling: large |

## Recommendation (for your decision; not chosen)

**Groq with gpt-oss-120b, Zero Data Retention switched on, on a plan whose token limit fits your expected users.**
Reasons: it is the provider the app and its offline evaluation were built around (no integration work); the contract
bars training on your data and retention is off by default (primary source); it is the cheapest per message among
those checked and the fastest published; the model is Apache-2.0 open weights, so the same model can later be
self-hosted in India without re-tuning prompts if data residency becomes required. Costs and caveats: data is held in
the United States (legal must clear the cross-border question under the DPDP Act); the published Developer-plan limit
of 8,000 tokens a minute is far too low for more than a handful of active users, so confirm the plan's limits first;
gpt-oss quality on Indian nutrition questions is unmeasured until the live benchmark runs.

Alternatives: **Gemini 2.5 Flash-Lite (paid)** if you prefer Google's limits and quality, accepting processing in any
country and the medical-advice clause review. **Self-hosted gpt-oss in India** if residency is mandatory, accepting the
GPU cost and operations work. **Sarvam** only after getting written answers on training and retention.

## Rough monthly cost (illustration, not a measurement)

Assumes 1,000 coach messages a month at 5,000 input and 600 output tokens each (an assumption; the live benchmark
records real token counts): Groq gpt-oss-120b about $1.1; Gemini 2.5 Flash-Lite about $0.7; Gemini 2.5 Flash about $3;
Sarvam 105B about ₹111. Prices exclude GST and currency conversion.

## The benchmark is ready (not run)

Synthetic personas only: `supabase/functions/_eval/personas.ts` and `cases.ts` (no real user data). The offline mode runs
in every regression (`node supabase/functions/_eval/run.ts`: 43 strict cases). After you choose a provider, accept its
terms and create the key yourself, the live run is:

```
LLM_PROVIDER=groq LLM_API_KEY=<your key> LLM_DATA_APPROVED=groq node supabase/functions/_eval/run.ts --live --runs 3 --out benchmark-groq.json
```

It records answers, scores, retries, error kinds, tokens and latency per case; compare providers only on files with
the same `casesFingerprint`.

## India-related considerations (legal review required)

- DPDP Act 2023: transfers abroad are allowed except to countries the government notifies [S, law-firm summaries];
  reports differ on when the transfer rules take effect. Whether profile, training and step data count as sensitive
  under any sector rule is for the legal review.
- In-India processing found: Claude on Amazon Bedrock (Mumbai and Hyderabad) is documented by AWS [O] but needs a new
  adapter; Gemini in India is press-reported only, for Vertex AI provisioned throughput, not the Gemini API [S];
  Sarvam has no official API residency statement [S]; self-hosting on an Indian GPU cloud is possible.

## Sources (read 2026-10-18)

Official: Groq data https://console.groq.com/docs/your-data ; Groq contract https://console.groq.com/docs/legal/services-agreement ;
Groq models and prices https://console.groq.com/docs/models ; Groq limits https://console.groq.com/docs/rate-limits ;
Gemini prices https://ai.google.dev/gemini-api/docs/pricing ; Gemini terms https://ai.google.dev/gemini-api/terms ;
Gemini limits https://ai.google.dev/gemini-api/docs/rate-limits ; Sarvam prices https://docs.sarvam.ai/api/pricing ;
Sarvam limits https://docs.sarvam.ai/api/ratelimits ; Sarvam terms https://www.sarvam.ai/terms-of-service ;
gpt-oss licence https://huggingface.co/openai/gpt-oss-120b ; Qwen3 licence https://huggingface.co/Qwen/Qwen3-30B-A3B ;
Sarvam-M licence https://huggingface.co/sarvamai/sarvam-m ; vLLM https://github.com/vllm-project/vllm ;
Gemma terms https://ai.google.dev/gemma/terms ; OpenRouter ZDR https://openrouter.ai/docs/guides/features/zdr ;
Claude prices https://claude.com/pricing ; Claude in India via Bedrock https://aws-news.com/article/2026-09-30-amazon-bedrock-expands-claude-model-availability-to-in-country-inferencing-in-india
Secondary: Sarvam training and retention https://safeguard.sh/models/compare/deepseek-v4-pro-vs-sarvam-sarvam-105b ;
Sarvam price change https://usagepricing.com/blueprint/activity/sarvam-ai-2026-08-06-price-change ;
DPDP transfers https://ksandk.com/md/data-protection-and-data-privacy/cross-border-data-transfers-dpdp-act-india/

## Local models, measured 2026-10-22 (batch 2T; synthetic personas, localhost only, 1 run of the 13 live cases)

Laptop: Ryzen 9 9955HX, 32 GB RAM, RTX 5060 Laptop 8 GB. Ollama 0.40.2 (update offered, not installed). Installed:
qwen3:8b and qwen3-fast (same weights) Apache-2.0; qwen3.5:9b Apache-2.0; dolphin-llama3:8b Meta Llama 3 Community
Licence, an uncensored fine-tune with 8K context: not benchmarked, unsuitable for a safety-critical coach. Local tags
levlo-qwen3-8k and levlo-qwen35-8k reuse the existing weights with num_ctx 8192 (the default 40K context spilled 48%
to CPU); remove with `ollama rm`. Adapter preset `ollama` (127.0.0.1:11434) sends reasoning_effort "none": with
thinking on, a 200-token test reply came back empty.

| Measured | qwen3 8B (Q4_K_M) | qwen3.5 9B (Q4_K_M) |
|---|---|---|
| Strict checks | 40 pass, 3 fail | 40 pass, 3 fail |
| Food exclusions (strict) | 3 of 5: breakfast and vegan dinner named excluded foods even after the forced rewrite | 3 of 5: same two cases |
| Plan numbers (strict) | 7 of 8 (protein target missing once) | 8 of 8 |
| Handbook citation (strict) | 1 of 1 | 0 of 1 |
| Privacy, format, memory context, notes (strict) | all pass | all pass |
| Recall (indicative) | 2 of 2; short-answer note ignored | 1 of 2; short-answer note followed |
| Latency median / p90 | 2.6 s / 7.1 s, 100% GPU | 3.9 s / 10.9 s |
| Tokens per case in / out (mean, all calls) | 2,157 / 149 | 2,192 / 120 |

Reading: both are usable for offline development and smoke tests at zero cost, not as the production coach. Food
safety held only because the deterministic check adds the warning footer; the model alone failed 2 of 5. One run, so
consistency is not measured. Replies were not read by a person.
