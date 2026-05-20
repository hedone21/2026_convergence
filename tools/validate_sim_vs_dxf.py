"""시뮬 site dump CSV vs DXF JSON 자동 품질 측정.

site_dump.gd가 헤드리스 부팅으로 export한 spawn 결과(walls/columns)와
원본 DXF JSON(SiteData)을 비교하여 정량 metric 산출.

SPEC-QM-001 (TBD) — 자동화된 도면-시뮬레이션 품질 측정.

측정 항목:
  M1  total length ratio        — Σ(dump walls length) / Σ(json walls length).
                                   door cut으로 다소 < 1.0 정상 (출입구 면적 제외).
  M2  coverage                  — dump segment의 mid가 JSON 어떤 wall 근방(평행+
                                   수직거리 < TOL)에 있는 비율. 1에 가까울수록 충실.
  M3  orphan dump segments      — JSON 어떤 wall과도 매칭 안 되는 spawn (시뮬 측 노이즈)
  M4  unmatched json walls      — spawn에 반영 안 된 도면 wall (시뮬 측 누락)
  M5  position deviation (mean) — 매칭된 segment의 평균 수직 거리 (mm)

종료 코드 = (1 - coverage) * 100 의 정수 부분. 0=완벽 일치, 100=완전 mismatch.

usage:
  python tools/validate_sim_vs_dxf.py \\
      --dump data/sessions/site_dump.csv \\
      --json data/calpoly_b001/floor_1.json
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from pathlib import Path


COVERAGE_PERP_TOL_M = 0.15        # dump mid → JSON wall 수직거리 임계 (15cm)
COVERAGE_ANGLE_TOL_DEG = 5.0      # 각도 매칭 임계
COVERAGE_ALONG_PAD_M = 0.30       # JSON wall edge로 along projection padding


def _seg_props(s, e):
    dx, dy = e[0] - s[0], e[1] - s[1]
    L = math.hypot(dx, dy)
    ang = math.atan2(dy, dx) % math.pi
    return L, ang


def _segment_matches(dmid_x, dmid_y, dang, dlen,
                     js, je, jang, jlen,
                     perp_tol, angle_tol_rad, along_pad):
    """dump segment의 mid + 방향 vs JSON segment 평행성 + 수직거리 + along 매칭."""
    ang_diff = abs(dang - jang)
    if ang_diff > math.pi - angle_tol_rad:
        ang_diff = abs(math.pi - ang_diff)
    if ang_diff > angle_tol_rad:
        return False, 0.0
    cos_j, sin_j = math.cos(jang), math.sin(jang)
    # JSON wall의 line offset
    d_j = -sin_j * js[0] + cos_j * js[1]
    d_d = -sin_j * dmid_x + cos_j * dmid_y
    perp = abs(d_d - d_j)
    if perp > perp_tol:
        return False, perp
    # along projection: JSON segment의 t-range 안에 dump mid 들어가는지
    t_s = cos_j * js[0] + sin_j * js[1]
    t_e = cos_j * je[0] + sin_j * je[1]
    t_lo, t_hi = (t_s, t_e) if t_s <= t_e else (t_e, t_s)
    t_d = cos_j * dmid_x + sin_j * dmid_y
    if t_d < t_lo - along_pad or t_d > t_hi + along_pad:
        return False, perp
    return True, perp


def _load_dump(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open() as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append({
                "group": r["group"],
                "start": (float(r["start_x"]), float(r["start_z"])),
                "end": (float(r["end_x"]), float(r["end_z"])),
                "length": float(r["length"]),
                "angle_rad": float(r["angle_rad"]),
            })
    return rows


def _load_json_walls(path: Path) -> tuple[list[dict], tuple[float, float]]:
    """JSON wall 좌표를 dump와 같은 좌표계로 변환 (bbox center 차감)."""
    data = json.loads(path.read_text())
    bb = data["metadata"]["bbox_m"]
    (x0, y0), (x1, y1) = bb
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    walls = []
    cats = data["categories"]
    for grp, items in [("outer", cats.get("outer_walls", [])),
                       ("inner", cats.get("inner_walls", []))]:
        for w in items:
            s = (w["start"][0] - cx, w["start"][1] - cy)
            e = (w["end"][0] - cx, w["end"][1] - cy)
            L, ang = _seg_props(s, e)
            walls.append({
                "side": grp,
                "start": s,
                "end": e,
                "length": L,
                "angle": ang,
            })
    return walls, (cx, cy)


def validate(dump_path: Path, json_path: Path) -> dict:
    dump_rows = _load_dump(dump_path)
    dump_walls = [r for r in dump_rows if r["group"] == "walls"]
    dump_cols = [r for r in dump_rows if r["group"] == "columns"]
    json_walls, _ = _load_json_walls(json_path)

    sum_dump_len = sum(r["length"] for r in dump_walls)
    sum_json_len = sum(w["length"] for w in json_walls)

    # 매칭 — dump 각각에 대해 JSON walls 순회 (O(N*M))
    angle_tol = math.radians(COVERAGE_ANGLE_TOL_DEG)
    matched_dump = 0
    perp_sum = 0.0
    perp_count = 0
    matched_dump_len = 0.0
    json_matched_flags = [False] * len(json_walls)
    for d in dump_walls:
        dmid_x = (d["start"][0] + d["end"][0]) * 0.5
        dmid_y = (d["start"][1] + d["end"][1]) * 0.5
        dang = d["angle_rad"] % math.pi
        best_perp = None
        best_j = -1
        for j, jw in enumerate(json_walls):
            ok, perp = _segment_matches(
                dmid_x, dmid_y, dang, d["length"],
                jw["start"], jw["end"], jw["angle"], jw["length"],
                COVERAGE_PERP_TOL_M, angle_tol, COVERAGE_ALONG_PAD_M,
            )
            if ok and (best_perp is None or perp < best_perp):
                best_perp = perp
                best_j = j
        if best_j >= 0:
            matched_dump += 1
            matched_dump_len += d["length"]
            perp_sum += best_perp
            perp_count += 1
            json_matched_flags[best_j] = True

    coverage = matched_dump / len(dump_walls) if dump_walls else 0.0
    coverage_len = matched_dump_len / sum_dump_len if sum_dump_len > 0 else 0.0
    length_ratio = sum_dump_len / sum_json_len if sum_json_len > 0 else 0.0
    mean_perp_mm = (perp_sum / perp_count * 1000.0) if perp_count > 0 else 0.0
    orphan_dump = len(dump_walls) - matched_dump
    unmatched_json = json_matched_flags.count(False)

    return {
        "dump_walls": len(dump_walls),
        "dump_columns": len(dump_cols),
        "json_walls": len(json_walls),
        "M1_length_ratio": length_ratio,
        "M2_coverage_count": coverage,
        "M2b_coverage_length": coverage_len,
        "M3_orphan_dump": orphan_dump,
        "M4_unmatched_json": unmatched_json,
        "M5_mean_perp_mm": mean_perp_mm,
        "sum_dump_m": sum_dump_len,
        "sum_json_m": sum_json_len,
    }


def _print_report(dump_path: Path, json_path: Path, m: dict) -> None:
    print(f"=== {dump_path.name}  vs  {json_path.name} ===")
    print(f"  spawn walls    : {m['dump_walls']:>5}  (cols={m['dump_columns']})")
    print(f"  dxf walls      : {m['json_walls']:>5}")
    print(f"  M1 length ratio: {m['M1_length_ratio']*100:>6.2f}%   "
          f"sum_dump={m['sum_dump_m']:.1f}m  sum_json={m['sum_json_m']:.1f}m")
    print(f"  M2 coverage    : {m['M2_coverage_count']*100:>6.2f}%   "
          f"({m['dump_walls'] - m['M3_orphan_dump']}/{m['dump_walls']})")
    print(f"  M2b len-cov    : {m['M2b_coverage_length']*100:>6.2f}%")
    print(f"  M3 orphan dump : {m['M3_orphan_dump']:>5}")
    print(f"  M4 unmatched   : {m['M4_unmatched_json']:>5}  (dxf walls not used)")
    print(f"  M5 mean perp   : {m['M5_mean_perp_mm']:>6.1f} mm  (matched only)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", required=True, help="site_dump CSV path")
    parser.add_argument("--json", required=True, help="DXF JSON (floor_*.json)")
    args = parser.parse_args()

    m = validate(Path(args.dump), Path(args.json))
    _print_report(Path(args.dump), Path(args.json), m)
    # 종료 코드: (1 - coverage) * 100. 0=완벽
    return int(round((1.0 - m["M2_coverage_count"]) * 100))


if __name__ == "__main__":
    raise SystemExit(main())
