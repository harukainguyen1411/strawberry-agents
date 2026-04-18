# Schema changes touching derived totals must propagate through the stack

When an ADR amendment changes a field that feeds derived totals (currency, units, timezone, base of measurement), update **all** the downstream surfaces in the same edit pass:

1. **Data model** — field type/enum + any `meta/*` doc that backs the conversion (e.g. FX rates in both directions, not just one).
2. **Invariants** — explicit rule for how the field interacts with immutability. For per-user base currency: store native broker currency on trades/positions, convert only at derived totals (snapshots, summary, sparkline, digest), and have snapshots embed the base used at write-time so later switches don't silently rewrite history.
3. **Architecture bullet** — name where in the code the conversion happens (handler layer in the shared tools module, not the UI).
4. **UI / rendering** — every chart, card, or text that previously hardcoded a unit must now read from the user field.
5. **Snapshot semantics** — late writes vs base switches need a defined behaviour.

A "per-user X" field is never a footnote. If you find yourself only changing one section, you've missed at least three others.
