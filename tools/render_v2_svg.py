"""v2 schema JSON (categories tree) → SVG 시각화."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


COLORS = {
    "outer_walls": "#c0392b",
    "inner_walls": "#7f8c8d",
    "columns":     "#2c3e50",
    "doors":       "#e67e22",
    "windows":     "#3498db",
    "stairs":      "#27ae60",
    "elevators":   "#2980b9",
    "rooms":       "#9b59b6",
    "slabs":       "#bdc3c7",
}


def render(data: dict, out_path: Path, target_w: int = 1600) -> None:
    cats = data["categories"]
    bbox = data["metadata"]["bbox_m"]
    (x0, y0), (x1, y1) = bbox
    pad = (x1 - x0) * 0.05
    x0 -= pad; y0 -= pad; x1 += pad; y1 += pad
    w_m = x1 - x0
    h_m = y1 - y0

    # SVG y-flip (DXF y는 위로, SVG y는 아래로)
    def fy(y): return y1 + y0 - y

    parts: list[str] = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{x0} {y0} {w_m} {h_m}" '
        f'width="{target_w}" height="{int(target_w * h_m / w_m)}">'
    )
    parts.append(f'<rect x="{x0}" y="{y0}" width="{w_m}" height="{h_m}" fill="#fafafa"/>')

    # 1m grid
    gx = math.floor(x0)
    while gx <= x1:
        parts.append(
            f'<line x1="{gx}" y1="{y0}" x2="{gx}" y2="{y1}" '
            f'stroke="#e8e8f0" stroke-width="0.02"/>'
        )
        gx += 1
    gy = math.floor(y0)
    while gy <= y1:
        parts.append(
            f'<line x1="{x0}" y1="{fy(gy)}" x2="{x1}" y2="{fy(gy)}" '
            f'stroke="#e8e8f0" stroke-width="0.02"/>'
        )
        gy += 1

    # slabs (배경)
    for s in cats.get("slabs", []):
        pts = " ".join(f"{p[0]},{fy(p[1])}" for p in s["polygon"])
        parts.append(f'<polygon points="{pts}" fill="{COLORS["slabs"]}" '
                     f'fill-opacity="0.3" stroke="none"/>')

    # inner walls (얇게)
    for w in cats.get("inner_walls", []):
        s, t = w["start"], w["end"]
        parts.append(
            f'<line x1="{s[0]}" y1="{fy(s[1])}" x2="{t[0]}" y2="{fy(t[1])}" '
            f'stroke="{COLORS["inner_walls"]}" stroke-width="0.05"/>'
        )

    # outer walls (굵게)
    for w in cats.get("outer_walls", []):
        s, t = w["start"], w["end"]
        parts.append(
            f'<line x1="{s[0]}" y1="{fy(s[1])}" x2="{t[0]}" y2="{fy(t[1])}" '
            f'stroke="{COLORS["outer_walls"]}" stroke-width="0.15"/>'
        )

    # columns (line segment 또는 position+size 둘 다 지원)
    for c in cats.get("columns", []):
        if "start" in c and "end" in c:
            s, t = c["start"], c["end"]
            parts.append(
                f'<line x1="{s[0]}" y1="{fy(s[1])}" x2="{t[0]}" y2="{fy(t[1])}" '
                f'stroke="{COLORS["columns"]}" stroke-width="0.08"/>'
            )
            continue
        pos = c.get("position", [0, 0])
        size = c.get("size", [0.3, 0.3])
        parts.append(
            f'<rect x="{pos[0] - size[0]/2}" y="{fy(pos[1] + size[1]/2)}" '
            f'width="{size[0]}" height="{size[1]}" '
            f'fill="{COLORS["columns"]}"/>'
        )

    # windows (line segment)
    for w in cats.get("windows", []):
        s, t = w["start"], w["end"]
        parts.append(
            f'<line x1="{s[0]}" y1="{fy(s[1])}" x2="{t[0]}" y2="{fy(t[1])}" '
            f'stroke="{COLORS["windows"]}" stroke-width="0.10"/>'
        )

    # doors (polygon 또는 swing arc 둘 다 지원)
    for d in cats.get("doors", []):
        if "polygon" in d:
            pts = " ".join(f"{p[0]},{fy(p[1])}" for p in d["polygon"])
            parts.append(f'<polygon points="{pts}" fill="{COLORS["doors"]}" '
                         f'fill-opacity="0.4" stroke="{COLORS["doors"]}" stroke-width="0.04"/>')
            continue
        if "hinge" not in d:
            continue
        c = d["hinge"]
        r = d["swing_radius"]
        a0 = d.get("swing_angle_start_deg", 0)
        a1 = d.get("swing_angle_end_deg", 90)
        # SVG arc — y-flip 적용
        # DXF angle: 0=+x, 90=+y (CCW). y-flip 후 SVG: 0=+x, 90=-y 가 되니 angle을 -로
        rad0 = math.radians(a0)
        rad1 = math.radians(a1)
        sx = c[0] + r * math.cos(rad0)
        sy = c[1] + r * math.sin(rad0)
        ex = c[0] + r * math.cos(rad1)
        ey = c[1] + r * math.sin(rad1)
        sweep_deg = (a1 - a0) % 360
        large_arc = 1 if sweep_deg > 180 else 0
        # y-flip 후 sweep 방향 반전
        sweep_flag = 0  # DXF CCW → SVG (y-flip) CW
        parts.append(
            f'<path d="M {c[0]} {fy(c[1])} L {sx} {fy(sy)} '
            f'A {r} {r} 0 {large_arc} {sweep_flag} {ex} {fy(ey)} Z" '
            f'fill="{COLORS["doors"]}" fill-opacity="0.15" '
            f'stroke="{COLORS["doors"]}" stroke-width="0.04"/>'
        )
        # hinge 점
        parts.append(
            f'<circle cx="{c[0]}" cy="{fy(c[1])}" r="0.08" '
            f'fill="{COLORS["doors"]}"/>'
        )

    # rooms (polygon outline + label + area)
    for room in cats.get("rooms", []):
        pts = " ".join(f"{p[0]},{fy(p[1])}" for p in room.get("polygon", []))
        if pts:
            parts.append(
                f'<polygon points="{pts}" fill="{COLORS["rooms"]}" '
                f'fill-opacity="0.08" stroke="{COLORS["rooms"]}" stroke-width="0.03"/>'
            )
        if room.get("label") and room.get("centroid"):
            cx, cy = room["centroid"]
            parts.append(
                f'<text x="{cx}" y="{fy(cy)}" font-size="0.4" '
                f'fill="#5a3475" text-anchor="middle">{room["label"]}</text>'
            )

    # legend
    meta = data["metadata"]
    legend_y = y0 + 0.3
    parts.append(
        f'<text x="{x0 + 0.3}" y="{legend_y}" font-size="0.35" fill="#333" '
        f'font-weight="bold">DXF → v2 SVG  ·  '
        f'bbox: {meta["bbox_m"][0]} to {meta["bbox_m"][1]} m</text>'
    )
    counts = "  ".join(f"{k}={len(cats[k])}" for k in COLORS if cats.get(k))
    parts.append(
        f'<text x="{x0 + 0.3}" y="{legend_y + 0.5}" font-size="0.28" fill="#555">'
        f'{counts}</text>'
    )

    parts.append('</svg>')
    out_path.write_text("\n".join(parts))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="inp", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--width", type=int, default=1600)
    args = parser.parse_args()

    data = json.loads(Path(args.inp).read_text())
    render(data, Path(args.out), target_w=args.width)
    print(f"{args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
