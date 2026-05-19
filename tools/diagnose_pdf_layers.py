"""PDF의 raw drawings를 type / stroke_width / stroke_color 기반으로 분류 후 SVG로 시각화.

추출기 재작성을 위한 진단 도구. extract_floorplan.py와 별개로 동작 — 휴리스틱 적용 전
원본 drawings의 의미 단서(굵기, 색, 채움 여부)가 도면 위에 실제로 어떻게 분포하는지 확인.

분류 기준 (PoC):
  - type='f' (채움) + rect    → 기둥 (검정 채움)
  - stroke_width >= 1.92      → 외벽 (빨강)
  - 1.32 <= stroke_width <1.92→ 벽 (주황)
  - 0.6  <= stroke_width <1.32→ 일반 선 (회색)
  - stroke_width < 0.6        → 보조선 (옅은 회색)
  - stroke_color = 올리브      → 가구/주석 layer (파랑, 분리)
"""

from __future__ import annotations

import argparse
from pathlib import Path

try:
    import fitz  # pymupdf
except ImportError:
    import sys
    sys.exit("pymupdf(fitz) 모듈이 필요합니다: pip install pymupdf")


# 분류 임계값
WIDTH_OUTER_WALL: float = 1.92
WIDTH_WALL: float = 1.32
WIDTH_THIN: float = 0.6

# 올리브 layer 색상 (가구/주석)
OLIVE_RGB: tuple[float, float, float] = (0.5, 0.5, 0.0)
OLIVE_TOLERANCE: float = 0.02


# 카테고리별 시각화 색상
COLOR_COLUMN: str = "#000000"           # 채움 rect
COLOR_OUTER_WALL: str = "#c0392b"       # 빨강
COLOR_WALL: str = "#e67e22"             # 주황
COLOR_LINE_NORMAL: str = "#7f8c8d"      # 회색
COLOR_LINE_THIN: str = "#d0d0d0"        # 옅은 회색
COLOR_OLIVE_LAYER: str = "#3498db"      # 파랑 (가구/주석)
COLOR_OTHER: str = "#9b59b6"            # 보라 (분류 안 됨)


def _is_olive(color: tuple[float, float, float] | None) -> bool:
    if color is None:
        return False
    return all(abs(color[i] - OLIVE_RGB[i]) < OLIVE_TOLERANCE for i in range(3))


def _classify(drawing: dict) -> str:
    """drawing → 카테고리 문자열."""
    dtype = drawing.get("type", "")
    color = drawing.get("color")
    width = drawing.get("width") or 0.0

    # 채움 rect = 기둥
    if dtype == "f":
        return "column"

    # 올리브 layer = 가구/주석
    if _is_olive(color):
        return "olive"

    # stroke width 기준
    if width >= WIDTH_OUTER_WALL:
        return "outer_wall"
    if width >= WIDTH_WALL:
        return "wall"
    if width >= WIDTH_THIN:
        return "line_normal"
    if width > 0:
        return "line_thin"

    return "other"


def _category_color(cat: str) -> str:
    return {
        "column": COLOR_COLUMN,
        "outer_wall": COLOR_OUTER_WALL,
        "wall": COLOR_WALL,
        "line_normal": COLOR_LINE_NORMAL,
        "line_thin": COLOR_LINE_THIN,
        "olive": COLOR_OLIVE_LAYER,
        "other": COLOR_OTHER,
    }.get(cat, COLOR_OTHER)


def _category_stroke_width(cat: str) -> float:
    return {
        "outer_wall": 3.5,
        "wall": 2.5,
        "line_normal": 1.2,
        "line_thin": 0.6,
        "olive": 1.0,
        "other": 1.0,
    }.get(cat, 1.0)


def _render_items(items: list, cat: str) -> list[str]:
    """drawing.items → SVG element 문자열들."""
    color = _category_color(cat)
    stroke_w = _category_stroke_width(cat)
    out: list[str] = []
    for it in items:
        kind = it[0]
        if kind == "l":
            p1, p2 = it[1], it[2]
            out.append(
                f'<line x1="{p1.x:.2f}" y1="{p1.y:.2f}" '
                f'x2="{p2.x:.2f}" y2="{p2.y:.2f}" '
                f'stroke="{color}" stroke-width="{stroke_w}" stroke-linecap="round"/>'
            )
        elif kind == "re":
            r = it[1]
            if cat == "column":
                out.append(
                    f'<rect x="{r.x0:.2f}" y="{r.y0:.2f}" '
                    f'width="{r.width:.2f}" height="{r.height:.2f}" '
                    f'fill="{color}" stroke="none"/>'
                )
            else:
                out.append(
                    f'<rect x="{r.x0:.2f}" y="{r.y0:.2f}" '
                    f'width="{r.width:.2f}" height="{r.height:.2f}" '
                    f'fill="none" stroke="{color}" stroke-width="{stroke_w}"/>'
                )
        elif kind == "qu":
            q = it[1]
            # winding: ul → ur → lr → ll
            out.append(
                f'<polygon points="{q.ul.x:.2f},{q.ul.y:.2f} {q.ur.x:.2f},{q.ur.y:.2f} '
                f'{q.lr.x:.2f},{q.lr.y:.2f} {q.ll.x:.2f},{q.ll.y:.2f}" '
                f'fill="{color}" stroke="{color}" stroke-width="{stroke_w}"/>'
            )
        elif kind == "c":
            if len(it) < 5:
                continue
            p0, p1, p2, p3 = it[1], it[2], it[3], it[4]
            out.append(
                f'<path d="M {p0.x:.2f} {p0.y:.2f} '
                f'C {p1.x:.2f} {p1.y:.2f}, {p2.x:.2f} {p2.y:.2f}, '
                f'{p3.x:.2f} {p3.y:.2f}" '
                f'fill="none" stroke="{color}" stroke-width="{stroke_w}"/>'
            )
    return out


