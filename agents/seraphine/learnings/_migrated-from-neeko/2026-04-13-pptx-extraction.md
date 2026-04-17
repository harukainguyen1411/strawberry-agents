# Learning: Extracting design tokens from python-pptx

## Date
2026-04-13

## Lesson
When extracting design tokens from `.pptx` files using `python-pptx`, iterate with `list()` on `.slides`, `.rows`, `.columns`, and `.cells` before slicing — direct slice access on these collections can raise `TypeError` or `AttributeError` in newer versions of the library.

## Key patterns
- `list(prs.slides)` instead of `prs.slides[:n]`
- `list(tbl.rows)` and `list(row.cells)` before indexing
- Font color extraction: wrap `run.font.color.rgb` in try/except — colors may be theme-based (not direct RGB)
- Fill color extraction: wrap entire `shape.fill.fore_color.rgb` in try/except — not all shapes have fill
- Slide dimensions via `prs.slide_width.inches` and `prs.slide_height.inches`
- Row height in points: `row.height / 914400 * 72`

## Vietinbank/UBCS specifics
- Both UBCS reference files use `10.0 x 5.625` inches (16:9 widescreen) — NOT 7.5h as previously assumed
- UBCS Q4 template uses Roboto as primary font; Vietinbank style ref uses Cambria + Arial
- UBCS Q4 has a slightly different blue: `005992` vs the existing guide's `00588F`
