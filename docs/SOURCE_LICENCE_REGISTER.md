# Source and licence register (2026-10-18)

Scope: every third-party dataset, media file, font, library and model Levlofit uses or is considering. "Verified" means
read on the licensor's own page or in the package's own licence file on 2026-10-18. No licence was bought or accepted,
and no restricted asset was copied. Not legal advice: commercial launch still needs the legal review.

Intended use: a free initial launch (owner decision 2026-10-18), with possible commercial use later.

## In use

| Asset | Where used | Licence (exact) | Verified at | Attribution | Redistribution | Commercial use | Action |
|---|---|---|---|---|---|---|---|
| ExerciseDB free V1 (AscendAPI): exercise names, muscles, instructions, 180p GIFs | public.exercises (catalogue imported once); GIFs hot-linked from static.exercisedb.dev | Usage Restrictions: allowed for "Personal projects, prototypes, educational tools, non-commercial apps, community-driven fitness platforms"; not allowed for "Commercial products, SaaS platforms, or any monetised use without a paid plan via RapidAPI"; "Credit to AscendAPI is required" | https://oss.exercisedb.dev/swagger (Usage Restrictions) | Required; the app shows the AscendAPI credit on every exercise screen | Not addressed (caching/redistribution of GIFs not stated) | **Not allowed without a paid plan** | Keep for the free launch with the credit. Before any revenue: paid plan, or replace media (see alternatives) |
| IFCT 2017 food composition (National Institute of Nutrition, ICMR): 543 foods, macros, 8 micronutrients | foods table (migrations 20260929170000, 20261016200000) | Book: "Copyright © 2017 by National Institute of Nutrition, Indian Council of Medical Research"; no open licence found. The ifct2017 GitHub project's own code is AGPL-3.0 since 1 May 2025 (earlier MIT) and does not license NIN's data | https://nin.res.in/ebooks/IFCT2017.pdf ; https://github.com/ifct2017/ifct2017.github.io [S: search summary of both] | Cite as "Indian Food Composition Tables 2017, National Institute of Nutrition, ICMR, Hyderabad" | **Not granted** | **Not granted** | Ask NIN in writing (nin@ap.nic.in, ifct2017@gmail.com) before release, even a free one; owner sends the request. Fallback: USDA FDC for non-Indian foods |
| Phosphor icon font (Phosphor-Light.ttf) | app/assets/fonts | MIT ("Copyright (c) 2020-2021 Phosphor Icons") | app/assets/fonts/PHOSPHOR-LICENSE | Notice must ship with the font | Yes | Yes | **Done 2026-10-18**: licence bundled as an asset and registered on the in-app licence page (registerBundledLicenses in main.dart; test in backend_guard_test.dart) |
| Geist, Geist Mono, Unbounded fonts | app via google_fonts (runtime download); website via next/font/google | SIL Open Font License 1.1 for all three: "This Font Software is licensed under the SIL Open Font License, Version 1.1." (Geist: Copyright 2024 The Geist Project Authors; Unbounded: Copyright 2022 The Unbounded Project Authors) | google/fonts repository: ofl/geist, ofl/geistmono, ofl/unbounded OFL.txt (read 2026-10-22) | OFL notice | Yes (not sold alone) | Yes | Keep; if fonts are ever bundled in the app, ship OFL.txt and register it like the Phosphor licence |
| Reminder sound levlo_chime.wav | app/assets/sounds, Android raw | Levlofit's own: synthesised by data/make_chime.py | repository | none | yes | yes | Keep |
| App icon | app/assets/icon | Levlofit's own | repository | none | yes | yes | Keep |
| flutter_local_notifications 22.3.1, **patched copy** in app/third_party (BSD-3-Clause, LICENSE kept, changes in LEVLOFIT_PATCH.md) | reminders | BSD-3-Clause | app/third_party/flutter_local_notifications/LICENSE | Keep licence and notice | Yes, with the licence | Yes | Keep the patch notes; re-check upstream before upgrading |
| Flutter packages (136 hosted, from pubspec.lock) | app | BSD 97, MIT 29, Apache-2.0 8, MPL-2.0 2 (dbus, gtk: Linux-desktop only, not in the Android build); 0 unknown | each package's LICENSE file in the pub cache | Notices via Flutter's licence page (showLicensePage) | yes | yes | Keep; make sure the Settings screen links to the licence page |
| Website npm packages (364) | website build | MIT 306, Apache-2.0 22, ISC 17, BSD 9, others permissive; LGPL-3.0 parts in @img/sharp (libvips) and MPL-2.0 in lightningcss and axe-core: build and lint tools, not in the exported site | each package.json | n/a for build tools | n/a | yes | Keep; if sharp is ever shipped in a server, comply with LGPL (dynamic linking, notices) |
| Supabase client libraries, Deno std | app, Edge Functions | MIT (supabase-js, supabase_flutter) | package licence files | notices | yes | yes | Keep |
| Handbook sources (WHO, ACSM, ISSN, NICE, ICMR, journal papers) | Handbook text and plan engine | Each publisher's copyright; Levlofit paraphrases and cites, quotes stay short in the internal evidence register | registers in data/evidence and data/handbook_v4 | Citations shown in each chapter | Paraphrase only | Paraphrase with citation | Keep; never copy tables or figures wholesale |

