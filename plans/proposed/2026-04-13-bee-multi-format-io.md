---
status: proposed
owner: swain
created: 2026-04-13
title: Bee — Multi-Format Input and Output Support
---

# Bee — Multi-Format Input and Output Support

> Expand Bee beyond docx-only: Haruka uploads .docx, .xlsx, .pptx, or .pdf and selects an output format. The worker extracts content, runs Claude, and renders the result into the requested format. Backward compatible with existing docx-only pipeline.

## Current State

- **Frontend** (`apps/myapps/src/views/bee/BeeHome.vue`): file picker accepts `.docx` only. Upload goes to `bee-temp/<uid>/<ts>/input.docx` in Firebase Storage.
- **Composable** (`apps/myapps/src/composables/useBee.ts`): hardcodes `input.docx` path and `application/vnd.openxmlformats-officedocument.wordprocessingml.document` content type.
- **Cloud Function** (`createBeeIssue`): receives `docxStorageUrl` param. Issue body metadata line: `docx: gs://...`.
- **Worker** (`apps/private-apps/bee-worker/src/`):
  - `parseIssueBody` extracts `question` and `docxUrl` from issue body metadata.
  - `worker.ts` downloads `input.docx`, runs `claude -p` (which reads `input.docx` from the job dir), gets JSON comment array back, injects comments via `docx.ts` / `comments.py`, uploads `result.docx`.
  - Claude prompt hardcodes "Read file `input.docx`" instruction.
- **Gemini intake plan** (`plans/in-progress/2026-04-13-bee-gemini-intake.md`): uses `mammoth` for docx text extraction in Cloud Functions. Lists non-docx formats as explicitly out of scope.

## 1. Input Formats and Parsers

All parsers run in the bee-worker (Node.js on GCE e2-micro). Each must produce a structured text representation that Claude can reason about.

### .docx — `mammoth` (existing)

Already in use. Extracts raw text. No changes needed for input parsing.

### .xlsx — `exceljs`

- **Library:** `exceljs` (npm). MIT license, actively maintained, 12k+ GitHub stars.
- **Extraction:** iterate worksheets, read each row as an array. Output a text representation per sheet: sheet name as header, rows as tab-separated values, cell formulas preserved as `=FORMULA` notation.
- **Why not `xlsx` (SheetJS)?** The community edition dropped open-source licensing in 2023. `exceljs` is fully MIT and supports reading + writing (needed for output), so one library covers both directions.
- **Edge cases:**
  - Merged cells: `exceljs` exposes merge info. For text extraction, unmerge and duplicate the value into each cell position.
  - Charts/images: ignored for text extraction. Note in the extracted text: "[Chart omitted]", "[Image omitted]".
  - Very large spreadsheets (>10k rows): truncate at 10k rows per sheet with a note. Claude's context window is the constraint, not memory.

### .pptx — `pptx-parser` or raw OOXML extraction

- **Library:** No mature single-purpose pptx-to-text library exists in the Node ecosystem with reliable maintenance. Two options:
  - **Option A (recommended):** Use `node-unzipper` to open the .pptx (which is a ZIP), parse `ppt/slides/slide*.xml` files with a lightweight XML parser (`fast-xml-parser`). Extract text from `<a:t>` elements. This is ~50 lines of code and zero heavy dependencies.
  - **Option B:** `officegen` or `pptx2json` — both have spotty maintenance and pull in large dependency trees.
- **Extraction:** Per-slide text blocks, ordered by slide number. Output: `## Slide 1\n<text>\n## Slide 2\n<text>`.
- **Edge cases:**
  - Speaker notes: extract from `ppt/notesSlides/` if present. Append as `[Speaker notes: ...]` after each slide.
  - Embedded media: ignored. Note: "[Image omitted]", "[Video omitted]".
  - SmartArt/diagrams: text within SmartArt XML nodes is extractable; layout is not. Extract text only.

### .pdf — `pdf-parse`

- **Library:** `pdf-parse` (npm). Wraps Mozilla's `pdf.js`. Lightweight, no native binaries.
- **Extraction:** `pdf(buffer).then(data => data.text)`. Returns concatenated text from all pages.
- **Why not `pdfjs-dist` directly?** `pdf-parse` is a simpler wrapper for text-only extraction. If layout preservation becomes important later, switch to `pdfjs-dist` with custom text-layer handling.
- **Edge cases:**
  - **Scanned PDFs (image-only):** `pdf-parse` returns empty text. Detection: if extracted text length < 50 chars for a multi-page PDF, it is likely scanned. **Out of scope for P0.** Surface a message to Haruka: "This PDF appears to be scanned. Text extraction is not supported for scanned documents yet." Log for future OCR consideration (Tesseract.js or Google Cloud Vision).
  - Password-protected PDFs: `pdf-parse` throws. Catch and return error to user.
  - Large PDFs (>50 pages): truncate text extraction at 50 pages with a note.

