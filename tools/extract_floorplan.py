"""Parliament Village South Hall PDF → floorplan JSON 변환.

- 4페이지(층) 일괄 처리
- 굵은 stroke(>=1.0pt) line segment만 추출 → 골조 벽 후보
- STAIRS/ELEVATOR 라벨 bbox → 코어
- 1~8, A~F 그리드 라벨 → 기둥 교점

축척:
- 도면 1/8" = 1'-0"  → 도면 1pt(=1/72in) 는 실제 (96/72)in = (4/3)in
- 실제 미터 = pdf_pt * (4/3) * 0.0254
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import fitz  # pymupdf
except ImportError:
    sys.exit("pymupdf(fitz) 모듈이 필요합니다: pip install pymupdf")


PDF_PATH_DEFAULT = "/home/go/Downloads/Parliament-Village.pdf"

PDF_PT_TO_REAL_INCH = 96.0 / 72.0
INCH_TO_METER = 0.0254
PDF_PT_TO_METER = PDF_PT_TO_REAL_INCH * INCH_TO_METER

OUTER_WALL_WIDTH_MIN_PT = 1.3
INNER_WALL_WIDTH_MIN_PT = 0.9
# Legend(우상단 미니맵 + 타이틀블록) 영역 — 이 안에 들어가는 walls는 제외
LEGEND_EXCLUDE_RECT_PT = (2650.0, 0.0, 3024.0, 2160.0)
GRID_X_LABELS = ("1", "2", "3", "4", "5", "6", "7", "8")
GRID_Y_LABELS = ("A", "B", "C", "D", "E", "F")
CORE_LABELS = ("STAIRS", "ELEVATOR")
GRID_X_BAND_PT = 60.0   # X 라벨: 페이지 상/하 가장자리 띠
GRID_Y_LEFT_BAND_PT = 150.0  # Y 라벨: 페이지 좌측 띠. 우측은 Legend라 제외
GRID_LABEL_FONT_SIZE_MAX = 11.5  # 도면 외곽 grid 라벨은 ~11pt. 우상단 Legend는 12.6pt


def classify_wall(width_pt: float) -> str | None:
    if width_pt >= OUTER_WALL_WIDTH_MIN_PT:
        return "outer"
    if width_pt >= INNER_WALL_WIDTH_MIN_PT:
        return "inner"
    return None


def _in_legend(x: float, y: float) -> bool:
    lx0, ly0, lx1, ly1 = LEGEND_EXCLUDE_RECT_PT
    return lx0 <= x <= lx1 and ly0 <= y <= ly1


def _segment_in_legend(ax: float, ay: float, bx: float, by: float) -> bool:
    # 두 끝점 모두 Legend 영역 안이면 제외
    return _in_legend(ax, ay) and _in_legend(bx, by)


def extract_walls(drawings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    walls: list[dict[str, Any]] = []
    for d in drawings:
        width_pt = d.get("width") or 0.0
        kind = classify_wall(width_pt)
        if kind is None:
            continue
        for item in d.get("items", []):
            op = item[0]
            if op == "l":
                p0, p1 = item[1], item[2]
                if _segment_in_legend(p0.x, p0.y, p1.x, p1.y):
                    continue
                walls.append({
                    "a_pt": [round(p0.x, 3), round(p0.y, 3)],
                    "b_pt": [round(p1.x, 3), round(p1.y, 3)],
                    "width_pt": round(width_pt, 3),
                    "kind": kind,
                })
            elif op == "re":
                rect = item[1]
                x0, y0, x1, y1 = rect.x0, rect.y0, rect.x1, rect.y1
                if _segment_in_legend(x0, y0, x1, y1):
                    continue
                corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
                for i in range(4):
                    a = corners[i]
                    b = corners[(i + 1) % 4]
                    walls.append({
                        "a_pt": [round(a[0], 3), round(a[1], 3)],
                        "b_pt": [round(b[0], 3), round(b[1], 3)],
                        "width_pt": round(width_pt, 3),
                        "kind": kind,
                    })
    return walls


def extract_text_spans(page: fitz.Page) -> list[dict[str, Any]]:
    spans: list[dict[str, Any]] = []
    for block in page.get_text("dict").get("blocks", []):
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                text = span.get("text", "").strip()
                if not text:
                    continue
                spans.append({
                    "text": text,
                    "bbox": list(span.get("bbox")),
                    "size": span.get("size"),
                })
    return spans


def extract_cores(spans: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cores: list[dict[str, Any]] = []
    for s in spans:
        upper = s["text"].upper()
        for label in CORE_LABELS:
            if upper == label or upper.startswith(label + " ") or upper.startswith(label + "-"):
                cores.append({
                    "label": label,
                    "text": s["text"],
                    "bbox_pt": s["bbox"],
                })
                break
    return cores


def extract_grid(spans: list[dict[str, Any]], page_rect: fitz.Rect) -> dict[str, Any]:
    """페이지 상하 GRID_LABEL_BAND_PT 띠에서 1~8을, 좌우 띠에서 A~F를 찾는다."""
    grid_x_candidates: dict[str, list[float]] = {k: [] for k in GRID_X_LABELS}
    grid_y_candidates: dict[str, list[float]] = {k: [] for k in GRID_Y_LABELS}

    top = page_rect.y0 + GRID_X_BAND_PT
    bottom = page_rect.y1 - GRID_X_BAND_PT
    left = page_rect.x0 + GRID_Y_LEFT_BAND_PT

    grid_x_re = re.compile(r"^[1-8]$")
    grid_y_re = re.compile(r"^[A-F]$")

    for s in spans:
        text = s["text"].strip()
        size = s.get("size") or 0.0
        if size > GRID_LABEL_FONT_SIZE_MAX:
            continue
        bx0, by0, bx1, by1 = s["bbox"]
        cx = (bx0 + bx1) / 2
        cy = (by0 + by1) / 2
        if grid_x_re.match(text) and (cy < top or cy > bottom):
            grid_x_candidates[text].append(cx)
        elif grid_y_re.match(text) and cx < left:
            grid_y_candidates[text].append(cy)

    grid_x = {}
    for k, xs in grid_x_candidates.items():
        if xs:
            grid_x[k] = round(sum(xs) / len(xs), 3)
    grid_y = {}
    for k, ys in grid_y_candidates.items():
        if ys:
            grid_y[k] = round(sum(ys) / len(ys), 3)
    return {"x": grid_x, "y": grid_y}


def process_page(page: fitz.Page, page_index: int) -> dict[str, Any]:
    drawings = page.get_drawings()
    spans = extract_text_spans(page)
    walls = extract_walls(drawings)
    cores = extract_cores(spans)
    grid = extract_grid(spans, page.rect)

    title_match = next((s["text"] for s in spans if "FLOOR PLAN" in s["text"].upper()), None)

    walls_bbox: list[float] | None = None
    for w in walls:
        ax, ay = w["a_pt"]
        bx, by = w["b_pt"]
        if walls_bbox is None:
            walls_bbox = [min(ax, bx), min(ay, by), max(ax, bx), max(ay, by)]
        else:
            walls_bbox[0] = min(walls_bbox[0], ax, bx)
            walls_bbox[1] = min(walls_bbox[1], ay, by)
            walls_bbox[2] = max(walls_bbox[2], ax, bx)
            walls_bbox[3] = max(walls_bbox[3], ay, by)

    return {
        "page_index": page_index,
        "title": title_match,
        "page_rect_pt": list(page.rect),
        "walls_bbox_pt": walls_bbox,
        "scale": {
            "pdf_pt_to_real_inch": PDF_PT_TO_REAL_INCH,
            "pdf_pt_to_meter": PDF_PT_TO_METER,
        },
        "walls": walls,
        "wall_counts": {
            "outer": sum(1 for w in walls if w["kind"] == "outer"),
            "inner": sum(1 for w in walls if w["kind"] == "inner"),
        },
        "cores": cores,
        "grid": grid,
    }


def write_per_floor(summary: dict[str, Any], out_dir: Path) -> Path:
    floor_label = summary["title"] or f"floor_{summary['page_index']:02d}"
    match = re.search(r"LEVEL\s*(\d+)", floor_label.upper())
    floor_num = match.group(1) if match else f"{summary['page_index']:02d}"
    out_path = out_dir / f"floor_{floor_num}.json"
    out_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    return out_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Parliament Village PDF → floorplan JSON")
    parser.add_argument("--pdf", default=PDF_PATH_DEFAULT)
    parser.add_argument(
        "--out-dir",
        default="data/parliament_village",
        help="층별 JSON 저장 디렉토리",
    )
    parser.add_argument("--summary", default=None, help="요약 통계 JSON 경로 (선택)")
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    if not pdf_path.exists():
        sys.exit(f"PDF를 찾을 수 없습니다: {pdf_path}")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    doc = fitz.open(pdf_path)
    floor_summaries: list[dict[str, Any]] = []
    for i, page in enumerate(doc):
        summary = process_page(page, i)
        out_path = write_per_floor(summary, out_dir)
        floor_summaries.append({
            "page": i,
            "title": summary["title"],
            "out": str(out_path),
            "wall_outer": summary["wall_counts"]["outer"],
            "wall_inner": summary["wall_counts"]["inner"],
            "cores": len(summary["cores"]),
            "grid_x": len(summary["grid"]["x"]),
            "grid_y": len(summary["grid"]["y"]),
            "bbox_pt": summary["walls_bbox_pt"],
        })

    print(f"PDF: {pdf_path}")
    print(f"출력 디렉토리: {out_dir}")
    print("=" * 78)
    print(f"{'page':>4} | {'title':<32} | {'outer':>5} {'inner':>5} {'cores':>5} {'gx':>3} {'gy':>3}")
    print("-" * 78)
    for s in floor_summaries:
        print(
            f"{s['page']:>4} | {(s['title'] or '')[:32]:<32} | "
            f"{s['wall_outer']:>5} {s['wall_inner']:>5} {s['cores']:>5} {s['grid_x']:>3} {s['grid_y']:>3}"
        )
    if args.summary:
        Path(args.summary).write_text(json.dumps(floor_summaries, indent=2, ensure_ascii=False))
        print(f"\n요약: {args.summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
