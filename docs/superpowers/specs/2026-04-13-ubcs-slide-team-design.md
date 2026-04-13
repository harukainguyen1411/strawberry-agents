# UBCS Slide Team — Design Spec
**Date:** 2026-04-13  
**Status:** Approved

## Summary

Multi-agent pipeline trong Strawberry để tự động tạo slide báo cáo họp UBCS (Ủy ban Chính sách) từ file Excel, theo đúng visual style Vietinbank.

---

## 1. Architecture

Ba agent hiện có trong Strawberry, không tạo agent mới:

```
Evelynn (coordinator)
    │
    ├── Zoe ─────── đọc Excel → xuất JSON trung gian vào /tmp/ubcs_data.json
    │
    ├── Katarina ── nhận JSON + style guide → clone template PPTX → build output
    │
    └── Output ──── ~/Downloads/Slide hop UBCS Quy X - YYYY-MM-DD.pptx
```

**Trigger:** Thủ công — Evelynn nhận lệnh từ Duong, dispatch tuần tự Zoe rồi Katarina.

**Input:**
- Path file Excel (ví dụ `~/Downloads/UBCS QUY 2.xlsx`)
- Path file template PPTX (ví dụ `~/Downloads/Slide hop UBCS Quy 4.pptx`)

**Output:** File PPTX đặt tại `~/Downloads/`, tên format `Slide hop UBCS Quy X - YYYY-MM-DD.pptx`

---

## 2. Tools (lưu trong `tools/`)

| File | Agent | Mục đích |
|---|---|---|
| `tools/ubcs-data-parser.py` | Zoe | Đọc Excel, chuẩn hóa, xuất JSON |
| `tools/ubcs-slide-builder.py` | Katarina | Nhận JSON + style guide, build PPTX |
| `tools/ubcs-style-guide.json` | cả hai | Brand colors, fonts, layout rules |

---

## 3. Data Parser (Zoe)

Đọc 2 sheet chính:
- `Gốc tổng hợp VPCS các khối` → đếm VBCS còn hiệu lực theo Khối (Phần 1)
- `VB TRÊN 5N` → phân loại trạng thái theo Khối + rows có tiến độ/ghi chú (Phần 2)

Xuất `ubcs_data.json` với schema:
```json
{
  "quy": "1",
  "nam": "2026",
  "phan1": {
    "tong_q1": 474,
    "theo_khoi": [
      { "ten": "Khối QLRR TD", "q1": 121, "q4": 111, "delta": 10 }
    ]
  },
  "phan2": {
    "tong": 255,
    "theo_khoi": [
      { "ten": "K NHÂN SỰ", "giu_nguyen": 32, "sdbs": 11, "tuyen_huy": 10, "tong": 55 }
    ],
    "co_tien_do": [
      { "khoi": "K NHÂN SỰ", "soky": "...", "trich": "...", "trang_thai": "Điều chỉnh", "tien_do": "..." }
    ]
  }
}
```

Khối name mapping (template Q4 ↔ excel) được hardcode trong parser, dễ cập nhật.

---

## 4. Slide Builder (Katarina)

Clone các slide từ template PPTX (giữ nguyên visual gốc), thay data:

| Slide | Clone từ | Nội dung |
|---|---|---|
| Title | Slide 1 template | "Họp UBCS Quý X/YYYY" |
| Nội dung | Slide 2 template | Mục lục |
| Phần 1 — Bảng cây VBCS | Slide 4 template | Khối \| Q4 \| Q1 \| Delta |
| Phần 1 — Donut chart | Slide mới (blank) | Phân bổ VB theo Khối |
| Phần 2 — Bảng tổng quan | Slide 18 template | Khối \| Giữ nguyên \| SĐBS \| Tuyên hủy |
| Phần 2 — Stacked bar chart | Slide mới (blank) | Trạng thái theo Khối |
| Phần 2 — Chi tiết tiến độ | Slide 19 template (×N) | VB có tiến độ thực hiện |

---

## 5. Styling System

Lấy chuẩn từ `Ban Chao Giai phap cho Truong Hoc 2025.pptx`.

**Brand Colors:**
| Role | Hex | Dùng cho |
|---|---|---|
| Navy | `#223A5E` | Header bảng, tiêu đề section, dòng tổng |
| Blue | `#00588F` | Sub-header, border, số nổi bật |
| Red | `#C91F3E` | Tuyên hủy, delta âm |
| Green | `#00B050` | Hoàn thành, delta dương |
| Light blue | `#E4F7FF` | Row xen kẽ bảng |
| White | `#FFFFFF` | Text trên nền tối |

**Font:** Cambria (tiêu đề), Arial (body/bảng)

**Bảng:**
- Header row: nền Navy, chữ trắng, Cambria bold
- Row xen kẽ: nền `#E4F7FF`
- Dòng Cộng/Tổng: nền Navy, chữ trắng, bold
- Tô màu trạng thái: Tuyên hủy → đỏ nhạt `#FFE0E0`, SĐBS → xanh nhạt `#E0F0FF`, Hoàn thành → xanh `#E0FFE8`
- Delta âm → chữ đỏ `#C91F3E`, delta dương → chữ xanh `#00B050`

**Charts:**
- Donut chart (Phần 1): màu từ bảng brand colors, legend bên phải
- Stacked bar chart (Phần 2): 3 màu Navy/Blue/Red cho 3 nhóm trạng thái

---

## 6. Slides Output

Tổng ~12 slides:
1. Title
2. Nội dung
3. Phần 1: Bảng cây VBCS theo Khối
4. Phần 1: Donut chart phân bổ
5. Phần 2: Bảng tổng quan VB>5N
6. Phần 2: Stacked bar chart trạng thái
7–12. Phần 2: Chi tiết VB có tiến độ (8 dòng/slide)

---

## 7. Out of Scope

- Watch folder / daemon tự động
- Phần 3 (Kế hoạch ban hành), Phần 4 (TBKL), Phần 5 (QĐPL) — cần input tường thuật thủ công
- Export PDF
