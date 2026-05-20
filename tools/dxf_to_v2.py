"""DXF (AIA layer 표준) → v2 schema JSON 변환.

전제:
- DXF의 layer 이름이 의미를 직접 명시 (A-WALL, A-OPENING, A-FOOTPRINT, S-SLAB 등)
- xref- prefix와 $0$ 구분자는 외부 참조 명명이라 무시하고 마지막 토큰만 매칭
- 단위는 $INSUNITS 헤더로 결정 (1=inch, 4=mm, 6=m). 잘못된 헤더는 wall 길이 분포로 검증

매핑:
- A-FOOTPRINT LWPOLYLINE → outer_walls (polygon edge로 분해)
- A-WALL LINE → inner_walls (단일 layer이므로 외/내 분리는 footprint buffer 기반 추후)
- A-OPENING ARC → doors (center=hinge, radius=swing, angle range=swing arc)
- S-SLAB LWPOLYLINE → slabs
- 나머지 layer는 drop
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

try:
    import ezdxf
except ImportError as exc:
    sys.exit(f"의존성 누락: {exc}. venv 활성화 후 pip install ezdxf")


INSUNITS_TO_METER = {
    1: 0.0254,    # inch
    2: 0.3048,    # foot
    4: 0.001,     # millimeter
    5: 0.01,      # centimeter
    6: 1.0,       # meter
}


LAYER_KIND = {
    # jscad (주택) layer
    "A-WALL": "wall",
    "A-FOOTPRINT": "footprint",
    "A-OPENING": "opening",
    "A-GARAGE-DOOR": "garage_door",
    "A-HEADER": "header",
    "A-CASE-1": "case",
    "A-FIXTURE": "fixture",
    "S-SLAB": "slab",
    "S-FOOTER": "footer",
    "S-STEM-WALL": "stem_wall",
    "R-BEAM": "beam",
    "R-OVERBUILD": "roof",
    "R-OVERHANG": "roof",
    "R-TRUSS": "roof",
    "FF-JOISTS": "joist",
    # Cal Poly (대학 시설) AIA 표준 layer
    "A-DOOR": "door_poly",      # LWPOLYLINE 문 형태
    "A-GLAZ": "window",          # 창문 (glazing)
    "A-COLS": "column",          # 기둥
    "A-FLOR": "floor",           # 바닥 (mark/pattern)
    "A-GRID": "grid",            # 축 grid
    "A-SITE": "site",            # 사이트 경계
    "AREA-ASSIGN": "room",       # 방 영역 polygon
    "AREA-GROSS": "gross_area",  # 전체 면적
    "AREA-TEXT": "area_label",
    "A-IDEN-VNUM": "room_label", # 방 번호
    "A-IDEN-RNUM": "room_label",
    "A-IDEN-SNUM": "room_label",
}


def _layer_kind(layer_name: str) -> str | None:
    """xref-$0$ prefix 벗기고 마지막 의미 토큰만 매칭."""
    base = layer_name.split("$")[-1] if "$" in layer_name else layer_name
    return LAYER_KIND.get(base)


def _make_id(prefix: str, x: float, y: float, bin_size: float = 4.0) -> str:
    bx, by = int(x / bin_size), int(y / bin_size)
    h = hashlib.md5(f"{prefix}{bx},{by}".encode()).hexdigest()[:6].upper()
    return f"{prefix}{h}"


def _decide_unit_scale(doc, sample_wall_lengths: list[float]) -> tuple[float, str]:
    """헤더 + wall 길이 분포로 단위 결정.

    합리적 wall 길이: 0.1m ~ 10m. 이 범위에 median이 들어오는 scale 선택.
    """
    insunits = doc.header.get("$INSUNITS", 0)
    scale = INSUNITS_TO_METER.get(insunits, 0.0254)

    if sample_wall_lengths:
        med = sorted(sample_wall_lengths)[len(sample_wall_lengths) // 2]
        med_m = med * scale
        if not (0.1 <= med_m <= 10.0):
            # 헤더 무시하고 다른 scale 시도
            for s in [0.0254, 0.001, 0.3048, 0.01, 1.0]:
                if 0.1 <= med * s <= 10.0:
                    return s, f"override_by_wall_median (insunits={insunits} → scale={s})"
    note = f"insunits={insunits}"
    return scale, note


def _polygon_edges(pts: list[tuple[float, float]]):
    """polygon vertex sequence → edge pairs (중복 vertex skip)."""
    n = len(pts)
    for i in range(n):
        a = pts[i]
        b = pts[(i + 1) % n]
        if a == b:
            continue
        yield a, b


def convert(dxf_path: Path, out_path: Path) -> dict:
    doc = ezdxf.readfile(dxf_path)
    msp = doc.modelspace()

    # 1차: wall LINE 길이 수집 (단위 결정용)
    wall_lengths = []
    for e in msp.query("LINE"):
        if _layer_kind(e.dxf.layer) == "wall":
            s, t = e.dxf.start, e.dxf.end
            wall_lengths.append(((s[0] - t[0]) ** 2 + (s[1] - t[1]) ** 2) ** 0.5)

    scale, scale_note = _decide_unit_scale(doc, wall_lengths)

    def m(v: float) -> float:
        return round(v * scale, 4)

    categories = {
        "outer_walls": [],
        "inner_walls": [],
        "columns": [],
        "doors": [],
        "windows": [],
        "stairs": [],
        "elevators": [],
        "rooms": [],
        "slabs": [],
    }

    # 2차: A-FOOTPRINT LWPOLYLINE → outer_walls
    footprints_raw = []
    for e in msp.query("LWPOLYLINE"):
        if _layer_kind(e.dxf.layer) == "footprint":
            pts = [(p[0], p[1]) for p in e.get_points("xy")]
            footprints_raw.append(pts)
            for a, b in _polygon_edges(pts):
                cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                categories["outer_walls"].append({
                    "id": _make_id("W", cx, cy),
                    "start": [m(a[0]), m(a[1])],
                    "end": [m(b[0]), m(b[1])],
                    "side": "outer",
                    "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LWPOLYLINE_EDGE"},
                })

    # 3차: A-WALL LINE → inner_walls
    for e in msp.query("LINE"):
        if _layer_kind(e.dxf.layer) == "wall":
            s, t = e.dxf.start, e.dxf.end
            cx, cy = (s[0] + t[0]) / 2, (s[1] + t[1]) / 2
            categories["inner_walls"].append({
                "id": _make_id("W", cx, cy),
                "start": [m(s[0]), m(s[1])],
                "end": [m(t[0]), m(t[1])],
                "side": "inner",
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LINE"},
            })

    # 4차: A-OPENING ARC → doors
    for e in msp.query("ARC"):
        if _layer_kind(e.dxf.layer) == "opening":
            c = e.dxf.center
            categories["doors"].append({
                "id": _make_id("D", c[0], c[1]),
                "hinge": [m(c[0]), m(c[1])],
                "swing_radius": m(e.dxf.radius),
                "swing_angle_start_deg": e.dxf.start_angle,
                "swing_angle_end_deg": e.dxf.end_angle,
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "ARC"},
            })

    # 5차: S-SLAB LWPOLYLINE → slabs
    for e in msp.query("LWPOLYLINE"):
        if _layer_kind(e.dxf.layer) == "slab":
            pts = [(p[0], p[1]) for p in e.get_points("xy")]
            polygon_m = [[m(p[0]), m(p[1])] for p in pts]
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            categories["slabs"].append({
                "id": _make_id("S", cx, cy),
                "polygon": polygon_m,
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LWPOLYLINE"},
            })

    # 6차: A-DOOR LWPOLYLINE → doors (polygon + hinge/axis/span 추출)
    # 4 vertex + bulge 구조 가정: 직선 edge들(bulge=0) 중 가장 긴 것이 door frame (벽 따라).
    for e in msp.query("LWPOLYLINE"):
        if _layer_kind(e.dxf.layer) == "door_poly":
            pts_xyseb = list(e.get_points("xyseb"))
            if not pts_xyseb:
                continue
            pts = [(p[0], p[1]) for p in pts_xyseb]
            bulges = [p[4] for p in pts_xyseb]
            n = len(pts)
            cx = sum(p[0] for p in pts) / n
            cy = sum(p[1] for p in pts) / n

            # 모든 edge (호 chord 포함) 수집
            all_edges: list[tuple[float, int, tuple[float, float], tuple[float, float]]] = []
            for i in range(n):
                a = pts[i]
                b = pts[(i + 1) % n]
                L = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
                all_edges.append((L, i, a, b))

            # 가장 짧은 edge = frame 두께 표현 (v1→v2 ≈ 0.75 inch).
            # 그 *반대편 edge* (인덱스 +2) = door slab 닫힘 위치 = wall axis.
            shortest = min(all_edges, key=lambda x: x[0])
            opp_idx = (shortest[1] + 2) % n
            opp_L, _, oa, ob = all_edges[opp_idx]
            hinge_x = (oa[0] + ob[0]) * 0.5
            hinge_y = (oa[1] + ob[1]) * 0.5
            axis_x = (ob[0] - oa[0]) / opp_L if opp_L > 1e-6 else 1.0
            axis_y = (ob[1] - oa[1]) / opp_L if opp_L > 1e-6 else 0.0
            longest_L = opp_L

            categories["doors"].append({
                "id": _make_id("D", cx, cy),
                "polygon": [[m(p[0]), m(p[1])] for p in pts],
                "centroid": [m(cx), m(cy)],
                "hinge": [m(hinge_x), m(hinge_y)],
                "axis": [round(axis_x, 6), round(axis_y, 6)],
                "span_m": round(longest_L * scale, 4),
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LWPOLYLINE"},
            })

    # 7차: A-GLAZ LINE → windows
    for e in msp.query("LINE"):
        if _layer_kind(e.dxf.layer) == "window":
            s, t = e.dxf.start, e.dxf.end
            cx, cy = (s[0] + t[0]) / 2, (s[1] + t[1]) / 2
            categories["windows"].append({
                "id": _make_id("G", cx, cy),
                "start": [m(s[0]), m(s[1])],
                "end": [m(t[0]), m(t[1])],
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LINE"},
            })

    # 8차: A-COLS LINE → columns (segment 단위 — 보통 사각형 외곽 4 line)
    for e in msp.query("LINE"):
        if _layer_kind(e.dxf.layer) == "column":
            s, t = e.dxf.start, e.dxf.end
            cx, cy = (s[0] + t[0]) / 2, (s[1] + t[1]) / 2
            categories["columns"].append({
                "id": _make_id("C", cx, cy),
                "start": [m(s[0]), m(s[1])],
                "end": [m(t[0]), m(t[1])],
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LINE"},
            })

    # 9차: AREA-ASSIGN LWPOLYLINE → rooms
    for e in msp.query("LWPOLYLINE"):
        if _layer_kind(e.dxf.layer) == "room":
            pts = [(p[0], p[1]) for p in e.get_points("xy")]
            if len(pts) < 3:
                continue
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            # signed area
            area = 0.0
            for i in range(len(pts)):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % len(pts)]
                area += x1 * y2 - x2 * y1
            area_m2 = abs(area / 2) * scale * scale
            categories["rooms"].append({
                "id": _make_id("R", cx, cy),
                "polygon": [[m(p[0]), m(p[1])] for p in pts],
                "centroid": [m(cx), m(cy)],
                "area_m2": round(area_m2, 2),
                "label": None,
                "source": {"dxf_layer": e.dxf.layer, "dxf_type": "LWPOLYLINE"},
            })

    # 10차: A-IDEN-VNUM TEXT → room label, room centroid에 가장 가까운 room으로 매칭
    room_labels = []
    for e in msp.query("TEXT"):
        if _layer_kind(e.dxf.layer) == "room_label":
            pos = e.dxf.insert
            txt = e.dxf.text
            room_labels.append((pos[0], pos[1], txt))
    # nearest room 매칭
    for room in categories["rooms"]:
        cx_m, cy_m = room["centroid"]
        best = None
        best_d = float("inf")
        for (lx, ly, txt) in room_labels:
            lx_m, ly_m = lx * scale, ly * scale
            d = ((lx_m - cx_m) ** 2 + (ly_m - cy_m) ** 2) ** 0.5
            if d < best_d:
                best_d = d
                best = txt
        if best is not None and best_d < 5.0:  # 5m 이내
            room["label"] = best

    # metadata + origin shift (state plane / 큰 절대좌표 → 0 기반)
    extmin = doc.header.get("$EXTMIN", (0, 0, 0))
    extmax = doc.header.get("$EXTMAX", (0, 0, 0))
    ox_m = m(extmin[0])
    oy_m = m(extmin[1])
    needs_shift = abs(ox_m) > 1000 or abs(oy_m) > 1000
    if needs_shift:
        for key in categories:
            for el in categories[key]:
                if "start" in el:
                    el["start"][0] -= ox_m
                    el["start"][1] -= oy_m
                if "end" in el:
                    el["end"][0] -= ox_m
                    el["end"][1] -= oy_m
                if "polygon" in el:
                    for p in el["polygon"]:
                        p[0] -= ox_m
                        p[1] -= oy_m
                if "centroid" in el:
                    el["centroid"][0] -= ox_m
                    el["centroid"][1] -= oy_m
                if "hinge" in el:
                    el["hinge"][0] -= ox_m
                    el["hinge"][1] -= oy_m

    result = {
        "metadata": {
            "schema_version": "2.0",
            "source": {
                "format": "DXF",
                "path": str(dxf_path),
                "ezdxf_version": ezdxf.__version__,
                "dxf_version": doc.dxfversion,
                "$INSUNITS": doc.header.get("$INSUNITS"),
                "$MEASUREMENT": doc.header.get("$MEASUREMENT"),
                "unit_scale_to_meter": scale,
                "unit_scale_note": scale_note,
            },
            "bbox_m": [
                [0.0, 0.0] if needs_shift else [m(extmin[0]), m(extmin[1])],
                [round(m(extmax[0]) - ox_m, 4), round(m(extmax[1]) - oy_m, 4)]
                if needs_shift else [m(extmax[0]), m(extmax[1])],
            ],
            "origin_shift_applied": needs_shift,
            "origin_offset_m": [ox_m, oy_m] if needs_shift else [0, 0],
            "footprint_polygon_count": len(footprints_raw),
        },
        "categories": categories,
    }

    Path(out_path).write_text(json.dumps(result, indent=2, ensure_ascii=False))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dxf", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    result = convert(Path(args.dxf), Path(args.out))
    cats = result["categories"]
    meta = result["metadata"]

    print(f"=== {args.out} ===")
    print(f"  dxf_version: {meta['source']['dxf_version']}")
    print(f"  unit_scale_to_meter: {meta['source']['unit_scale_to_meter']} ({meta['source']['unit_scale_note']})")
    print(f"  bbox_m: {meta['bbox_m']}")
    print(f"  outer_walls:  {len(cats['outer_walls'])}")
    print(f"  inner_walls:  {len(cats['inner_walls'])}")
    print(f"  columns:      {len(cats['columns'])}")
    print(f"  doors:        {len(cats['doors'])}")
    print(f"  windows:      {len(cats['windows'])}")
    print(f"  rooms:        {len(cats['rooms'])}")
    print(f"  slabs:        {len(cats['slabs'])}")
    labeled = sum(1 for r in cats['rooms'] if r.get('label'))
    print(f"  rooms labeled: {labeled}/{len(cats['rooms'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