## 2. Output Formats and Generators

The worker produces structured output from Claude, then renders it into the requested format using format-specific libraries.

### .docx — `docx` library (existing path: comments injection; new path: document generation)

- **For comment-injection jobs** (current behavior): keep existing `comments.py` pipeline unchanged.
- **For document-generation jobs** (new): use the `docx` npm library to programmatically build a Word document from Claude's structured output. Supports headings, paragraphs, tables, lists, basic styling.
- **Why not Pandoc?** Pandoc requires a system binary install on the GCE instance. The `docx` library is pure JS and already sufficient for the document structures Haruka needs. Pandoc is overkill for personal use.

### .xlsx — `exceljs`

- Same library as input parsing (one dependency for both directions).
- Create workbook, add worksheets, write rows with data types preserved (numbers, strings, dates).
- Supports basic cell styling (bold headers, column widths) and formulas.
- Claude's structured output specifies sheet names, headers, and row data (see Section 4).

### .pptx — `pptxgenjs`

- **Library:** `pptxgenjs` (npm). MIT license, actively maintained, purpose-built for slide generation.
- Creates slides with title + body text, bullet lists, tables, and basic images.
- Claude's structured output specifies slide titles and content blocks (see Section 4).
- Limitations: no complex animations or transitions. Adequate for Haruka's academic/work use cases.

### .pdf — `pdfkit`

- **Library:** `pdfkit` (npm). Pure JS, no native dependencies.
- Generates PDF from text, with basic formatting (headings, paragraphs, lists, page breaks).
- **Why not html-to-pdf via Puppeteer?** Puppeteer requires a headless Chrome binary (~300MB). The e2-micro instance has 1GB RAM. `pdfkit` is lightweight and sufficient for text-heavy documents.
- Limitations: no complex layouts (multi-column, floating images). For Haruka's use cases (research summaries, formatted text), this is fine.

### Plain text / Markdown — fallback

- Always available. Claude's raw text output written to `result.md` or `result.txt`.
- Used when no specific output format is requested, or as a degraded fallback if format rendering fails.

## 3. Output Format Selection

### UI-driven selection with smart default

**Primary mechanism:** dropdown in `BeeHome.vue` after file upload. Options:

- Same as input (default, auto-selected based on uploaded file extension)
- .docx (Word)
- .xlsx (Excel)
- .pptx (PowerPoint)
- .pdf
- Plain text / Markdown

If no file is uploaded (text-only request), default is "Plain text / Markdown."

**Gemini intake override:** When the Gemini intake assistant is active, the intake bot already asks about output format as part of its rubric (see existing intake plan, Section 5, "Format" field). If the user specifies a format during intake, that takes precedence over the UI dropdown. The intake `finalSpec.format` field maps to the format enum.

**Recommendation:** UI selector is the primary control. Gemini intake can surface a suggestion ("I'll output this as a PowerPoint — is that right?") but the user always has final say via the UI dropdown before clicking "Send to Bee."

## 4. Worker Pipeline Change

### Recommended: Option A — Claude generates structured JSON, worker renders to format

Current flow: Claude reads `input.docx` and returns a JSON array of `{quote, comment, source_url}` objects. This is already structured output, but it is specific to the comment-injection use case.

**New flow:**

1. Worker detects the requested output format from the issue body metadata.
2. Worker builds a Claude prompt that includes the extracted text (not the raw file) and instructions to produce format-appropriate structured JSON.
3. Claude returns structured JSON matching one of the intermediate schemas below.
4. Worker renders the JSON into the target format using the appropriate library.

### Intermediate JSON schemas

**Document output** (for .docx, .pdf, plain text):

```
{
  "type": "document",
  "title": "string",
  "sections": [
    {
      "heading": "string",
      "level": 1-3,
      "paragraphs": ["string", ...],
      "list_items": ["string", ...] | null
    }
  ]
}
```

**Spreadsheet output** (for .xlsx):

```
{
  "type": "spreadsheet",
  "sheets": [
    {
      "name": "string",
      "headers": ["string", ...],
      "rows": [["cell_value", ...], ...],
      "column_types": ["string" | "number" | "date", ...]
    }
  ]
}
```

**Slide deck output** (for .pptx):

```
{
  "type": "slides",
  "title": "string",
  "slides": [
    {
      "title": "string",
      "body": ["string (bullet point)", ...],
      "notes": "string" | null,
      "layout": "title" | "content" | "two_column"
    }
  ]
}
```

**Comment-injection output** (existing, for docx review jobs):