def _compute_content_bbox(drawings: list) -> tuple[float, float, float, float] | None:
    """페이지 테두리(width≥1.92)를 제외한 본문 drawings의 bbox."""
    xs: list[float] = []
    ys: list[float] = []
    for d in drawings:
        # 페이지 테두리 후보(매우 굵은 stroke)는 bbox 계산에서 제외
        if (d.get("width") or 0.0) >= WIDTH_OUTER_WALL:
            continue
        r = d.get("rect")
        if r is None:
            continue
        xs.extend([r.x0, r.x1])
        ys.extend([r.y0, r.y1])
    if not xs:
        return None
    return (min(xs), min(ys), max(xs), max(ys))


def render_page(page, out_path: Path, page_label: str) -> dict[str, int]:
    """단일 페이지를 카테고리별로 분류해 SVG 출력. 카운트 반환."""
    drawings = page.get_drawings()
    pad = 30.0

    # 본문 영역으로 crop (페이지 테두리 제외)
    bbox = _compute_content_bbox(drawings)
    if bbox is None:
        rect = page.rect
        vb_x0, vb_y0, vb_w, vb_h = 0.0, 0.0, rect.width, rect.height
    else:
        bx0, by0, bx1, by1 = bbox
        vb_x0 = bx0 - pad
        vb_y0 = by0 - pad
        vb_w = (bx1 - bx0) + 2 * pad
        vb_h = (by1 - by0) + 2 * pad

    categories: dict[str, list[str]] = {
        "line_thin": [],
        "line_normal": [],
        "olive": [],
        "wall": [],
        "outer_wall": [],
        "column": [],
        "other": [],
    }
    counts: dict[str, int] = {k: 0 for k in categories}

    for d in drawings:
        cat = _classify(d)
        counts[cat] += 1
        elems = _render_items(d.get("items", []), cat)
        categories[cat].extend(elems)

    parts: list[str] = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{vb_x0:.1f} {vb_y0:.1f} {vb_w:.1f} {vb_h:.1f}" '
        f'width="2000" height="{int(2000 * vb_h / vb_w)}">'
    )
    parts.append(
        f'<rect x="{vb_x0:.1f}" y="{vb_y0:.1f}" width="{vb_w:.1f}" '
        f'height="{vb_h:.1f}" fill="#fafafa"/>'
    )

    # z-order: thin → normal → olive → wall → outer_wall → column → other
    for cat in ["line_thin", "line_normal", "olive", "wall", "outer_wall", "column", "other"]:
        if categories[cat]:
            parts.append(f'<g id="cat-{cat}" data-count="{counts[cat]}">')
            parts.extend(categories[cat])
            parts.append('</g>')

    # 범례 (viewBox 하단)
    legend_y = vb_y0 + vb_h + 40
    legend_items = [
        ("column", "기둥 (채움 rect)"),
        ("outer_wall", f"외벽 width≥{WIDTH_OUTER_WALL}"),
        ("wall", f"벽 width≥{WIDTH_WALL}"),
        ("line_normal", f"일반선 width≥{WIDTH_THIN}"),
        ("line_thin", f"보조선 width&lt;{WIDTH_THIN}"),
        ("olive", "올리브 layer (가구/주석)"),
        ("other", "분류 안 됨"),
    ]
    legend_x = vb_x0 + 20
    for i, (cat, label) in enumerate(legend_items):
        cy = legend_y + i * 28
        cnt = counts[cat]
        c = _category_color(cat)
        parts.append(
            f'<rect x="{legend_x}" y="{cy - 10}" width="30" height="14" fill="{c}"/>'
            f'<text x="{legend_x + 40}" y="{cy}" font-size="16" fill="#222">{label} : {cnt:,}</text>'
        )

    parts.append(
        f'<text x="{vb_x0 + 20}" y="{vb_y0 + 30}" font-size="24" fill="#111" '
        f'font-weight="bold">{page_label}</text>'
    )
    parts.append('</svg>')

    out_path.write_text("\n".join(parts))
    return counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", default="/home/go/Downloads/Parliament-Village.pdf")
    parser.add_argument("--out-dir", default="_workspace/diagnosis/pdf_layers")
    parser.add_argument("--page", type=int, default=-1,
                        help="특정 페이지만(0-based). -1이면 전체.")
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    if not pdf_path.exists():
        return print(f"PDF 없음: {pdf_path}") or 1

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    doc = fitz.open(pdf_path)
    pages = [args.page] if args.page >= 0 else list(range(doc.page_count))

    print(f"PDF: {pdf_path}")
    print(f"OUT: {out_dir}")
    print(f"임계값: outer≥{WIDTH_OUTER_WALL}, wall≥{WIDTH_WALL}, thin≥{WIDTH_THIN}")
    print()
    for pi in pages:
        page = doc[pi]
        label = f"floor_{pi + 1:02d}"
        out_path = out_dir / f"{label}_diagnosis.svg"
        counts = render_page(page, out_path, label)
        total = sum(counts.values())
        print(f"  {label}: total={total:,}  →  {out_path.name}")
        for cat, c in counts.items():
            print(f"      {cat:>14}: {c:>7,}")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
