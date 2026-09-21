# CDS English PYQ Website — Data Source Guide & Ingestion Prompt

You are helping build a **CDS English Previous-Year-Questions (PYQ) website**. This document tells you
exactly which file holds which questions, how each file is structured internally, and how to add the
questions systematically. **Read this whole file before writing any ingestion code.**

The exam being covered is UPSC **CDS English** (Combined Defence Services). Each paper has 120 questions.
There are two sessions per year — **CDS 1** and **CDS 2** — for the years **2016 through 2026**
(CDS 2 of 2026 has not been held yet).

---

## 0. Golden rules

1. **Vocabulary is handled separately — do NOT ingest vocabulary here.** This guide is only for the two
   other question families: **Grammar & Usage** and **Comprehension / Ordering / Cloze**. (Vocabulary files
   are listed at the bottom only so you can recognise and skip them.)
2. **Always ingest from the `*_Solved_*` files, never the questions-only files.** The Solved files contain
   everything the questions-only files have (verbatim question + options) **plus** the correct answer and a
   short explanation. The questions-only files are strict subsets and should be ignored for the website.
3. **Reproduce text verbatim.** Do not paraphrase, "clean up", or regenerate any question, option, passage,
   or explanation. Copy the exact characters.
4. **`(!)` inside any text is an intentional flag** meaning the original scan was unclear and the text was
   reconstructed. Keep it. Optionally surface it in the UI as a "verify" marker, but never delete it.
5. **Do not invent data for the known gaps** listed in Section 4. If a paper/section isn't in a file, it
   isn't available yet — leave it out rather than fabricating.

---

## 1. Where the data lives

All files are in this folder:

```
C:\Users\ASUS\OneDrive\Desktop\CDS Course\English PYQ\
```

They are Microsoft Word `.docx` files. Parse them with a docx library (e.g. `python-docx`,
or `mammoth`/`docx4j` in JS). Every file is plain paragraphs with **Heading 1 / Heading 2 / Heading 3**
styles plus Normal paragraphs — no tables.

---

## 2. File manifest (ingest these)

Each family is split into four **era files**. Use the Solved version of each.

### Family A — Grammar & Usage  (source of truth = the 4 `Grammar_Solved` files)

| File | Papers covered | Questions |
|---|---|---|
| `CDS_English_Grammar_Solved_2016-2017.docx` | 2016 CDS 1 & 2, 2017 CDS 1 & 2 | 100 |
| `CDS_English_Grammar_Solved_2018-2020.docx` | 2018–2020, CDS 1 & 2 (6 papers) | 203 |
| `CDS_English_Grammar_Solved_2021-2023.docx` | 2021–2023, CDS 1 & 2 (6 papers) | 290 |
| `CDS_English_Grammar_Solved_2024-2026.docx` | 2024 CDS 1 & 2, 2025 CDS 1 & 2, 2026 CDS 1 | 148 |

Grammar is **fully solved for all 21 papers.**

Grammar question **types** you will encounter (Heading 3 labels; normalise to these buckets):
Spotting Errors · Fill in the Blanks · Sentence Improvement · Sentence Completion ·
Prepositions & Determiners · Parts of Speech / Word Classes · Voice (Active/Passive) · Reported Speech ·
Transformation of Sentences · Sentence Co-relationship (Correlating Sentences) · Spelling · Use of Phrasal Verbs.

### Family B — Comprehension / Ordering / Cloze  (source of truth = the `Comprehension_Ordering_Solved` files)

| File | Papers covered | Questions |
|---|---|---|
| `CDS_English_Comprehension_Ordering_Solved_2016-2017.docx` | 2016 CDS 1 & 2, 2017 CDS 1 & 2 | 274 |
| `CDS_English_Comprehension_Ordering_Solved_2018-2020.docx` | 2018–2020, CDS 1 & 2 (6 papers) | 311 |
| `CDS_English_Comprehension_Ordering_Solved_2024-2026.docx` | 2024 CDS 1 & 2, 2025 CDS 1, 2026 CDS 1 | 105 |

Comprehension question **types**: Reading Comprehension · Ordering of Sentences (para-jumble) ·
Ordering of Words in a Sentence · Cloze (labelled "Cloze Composition / Comprehension / Passage") ·
Selecting Words (a cloze-style variant seen in 2016).

> **Not yet available for Family B** (do not ingest, no Solved file exists): **2021–2023** (all six papers)
> and **2025 CDS 2**. See Section 4.

---

## 3. Internal structure of every file (how to parse)

The hierarchy is identical across all files:

- **Heading 1** → the **year**, e.g. `2026`
- **Heading 2** → the **exam sitting**, e.g. `2026 - CDS 1 (held 13 Apr 2026)`
  - Parse the year with `20\d\d` and the session with `CDS\s*([12])`.
- **Heading 3** → a **section**, e.g. `Spotting Errors (Q46-55)  (10)` or
  `Reading Comprehension - Passage I (Q51-55)  (5)`
  - The `(Qx-y)` range tells you the real paper question numbers for that section. **Use this range to
    validate question stems** (see the match-list caveat below).
  - A Heading 3 ending in `- omitted  (0)` or `Sections omitted …  (0)` is a placeholder with **no
    questions** — skip it.

