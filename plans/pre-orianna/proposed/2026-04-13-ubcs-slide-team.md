---
title: UBCS Slide Team — Build & Style
status: proposed
date: 2026-04-13
agents: [neeko, katarina]
---

## Goal
Tạo pipeline 2 tool tạo slide báo cáo UBCS từ Excel, theo brand Vietinbank.

## Context
- Template Q4: `/Users/duongntd99/Downloads/Slide hop UBCS Quy 4.pptx`
- Style reference: `/Users/duongntd99/Downloads/Ban Chao Giai phap cho Truong Hoc 2025.pptx`
- Excel Q1: `/Users/duongntd99/Downloads/UBCS QUY 1.xlsx`
- Data JSON (đã parse): `/tmp/ubcs_data.json`
- Tools dir: `tools/` trong working directory

## Artifacts hiện có
- `tools/ubcs-style-guide.json` — brand colors/fonts, cần Neeko cải thiện
- `tools/ubcs-data-parser.py` — DONE, hoạt động tốt
- `tools/ubcs-slide-builder.py` — draft, cần Katarina hoàn thiện

## Task A — Neeko: Visual Design System
Cải thiện `tools/ubcs-style-guide.json`:
- Thêm spacing rules (row heights, padding, margin)
- Thêm slide layout templates (vị trí header bar, title, table, chart)
- Thêm per-slide config: slide 3 (bang1), slide 4 (donut), slide 5 (bang2), slide 6 (bar), slide 7+ (detail)
- Lấy màu/font từ `Ban Chao Giai phap cho Truong Hoc 2025.pptx` — font chính là Cambria + Arial, navy #223A5E, blue #00588F, red #C91F3E

## Task B — Katarina: Slide Builder
Hoàn thiện `tools/ubcs-slide-builder.py`:
- Dùng `tools/ubcs-style-guide.json` cho tất cả màu/font/size
- Áp đúng Cambria cho title, Arial cho body
- Bảng: header navy + white, alt row light blue, total row navy + white bold, delta âm đỏ/dương xanh
- Donut chart: dùng CHART_COLORS từ style guide, legend phải
- Stacked bar: 3 màu navy/blue/red, legend dưới
- Detail slides: tô màu theo trang_thai_color từ style guide
- Test: `python3 tools/ubcs-slide-builder.py /tmp/ubcs_data.json "/Users/duongntd99/Downloads/Slide hop UBCS Quy 4.pptx"`
- Output vào `~/Downloads/`

## Done when
- Neeko: style-guide.json đầy đủ, có layout spec cho từng loại slide
- Katarina: builder chạy được, output PPTX đẹp, không có lỗi
