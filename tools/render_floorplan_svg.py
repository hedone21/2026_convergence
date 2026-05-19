"""floor_*.json → SVG 시각화. 추출 결과 검증용."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from xml.sax.saxutils import escape


def render_svg(floor: dict, out_path: Path) -> None:
    bb = floor["walls_bbox_pt"]
    pad = 40.0
    x0, y0, x1, y1 = bb
    w = (x1 - x0) + 2 * pad
    h = (y1 - y0) + 2 * pad

    parts: list[str] = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0 - pad} {y0 - pad} {w} {h}" '
        f'width="1600" height="{int(1600 * h / w)}">'
    )
    parts.append('<rect x="{}" y="{}" width="{}" height="{}" fill="#fafafa"/>'.format(
        x0 - pad, y0 - pad, w, h))

    # grid lines (light)
    for key, gx in sorted(floor["grid"]["x"].items()):
        parts.append(
            f'<line x1="{gx}" y1="{y0}" x2="{gx}" y2="{y1}" '
            f'stroke="#d0d0e0" stroke-width="2" stroke-dasharray="6,4"/>'
        )
        parts.append(f'<text x="{gx}" y="{y0 - 8}" font-size="20" fill="#6060a0" '
                     f'text-anchor="middle">{escape(key)}</text>')
    for key, gy in sorted(floor["grid"]["y"].items()):
        parts.append(
            f'<line x1="{x0}" y1="{gy}" x2="{x1}" y2="{gy}" '
            f'stroke="#d0d0e0" stroke-width="2" stroke-dasharray="6,4"/>'
        )
        parts.append(f'<text x="{x0 - 12}" y="{gy + 6}" font-size="20" fill="#6060a0" '
                     f'text-anchor="end">{escape(key)}</text>')

    # inner walls (thin)
    for wseg in floor["walls"]:
        if wseg["kind"] != "inner":
            continue
        a, b = wseg["a_pt"], wseg["b_pt"]
        parts.append(
            f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" '
            f'stroke="#888" stroke-width="1.2"/>'
        )
    # outer walls (thick red)
    for wseg in floor["walls"]:
        if wseg["kind"] != "outer":
            continue
        a, b = wseg["a_pt"], wseg["b_pt"]
        parts.append(
            f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" '
            f'stroke="#c0392b" stroke-width="5"/>'
        )

    # cores (STAIRS/ELEVATOR)
    for core in floor["cores"]:
        bx0, by0, bx1, by1 = core["bbox_pt"]
        color = "#27ae60" if core["label"] == "STAIRS" else "#2980b9"
        parts.append(
            f'<rect x="{bx0 - 8}" y="{by0 - 8}" width="{bx1 - bx0 + 16}" '
            f'height="{by1 - by0 + 16}" fill="none" stroke="{color}" stroke-width="3"/>'
        )
        parts.append(
            f'<text x="{bx0}" y="{by0 - 12}" font-size="18" fill="{color}" '
            f'font-weight="bold">{escape(core["text"])}</text>'
        )

    title = floor.get("title") or f"page {floor['page_index']}"
    parts.append(
        f'<text x="{x0}" y="{y1 + pad - 8}" font-size="28" fill="#333" '
        f'font-weight="bold">{escape(title)}</text>'
    )
    counts = floor["wall_counts"]
    parts.append(
        f'<text x="{x0}" y="{y1 + pad + 20}" font-size="18" fill="#555">'
        f'outer={counts["outer"]} inner={counts["inner"]} cores={len(floor["cores"])} '
        f'grid={len(floor["grid"]["x"])}x{len(floor["grid"]["y"])}</text>'
    )
    parts.append('</svg>')
    out_path.write_text("\n".join(parts))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in-dir", default="data/parliament_village")
    parser.add_argument("--out-dir", default="_workspace/floorplan_svg")
    args = parser.parse_args()

    in_dir = Path(args.in_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    for json_path in sorted(in_dir.glob("floor_*.json")):
        floor = json.loads(json_path.read_text())
        out_path = out_dir / (json_path.stem + ".svg")
        render_svg(floor, out_path)
        print(f"렌더링: {json_path.name} → {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