```
{
  "type": "comments",
  "comments": [
    {"quote": "string", "comment": "string", "source_url": "string"}
  ]
}
```

The `type` field determines which rendering pipeline the worker invokes. The existing comment-injection flow is preserved as `type: "comments"` — no breaking change.

### Prompt adaptation

The worker prompt builder (`claude.ts:buildUserPrompt`) must become format-aware:

- Accept the target output format and the intermediate schema as parameters.
- Include the schema definition in the prompt so Claude knows what structure to produce.
- The "read `input.docx`" instruction becomes "Here is the extracted text from the uploaded file:" followed by the pre-extracted text (the worker extracts text before invoking Claude, rather than having Claude read the file directly). This decouples Claude from file-format awareness.

**Key change:** Claude no longer reads the raw file. The worker extracts text first, passes it in the prompt, and Claude operates on text only. This is cleaner and enables all input formats without Claude needing format-specific tools.

## 5. Upload UI Changes

### `BeeHome.vue`

- File input `accept` attribute: `.docx,.xlsx,.pptx,.pdf`
- Validation: check file extension against allowlist. Show error for unsupported types.
- File type hint text: "Supported formats: .docx, .xlsx, .pptx, .pdf"
- Output format dropdown (see Section 3). Appears after file selection. Auto-selects "Same as input."
- Max file size validation: 10MB (existing limit, if any, or introduce one).

### `DocxUpload` component

- Rename to `FileUpload` (or make format-agnostic). Update `accept` prop.
- Display detected file type icon/label after selection.

## 6. Issue Body Extension

Current metadata footer format:

```
---
docx: gs://bucket/path/to/input.docx
```

New format (backward compatible):

```
---
file: gs://bucket/path/to/input.xlsx
format: xlsx
output_format: pptx
```

- `file:` replaces `docx:` as the generic key. **Backward compatibility:** `parseIssueBody` checks for `file:` first, falls back to `docx:` if not found. Old issues with `docx:` continue to work.
- `format:` declares the input file format (extension without dot). Worker uses this to select the correct parser.
- `output_format:` declares the requested output format. If absent, defaults to input format. If no file, defaults to `markdown`.

### `parseIssueBody` changes

Current signature: `{ question: string; docxUrl: string | null }`

New signature: `{ question: string; fileUrl: string | null; inputFormat: string | null; outputFormat: string }`

Backward compatible: if only `docx:` is present, `inputFormat` = `"docx"`, `outputFormat` = `"docx"`.

## 7. Storage Path Conventions

Current: `bee-temp/<uid>/<ts>/input.docx`

New: `bee-temp/<uid>/<ts>/input.<ext>`

- Preserve the original file extension. The extension tells the worker (and any human debugging) what format the file is.
- Do not preserve the original filename. Storage paths should be predictable and not depend on user-chosen names (which may contain special characters, spaces, or be excessively long).
- The composable (`useBee.ts`) extracts the extension from the selected file's name and uses it in the storage path.
- Content type in `uploadBytes` must match the actual file type (map extension to MIME type).

## 8. Result File Naming

- `result.<output_ext>` — e.g., `result.pptx`, `result.xlsx`, `result.pdf`.
- Storage path: `bee-temp/issue-<issueNum>/<ts>/result.<output_ext>`.
- Do not include the user's intended name. The download link label in the issue comment can show a friendly name: "Download result (PowerPoint)" but the actual file is `result.pptx`.
- The `buildAnswerComment` function in `worker.ts` adapts the download link text based on output format.

## 9. Gemini Intake Interaction

The intake plan (`plans/in-progress/2026-04-13-bee-gemini-intake.md`) needs the following changes when this plan lands:

1. **File reading in `beeIntakeStart`:** Currently uses `mammoth` for docx only. Must detect file extension and dispatch to the appropriate parser (mammoth for docx, exceljs for xlsx, custom XML extraction for pptx, pdf-parse for pdf). Same libraries as the worker — shared extraction logic should be factored into a common package or duplicated (the functions and worker are separate deployables; a shared npm workspace package is the clean path).

2. **System prompt update:** The intake rubric already asks about "Format" (output format). No prompt change needed — the bot naturally asks about output format. The `finalSpec.format` field should be mapped to the `output_format` metadata key when filing the issue.

3. **`beeIntakeSubmit` issue body:** Add `format:` and `output_format:` lines to the metadata footer, sourced from the file extension and `finalSpec.format` respectively.

4. **Non-goal change:** Remove "Intake for non-docx file types" from the intake plan's Non-Goals section once this plan is implemented.

## 10. Phasing

### P0 — Multi-format input (worker still outputs docx or text only)