Within a section, Normal paragraphs follow these patterns:

- `Directions: …` → the instruction line for that section (attach to the section, not to one question).
- `N. <stem text>` (e.g. `46. …`) → a **question stem**. The stem paragraph is bold in the source.
- `(a) …` `(b) …` `(c) …` `(d) …` → the four **options**.
- `Answer: (x) <option text>` → the **correct answer** (green in the source). The `(x)` is the correct
  option letter.
- `Why: …` → a one-line **explanation** (grey italic). Optional but usually present.
- `⚠ Note: …` → an occasional caveat (red). Keep it.

**Per-type extras:**

- **Ordering of Words in a Sentence** — between the stem and the options you get four labelled chunks:
  `P: …`, `Q: …`, `R: …`, `S: …`, then a `Proper sequence:` line, then the options `(a) PQRS` etc.
  Store the P/Q/R/S chunks as the sentence fragments and the option letters as sequences.
- **Ordering of Sentences (para-jumble)** — you get `S1: …` (fixed first), then `P: … / Q: … / R: … / S: …`,
  then `S6: …` (fixed last), then `Proper sequence:` and options. Store S1 and S6 as anchors.
- **Reading Comprehension** and **Cloze / Selecting Words** — the section begins with a **Heading 3 named
  `… Passage …`** (or a `Passage` sub-heading) followed by the passage text in Normal paragraphs, then the
  numbered questions with options. Attach every question in that block to its passage. A cloze passage has
  numbered blanks that correspond to the question numbers.

**Match-list caveat (important for parsing):** some questions contain internal numbered sub-items
(`1.`, `2.`, `3.`, `4.` — lists to be matched). These are **not** new questions. Only treat `N.` as a real
question stem when **N falls inside the current section's `(Qx-y)` range.** This one rule prevents
massive over-counting.

**Suggested normalized record** to emit per question:

```json
{
  "exam": "CDS 1",
  "year": 2026,
  "paper_id": "2026-CDS1",
  "family": "Grammar",              // or "Comprehension"
  "section_type": "Spotting Errors",
  "q_number": 46,                    // real paper number
  "directions": "…",                // section-level
  "passage": "…",                    // RC/Cloze only, else null
  "stem": "…",
  "parts": {"P":"…","Q":"…","R":"…","S":"…"},   // ordering types only, else null
  "options": {"a":"…","b":"…","c":"…","d":"…"},
  "answer_letter": "a",
  "answer_text": "…",
  "why": "…",
  "note": "…",                       // usually null
  "ocr_uncertain": true              // true if the stem/options contain "(!)"
}
```

---

## 4. Known gaps — current as of this handoff

- **Grammar & Usage:** ✅ complete and solved for **all 21 papers**. Nothing missing.
- **Comprehension / Ordering / Cloze:** solved for **14 papers** — 2016 (both), 2017 (both),
  2018–2020 (all six), 2024 (both), 2025 CDS 1, 2026 CDS 1.
  - ⛔ **Missing: 2021–2023 (all six papers).** Questions exist in
    `CDS_English_Comprehension_Ordering_2021-2023.docx` (245 Q, questions-only) but there is **no Solved
    file yet**, so no answers. Do not publish these until a Solved file is provided.
  - ⛔ **Missing: 2025 CDS 2 comprehension** — not extracted at all (degraded scan).
- **Answer provenance note:** the 2016–2017 and 2018–2020 comprehension answers were generated (no official
  key was available), unlike the vocab/grammar answers and the 2024–2026 comprehension answers which came
  from supplied keys. If you add a "verified" badge, treat those two comprehension files as "unofficial key".

---

## 5. How to add questions systematically

Ingest **one era file at a time**, and within it **one paper (Heading 2) at a time**, so progress is easy
to track and verify. Recommended order: finish **Grammar** (all four eras, fully solved) first, then
**Comprehension** for the eras that have Solved files.

For each file:
1. Walk paragraphs top to bottom, tracking current year / exam / section (+ its `(Qx-y)` range).
2. Emit one record per question using the schema in Section 3.
3. **Verify before committing:** the number of `Answer:` lines should equal the number of question stems
   in that paper's sections; log any question with no answer. (Counts you should see per file are in the
   Section 2 tables.)

**Reusable instruction the user will give you, one at a time:**

> "Add **<family>** questions for **<era file>**, papers **<which>**. Parse per the data guide, emit the
> normalized records, then show me the per-paper question/answer counts so I can confirm before you load
> them into the site."

---

## 6. Appendix — files to SKIP

- **Vocabulary (handled elsewhere):** `CDS_English_Vocabulary_Solved_*.docx` and
  `CDS_English_Questions_*.docx` (the `Questions_` files are the vocabulary questions-only set).
- **Questions-only (subsets of the Solved files):** `CDS_English_Grammar_2016-2017.docx` …,
  `CDS_English_Comprehension_Ordering_2016-2017.docx` … — ignore in favour of their `_Solved_` twins.
- **Answer-key source docs, the mock test, raw PDFs, and the `_CDS_build` folder** — not website data.
