"""floor JSON (SiteData v1/v2) 정적 무결성 검사.

추출기(dxf_to_v2.py / extract_floorplan.py) 직후 자동 실행하여 시각 검증 전
구조적 오류를 콘솔로 보고. *경고만*, 자동 수정/실패 종료 없음.

검증 항목 (D7):
  V1  orphan walls       — 양쪽 endpoint 모두 다른 wall과 연결 안 된 고립 segment
  V2  0-hit doors        — hinge 근방에 wall 없음 (벽에 매달리지 않은 문)
  V3  boundary cycle     — outer_walls가 boundary_polygon edge와 매칭되는 비율
  V4  column-wall overlap— column 중심이 wall 위 (≤ 5cm)에 올라탄 케이스

종료 코드 = warning 수 (0이면 깨끗). CI 통합 가능하나 fail 아님.

사용:
  python tools/validate_floorplan.py data/calpoly_b001/floor_1.json
  python tools/validate_floorplan.py data/calpoly_b001/
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path


# 임계값 — 합리적 default. --loose / --strict 옵션으로 미세조정 가능.
ENDPOINT_BIN_M = 0.05            # 5cm 격자로 endpoint 클러스터링
SHORT_WALL_THRESHOLD_M = 0.20    # 짧은 벽 정보성 보고 (orphan 동시 보고)
DOOR_HIT_MAX_M = 0.50            # hinge에서 wall까지 거리 임계
COLUMN_OVERLAP_PERP_M = 0.05     # column 중심이 wall에서 5cm 이내면 overlap
BOUNDARY_MATCH_PERP_M = 0.30     # outer_wall이 boundary edge에 평행+근접 판정
BOUNDARY_MATCH_ANGLE_DEG = 3.0
BOUNDARY_MATCH_RATIO_WARN = 0.90 # 매칭률이 90% 미만이면 경고


@dataclass
class Warning:
    code: str           # "V1" / "V2" / "V3" / "V4"
    element_id: str     # 대상 객체 ID ("" if N/A)
    message: str        # 사람 읽는 메시지
    severity: str = "warn"  # "warn" | "info"


# ────────────────────────────────────────────────────────────────
# Geometry helpers
# ────────────────────────────────────────────────────────────────


def _bin_key(x: float, y: float, bin_m: float = ENDPOINT_BIN_M) -> tuple[int, int]:
    return (int(round(x / bin_m)), int(round(y / bin_m)))


def _seg_len(s: list[float], e: list[float]) -> float:
    return math.hypot(e[0] - s[0], e[1] - s[1])


def _point_to_segment_distance(px: float, py: float,
                               ax: float, ay: float,
                               bx: float, by: float) -> float:
    """point P → segment AB 최단 거리."""
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-12:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def _segment_parallel_close(seg_a: tuple[list[float], list[float]],
                            seg_b: tuple[list[float], list[float]],
                            perp_tol_m: float,
                            angle_tol_deg: float) -> bool:
    """두 segment가 평행 + 수직거리 perp_tol 안 + along projection 겹침."""
    a0, a1 = seg_a
    b0, b1 = seg_b
    adx, ady = a1[0] - a0[0], a1[1] - a0[1]
    bdx, bdy = b1[0] - b0[0], b1[1] - b0[1]
    aL = math.hypot(adx, ady)
    bL = math.hypot(bdx, bdy)
    if aL < 1e-6 or bL < 1e-6:
        return False
    ang_a = math.atan2(ady, adx) % math.pi
    ang_b = math.atan2(bdy, bdx) % math.pi
    ang_diff = abs(ang_a - ang_b)
    if ang_diff > math.pi - math.radians(angle_tol_deg):
        ang_diff = abs(math.pi - ang_diff)
    if ang_diff > math.radians(angle_tol_deg):
        return False
    # a의 중점 → b에 대한 수직거리
    cos_b, sin_b = math.cos(ang_b), math.sin(ang_b)
    d_b = -sin_b * b0[0] + cos_b * b0[1]
    amx, amy = (a0[0] + a1[0]) * 0.5, (a0[1] + a1[1]) * 0.5
    d_am = -sin_b * amx + cos_b * amy
    return abs(d_am - d_b) <= perp_tol_m


# ────────────────────────────────────────────────────────────────
# Schema dispatch
# ────────────────────────────────────────────────────────────────


def _is_v2(data: dict) -> bool:
    meta = data.get("metadata", {})
    return str(meta.get("schema_version", "")).startswith("2") and "categories" in data


def _collect_walls(data: dict) -> tuple[list[dict], list[dict]]:
    """(outer, inner) wall list with start/end normalized to list[float]."""
    if _is_v2(data):
        cats = data["categories"]
        return cats.get("outer_walls", []), cats.get("inner_walls", [])
    # v1 (parliament): walls.kind로 분기
    outer, inner = [], []
    scale = float(data.get("pdf_pt_to_meter", data.get("unit_scale_to_meter", 1.0)))
    for w in data.get("walls", []):
        kind = w.get("kind", "inner")
        if kind == "column":
            continue
        a = w.get("a_pt") or w.get("start")
        b = w.get("b_pt") or w.get("end")
        if a is None or b is None:
            continue
        # v1 pt → m 변환
        s = [a[0] * scale, a[1] * scale] if w.get("a_pt") else list(a)
        e = [b[0] * scale, b[1] * scale] if w.get("b_pt") else list(b)
        entry = {"id": w.get("id", ""), "start": s, "end": e, "side": kind}
        (outer if kind == "outer" else inner).append(entry)
    return outer, inner


def _collect_doors(data: dict) -> list[dict]:
    if _is_v2(data):
        return data["categories"].get("doors", [])
    return data.get("doors", [])


def _collect_columns(data: dict) -> list[dict]:
    if _is_v2(data):
        return data["categories"].get("columns", [])
    return []  # v1은 column이 grid 교차점, 별도 처리 안 함


def _collect_boundary(data: dict) -> list[list[list[float]]]:
    """polygon list (각 polygon은 [[x,y],...])."""
    if _is_v2(data):
        return [b["polygon"] for b in data["categories"].get("boundary_polygon", [])]
    # v1은 walls_bbox_pt를 단일 사각형 polygon으로
    bb = data.get("walls_bbox_pt")
    scale = float(data.get("pdf_pt_to_meter", 1.0))
    if bb and len(bb) == 4:
        x0, y0, x1, y1 = [v * scale for v in bb]
        return [[[x0, y0], [x1, y0], [x1, y1], [x0, y1]]]
    return []


# ────────────────────────────────────────────────────────────────
# V1: orphan walls
# ────────────────────────────────────────────────────────────────


def check_orphan_walls(outer: list[dict], inner: list[dict]) -> list[Warning]:
    walls = outer + inner
    bin_map: dict[tuple[int, int], int] = {}
    for w in walls:
        for p in (w["start"], w["end"]):
            k = _bin_key(p[0], p[1])
            bin_map[k] = bin_map.get(k, 0) + 1

    warnings: list[Warning] = []
    for w in walls:
        ks = _bin_key(w["start"][0], w["start"][1])
        ke = _bin_key(w["end"][0], w["end"][1])
        # 자기 자신 2개 endpoint 빼고 0개 → 양쪽 orphan
        free_s = bin_map.get(ks, 0) - 1
        free_e = bin_map.get(ke, 0) - 1
        if free_s == 0 and free_e == 0:
            L = _seg_len(w["start"], w["end"])
            tag = " (SHORT)" if L < SHORT_WALL_THRESHOLD_M else ""
            warnings.append(Warning(
                code="V1",
                element_id=w.get("id", ""),
                message=f"orphan{tag} L={L:.2f}m start=({w['start'][0]:.2f},{w['start'][1]:.2f})",
            ))
    return warnings


# ────────────────────────────────────────────────────────────────
# V2: 0-hit doors
# ────────────────────────────────────────────────────────────────


def check_doors_hit_walls(doors: list[dict], walls: list[dict]) -> list[Warning]:
    warnings: list[Warning] = []
    if not walls:
        return warnings
    for d in doors:
        hinge = d.get("hinge")
        if hinge is None:
            continue
        best = float("inf")
        for w in walls:
            dist = _point_to_segment_distance(
                hinge[0], hinge[1],
                w["start"][0], w["start"][1],
                w["end"][0], w["end"][1],
            )
            if dist < best:
                best = dist
                if best < DOOR_HIT_MAX_M * 0.2:  # 매우 가까우면 조기종료
                    break
        if best > DOOR_HIT_MAX_M:
            warnings.append(Warning(
                code="V2",
                element_id=d.get("id", ""),
                message=f"0-hit door (nearest_wall={best:.2f}m > {DOOR_HIT_MAX_M:.2f}m) "
                        f"hinge=({hinge[0]:.2f},{hinge[1]:.2f})",
            ))
    return warnings


# ────────────────────────────────────────────────────────────────
# V3: boundary cycle / outer_wall 매칭률
# ────────────────────────────────────────────────────────────────


def check_boundary_match(outer: list[dict],
                         boundaries: list[list[list[float]]]) -> list[Warning]:
    warnings: list[Warning] = []
    if not boundaries:
        warnings.append(Warning(
            code="V3", element_id="",
            message="no boundary_polygon — outer 분류 ground truth 없음",
            severity="info",
        ))
        return warnings
    # boundary edge 평탄화
    bedges: list[tuple[list[float], list[float]]] = []
    perimeter = 0.0
    for poly in boundaries:
        n = len(poly)
        for i in range(n):
            a = poly[i]
            b = poly[(i + 1) % n]
            if a == b:
                continue
            bedges.append((a, b))
            perimeter += math.hypot(b[0] - a[0], b[1] - a[1])

    if not bedges:
        return warnings

    matched = 0
    total_outer_len = 0.0
    matched_len = 0.0
    for w in outer:
        seg = (w["start"], w["end"])
        L = _seg_len(w["start"], w["end"])
        total_outer_len += L
        if any(_segment_parallel_close(seg, be,
                                       BOUNDARY_MATCH_PERP_M,
                                       BOUNDARY_MATCH_ANGLE_DEG)
               for be in bedges):
            matched += 1
            matched_len += L

    ratio = (matched / len(outer)) if outer else 0.0
    len_ratio = (matched_len / total_outer_len) if total_outer_len else 0.0
    boundary_n = len(bedges)
    msg_info = (f"boundary_edges={boundary_n} perimeter={perimeter:.1f}m | "
                f"outer_walls={len(outer)} matched={matched} ({ratio*100:.1f}%) "
                f"len_match={len_ratio*100:.1f}%")
    if ratio < BOUNDARY_MATCH_RATIO_WARN:
        warnings.append(Warning(code="V3", element_id="",
                                message=f"boundary match LOW — {msg_info}"))
    else:
        warnings.append(Warning(code="V3", element_id="",
                                message=msg_info, severity="info"))
    return warnings


# ────────────────────────────────────────────────────────────────
# V4: column-wall overlap
# ────────────────────────────────────────────────────────────────


def check_columns_overlap(columns: list[dict], walls: list[dict]) -> list[Warning]:
    warnings: list[Warning] = []
    if not columns or not walls:
        return warnings
    for c in columns:
        s = c.get("start")
        e = c.get("end")
        if s is None or e is None:
            continue
        cx, cy = (s[0] + e[0]) * 0.5, (s[1] + e[1]) * 0.5
        best = float("inf")
        nearest_wall = ""
        for w in walls:
            d = _point_to_segment_distance(
                cx, cy,
                w["start"][0], w["start"][1],
                w["end"][0], w["end"][1],
            )
            if d < best:
                best = d
                nearest_wall = w.get("id", "")
                if best < 1e-3:
                    break
        if best < COLUMN_OVERLAP_PERP_M:
            warnings.append(Warning(
                code="V4",
                element_id=c.get("id", ""),
                message=f"column on wall ({best*100:.1f}cm) near={nearest_wall} "
                        f"center=({cx:.2f},{cy:.2f})",
            ))
    return warnings


# ────────────────────────────────────────────────────────────────
# Driver
# ────────────────────────────────────────────────────────────────


def validate(data: dict) -> list[Warning]:
    outer, inner = _collect_walls(data)
    doors = _collect_doors(data)
    columns = _collect_columns(data)
    boundaries = _collect_boundary(data)
    all_walls = outer + inner

    warnings: list[Warning] = []
    warnings.extend(check_orphan_walls(outer, inner))
    warnings.extend(check_doors_hit_walls(doors, all_walls))
    warnings.extend(check_boundary_match(outer, boundaries))
    warnings.extend(check_columns_overlap(columns, all_walls))
    return warnings


def _print_report(path: Path, data: dict, warnings: list[Warning],
                  verbose: bool = False) -> int:
    schema = "v2" if _is_v2(data) else "v1"
    outer, inner = _collect_walls(data)
    doors = _collect_doors(data)
    cols = _collect_columns(data)
    n_walls = len(outer) + len(inner)

    print(f"=== {path} ({schema}, outer={len(outer)} inner={len(inner)} "
          f"doors={len(doors)} columns={len(cols)}) ===")

    by_code: dict[str, list[Warning]] = {}
    for w in warnings:
        by_code.setdefault(w.code, []).append(w)

    severe_count = 0
    for code in ("V1", "V2", "V3", "V4"):
        ws = by_code.get(code, [])
        warn_only = [w for w in ws if w.severity == "warn"]
        info_only = [w for w in ws if w.severity == "info"]
        if not ws:
            print(f"  [{code}] OK")
            continue
        if warn_only:
            print(f"  [{code}] {len(warn_only)} warnings")
            severe_count += len(warn_only)
            limit = len(warn_only) if verbose else min(5, len(warn_only))
            for w in warn_only[:limit]:
                print(f"    - {w.element_id or '(no-id)':<10} {w.message}")
            if len(warn_only) > limit:
                print(f"    ... +{len(warn_only) - limit} more (use -v)")
        for w in info_only:
            print(f"  [{code}] info: {w.message}")

    print(f"  Summary: {severe_count} warnings")
    return severe_count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="floor JSON 파일 또는 디렉토리")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="모든 warning 출력 (default: 처음 5개만)")
    args = parser.parse_args()

    p = Path(args.path)
    if p.is_dir():
        files = sorted(p.glob("floor_*.json"))
    else:
        files = [p]
    if not files:
        print(f"no floor JSON found in {p}", file=sys.stderr)
        return 1

    total = 0
    for f in files:
        with f.open() as fh:
            data = json.load(fh)
        ws = validate(data)
        total += _print_report(f, data, ws, verbose=args.verbose)
        print()
    print(f"=== TOTAL: {total} warnings across {len(files)} file(s) ===")
    return total


if __name__ == "__main__":
    raise SystemExit(main())