- Add xlsx, pptx, pdf parsers to bee-worker.
- Update `parseIssueBody` to handle new metadata format (backward compatible).
- Update frontend file picker to accept all four formats.
- Update `useBee.ts` to upload with correct extension and content type.
- Update Cloud Function `createBeeIssue` to accept `fileStorageUrl` (rename from `docxStorageUrl`) and `inputFormat`.
- Worker extracts text from any supported format, passes to Claude, Claude returns text/comment output, worker writes `result.docx` or `result.md` as today.
- **Deliverable:** Haruka can upload any of the four formats. Output is always docx (comment injection) or text.

### P1 — Output format selection and rendering

- Add output format dropdown to `BeeHome.vue`.
- Add `output_format` to issue body metadata.
- Worker prompt builder becomes format-aware (Section 4).
- Implement rendering pipelines: `exceljs` for xlsx, `pptxgenjs` for pptx, `pdfkit` for pdf, `docx` for docx generation.
- Intermediate JSON schemas validated before rendering (fail gracefully to markdown if schema validation fails).
- Update `buildAnswerComment` for format-aware download links.
- **Deliverable:** Haruka selects output format, gets result in that format.

### P2 — Polish and edge cases

- Shared text-extraction package between Cloud Functions (intake) and bee-worker.
- Scanned PDF detection with clear user messaging.
- Large file handling: progress indicators, chunked extraction.
- Format conversion quality review: have Haruka test each input-output combination and flag issues.
- Error recovery: if rendering fails, fall back to markdown output with a note ("Could not generate .pptx — here is the content as text").

## 11. Acceptance Scenarios

### Scenario A: xlsx input, pptx output

1. Haruka uploads `sales-data.xlsx` containing quarterly revenue by product.
2. She types: "Create a presentation summarizing the key trends from this data."
3. She selects "PowerPoint (.pptx)" from the output format dropdown.
4. She clicks Submit.
5. Issue is filed with `file: gs://.../input.xlsx`, `format: xlsx`, `output_format: pptx`.
6. Worker extracts sheet data as structured text, sends to Claude with slide-deck schema instructions.
7. Claude returns `{"type": "slides", "slides": [...]}`.
8. Worker renders via `pptxgenjs`, uploads `result.pptx`.
9. Haruka sees the download link in BeeHistory: "Download result (PowerPoint)".
10. She downloads and opens a .pptx with titled slides summarizing her data trends.

### Scenario B: pdf input, docx output

1. Haruka uploads `research-paper.pdf`.
2. She types: "Summarize this paper and list the key findings."
3. Output format: "Word (.docx)" (or left as "Same as input" which resolves to pdf, then she switches to docx).
4. Worker extracts text via `pdf-parse`, Claude produces document-structured JSON, worker renders via `docx` library.
5. Result: a .docx with headings and paragraphs summarizing the paper.

### Scenario C: backward compatibility

1. An old-format issue exists with `docx: gs://.../input.docx` (no `format:` or `output_format:` lines).
2. Worker's updated `parseIssueBody` falls back: `fileUrl` from `docx:`, `inputFormat` = `"docx"`, `outputFormat` = `"docx"`.
3. Existing comment-injection pipeline runs unchanged.

### Scenario D: scanned PDF (P0 graceful failure)

1. Haruka uploads a scanned PDF. `pdf-parse` returns near-empty text.
2. Worker detects <50 chars extracted from a multi-page PDF.
3. Issue comment posted: "This PDF appears to be a scanned document. Text extraction is not yet supported for scanned files. Please upload a text-based PDF or a different format."
4. Issue closed with label `failed`.

## Open Questions for Duong

1. **Excel formulas:** Should Bee preserve formulas when extracting xlsx input (passing formula expressions to Claude), or just extract computed values? Formulas add complexity but may be important for financial/academic spreadsheets.
2. **Shared extraction package:** The Gemini intake (Cloud Functions) and bee-worker both need the same text extraction logic. Factor into a shared workspace package now, or duplicate and unify later? Shared package is cleaner but adds monorepo complexity.
3. **PDF rendering quality:** `pdfkit` produces basic PDFs (text, headings, lists). If Haruka needs styled PDFs (custom fonts, headers/footers, page numbers), we would need a more sophisticated approach. Is basic sufficient for now?
4. **Storage rules PR:** Katarina's PR expanding storage rules for xlsx/pptx/pdf — is it landed or still in progress? This plan depends on those rules being in place before P0 can be tested.
5. **Worker resource constraints:** The e2-micro (1 vCPU, 1GB RAM) runs the worker. Adding `exceljs`, `pptxgenjs`, `pdfkit`, and `pdf-parse` increases memory usage. Should we size up to e2-small for P1, or test on micro first?