## Considered, not in use

| Asset | Licence (exact) | Verified at | Commercial use | Action |
|---|---|---|---|---|
| USDA FoodData Central | "USDA FoodData Central data are in the public domain and they are not copyrighted"; "published under CC0 1.0 Universal (CC0 1.0)"; "No permission is needed for their use, but we request that users list FoodData Central as the source" | https://fdc.nal.usda.gov/ ; data.gov record licence "https://www.usa.gov/publicdomain/label/1.0/" | Yes | Best licensed fallback for generic and Western foods; poor coverage of Indian dishes. Credit "USDA FoodData Central" |
| wger exercise database | Per entry: the API's licence table lists CC-BY-SA 3, CC-BY-SA 4, CC0, CC-BY 4, ODbL; sample exercise 9 is CC-BY-SA 4 by "deusinvictus"; code AGPL-3.0 | https://wger.de/api/v2/license/ ; https://wger.de/api/v2/exerciseinfo/ | Yes per entry, with attribution; CC-BY-SA and ODbL need share-alike for adapted data | Usable if each entry's licence and author are stored and shown; prefer CC0 and CC-BY entries; many entries have no images |
| Free Exercise DB (yuhonas/free-exercise-db), 800+ exercises with images | Repository "License: Unlicense"; data credited to wrkout/exercises.json, whose README calls it a "public domain" dataset but contains no licence text and no statement of where the images came from; wrkout also sells a separate dataset that "can be used in commercial projects" | https://github.com/yuhonas/free-exercise-db ; https://github.com/wrkout/exercises.json | **Unclear for the images** (origin undocumented) | Do not adopt the images until their origin and rights are documented in writing; the text fields may be usable under the Unlicense, but provenance should be confirmed first |
| INDB (Indian Nutrient Databank, Anuvaad) | Described as "open-access" in its paper; no licence text found; built mainly from IFCT 2017 plus UK and US databases, whose terms may carry over | https://pmc.ncbi.nlm.nih.gov/articles/PMC11277795 [S: search summary] | Unknown | Do not import until a licence is stated by the maintainers |
| MuscleWiki | Paid API; terms forbid caching or redistribution (batch AS) | earlier batch | Paid only | Not used |
| ExerciseDB paid plan | via RapidAPI or exercisedb.io | not re-checked | Paid | Owner decision before any revenue (no purchase made) |

## Replacement candidates checked 2026-10-22

| Need | Candidate | Licence (verified where stated) | Fit | Recommendation |
|---|---|---|---|---|
| Exercise media allowed for commercial use | wger exercise images | 383 images via https://wger.de/api/v2/exerciseimage/ ; each carries its own licence id (sample: id 1 = CC-BY-SA 3.0, one by author 'Everkinetic') | Static images, not the anatomy-GIF style the owner chose; coverage partial | Best licensed fallback: store licence id and author per image, show attribution; unmodified use needs attribution only (share-alike applies to adaptations) |
| Exercise data | Everkinetic data (github.com/everkinetic/data) | Repository states CC-BY-SA-4.0; image licence not stated on the page | Small, 22 commits | Only with a written image licence; otherwise use wger's copies, which carry per-image licences |
| Exercise media, own | Levlofit-made renders | Owned | Matches the chosen style | Long-term option before any revenue |
| Food data | USDA FoodData Central | CC0 1.0 (above) | Generic and Western foods | Keep as the licensed fallback |
| Indian food data | IFCT 2017, ICMR-NIN guideline 2024 | Copyright NIN; the 2024 guideline's own terms could not be re-read this session (NIN link 404, ICMR link returned a web page) | Core Indian coverage | Owner writes to NIN; meanwhile short attributed quotes only |

## AI models (see docs/AI_PROVIDER_COMPARISON.md)

| Model | Licence | Verified at | Note |
|---|---|---|---|
| gpt-oss-120b / 20b (OpenAI) | Apache-2.0 | https://huggingface.co/openai/gpt-oss-120b | Open weights under an OSI licence; used via Groq today |
| Qwen3 | Apache-2.0 | https://huggingface.co/Qwen/Qwen3-30B-A3B | Self-hosting candidate |
| Sarvam-M | Apache-2.0 | https://huggingface.co/sarvamai/sarvam-m | Self-hosting candidate |
| Gemma | Gemma Terms of Use (custom, prohibited-use policy, remote restriction right) | https://ai.google.dev/gemma/terms | Open weights, not open source |
| vLLM (serving software) | Apache-2.0 | https://github.com/vllm-project/vllm | For self-hosting |

## Decisions still needed (owner)

1. Write to NIN for IFCT 2017 reuse permission (applies even to a free app: no open licence was found).
2. Before any revenue: ExerciseDB paid plan, or a replacement media set with documented rights.
3. Whether to show a licences screen in the app (Flutter's built-in licence page) and add the USDA and IFCT credits.
