# Validation View Design Patterns

1. **Edits as overlay, not mutation.** Store human review edits in a separate review.json rather than mutating the generated artifacts. This preserves the LLM baseline for comparison and supports "reset to generated" per field.

2. **Single HTML file wins for review artifacts.** The Travelers review HTML proved that self-contained HTML (inline CSS/JS, no framework) is the right format for review documents — they can be opened from filesystem, emailed, served statically, or hosted with a backend.

3. **Section-to-artifact 1:1 mapping.** Each review section should map to exactly one pipeline artifact file. This makes data flow obvious and edit merging simple. Cross-cutting concerns (like persona appearing in research + strategy + content) are handled with cross-references, not restructuring.

4. **Inline edit vs regeneration boundary.** Text/value changes can be inline-edited. Structural changes (add/remove fields, steps, companion pages) require pipeline regeneration. The view must make this distinction clear to the reviewer.
