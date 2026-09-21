# VicThree Defence - CDS English PYQ Library

A free, mobile-first website to **browse CDS English Previous Year Questions**
(section-wise, year-wise) and **take a random practice quiz**. Plain HTML/CSS/JS,
no build step, hosted on **GitHub Pages from the `/docs` folder**.

Live: https://victhree.github.io/victhree-english/

## Sections (11)

Spotting Errors, Reading Comprehension, Ordering of Words, Ordering of Sentences,
Fill in the Blanks, Cloze (incl. the 2016 Selecting Words variant), Parts of Speech /
Word Classes, Prepositions & Determiners, Sentence Completion, Sentence Improvement,
and Other Grammar (Reported Speech, Voice, Transformation, Spelling, Phrasal Verbs,
Sentence Co-relationship).

Reading Comprehension and Cloze are **passage-based**: the passage is shown once above
its cluster of questions, and the quiz keeps a passage cluster whole (all of it or none).

## Data pipeline

Sources are the 7 `*_Solved_*.docx` files under `sources/` (Grammar and
Comprehension/Ordering, 2016-2026). Vocabulary is a separate site and is not included.

1. `tools/parse_english.ps1` - reads each `.docx` (a zip; parses `word/document.xml`
   directly, no Python/Node), normalises the section labels into the 11 sections,
   groups passage clusters, drops only source-defective items (no answer / not 4 valid
   options), de-duplicates, and writes one JSON per section into `docs/data/`.
2. `tools/build_index.ps1` - scans `docs/data/*.json` and rebuilds `docs/data/index.json`
   (the manifest the pages lazy-load).

Re-run both whenever a source changes:

```
powershell -ExecutionPolicy Bypass -File tools/parse_english.ps1
powershell -ExecutionPolicy Bypass -File tools/build_index.ps1
```

Current totals: **1457 questions**, years **2016-2026**, all answerable.

## Schema (per question)

`id, subject (section), topic (family), subtopic, topicOriginal, year, session, paper,
qno, ref, directions, passageId, passageText, stem, subs[], options[4], answer, explanation`

`passageId` / `passageText` are set only for Reading Comprehension / Cloze. `subs[]`
holds each statement or fragment (S1/P/Q/R/S/S6 for ordering) on its own line.

## Deploy

Hosted on GitHub Pages from `main` `/docs`. Cache-busting: every CSS/JS reference carries
`?v=N`; on any deploy that changes CSS or JS, bump `N` in lockstep across the three HTML
pages, the `CACHE` constant in `docs/sw.js`, and the shell list in `docs/sw.js`.

## Conventions

- No em-dashes anywhere in site copy (enforced in the parser too).
- Answers are previous-year public knowledge, graded in the browser.
