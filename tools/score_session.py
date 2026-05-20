"""세션 사후 채점 — SessionScorer 알고리즘의 Python 미러.

CSV/JSON 로깅 파일을 읽어 실제 hazard 위치와 사용자 마킹을 거리 2m로 매칭하여
precision/recall/F1, miss/false-positive, 평균 식별 시간 산출.

SPEC-DAT-002 (보강) — 세션 채점 (오프라인 분석).

usage:
  python tools/score_session.py \\
      --hazards data/sessions/session_001/hazards.json \\
      --markings data/sessions/session_001/markings.json \\
      --start-ts 1716220800000

JSON schema:
  hazards: [{"id": str, "position": [x,y,z], "type": str}, ...]
  markings: [{"position": [x,y,z], "timestamp_ms": int, "category": str}, ...]
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path


MATCH_DISTANCE_M = 2.0


def _dist(a, b) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def score(hazards: list[dict], markings: list[dict],
          session_start_ts: int = 0, match_dist: float = MATCH_DISTANCE_M) -> dict:
    used = [False] * len(markings)
    matched_pairs: list[dict] = []
    detect_times: list[int] = []
    tp = 0
    fn = 0

    for hz in hazards:
        h_pos = hz.get("position", [0.0, 0.0, 0.0])
        h_type = hz.get("type", "")
        best_idx = -1
        best_dist = match_dist + 1.0
        for i, m in enumerate(markings):
            if used[i]:
                continue
            cat = m.get("category", "")
            if cat == "false_positive":
                continue
            if cat != "" and cat != h_type:
                continue
            d = _dist(h_pos, m.get("position", [0.0, 0.0, 0.0]))
            if d < match_dist and d < best_dist:
                best_dist = d
                best_idx = i
        if best_idx >= 0:
            used[best_idx] = True
            tp += 1
            m = markings[best_idx]
            ttd = int(m.get("timestamp_ms", 0)) - session_start_ts
            detect_times.append(ttd)
            matched_pairs.append({
                "hazard_id": hz.get("id", ""),
                "hazard_position": h_pos,
                "marking_position": m.get("position", [0.0, 0.0, 0.0]),
                "distance_m": best_dist,
                "time_to_detect_ms": ttd,
            })
        else:
            fn += 1

    fp = sum(1 for u in used if not u)

    p_denom = tp + fp
    r_denom = tp + fn
    precision = tp / p_denom if p_denom > 0 else 0.0
    recall = tp / r_denom if r_denom > 0 else 0.0
    f_denom = precision + recall
    f1 = (2.0 * precision * recall / f_denom) if f_denom > 0.0 else 0.0
    avg_ttd = (sum(detect_times) / len(detect_times)) if detect_times else 0.0

    return {
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "true_positives": tp,
        "false_positives": fp,
        "false_negatives": fn,
        "avg_time_to_detect_ms": avg_ttd,
        "matched_pairs": matched_pairs,
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--hazards", required=True, help="hazards JSON 경로")
    p.add_argument("--markings", required=True, help="markings JSON 경로")
    p.add_argument("--start-ts", type=int, default=0, help="세션 시작 timestamp ms")
    p.add_argument("--match-dist", type=float, default=MATCH_DISTANCE_M)
    p.add_argument("--out", default="", help="결과 JSON 출력 경로 (선택)")
    args = p.parse_args()

    hazards = json.loads(Path(args.hazards).read_text())
    markings = json.loads(Path(args.markings).read_text())
    result = score(hazards, markings, args.start_ts, args.match_dist)

    print(f"=== Session Score ===")
    print(f"  TP={result['true_positives']} FP={result['false_positives']} FN={result['false_negatives']}")
    print(f"  Precision: {result['precision']:.3f}")
    print(f"  Recall:    {result['recall']:.3f}")
    print(f"  F1:        {result['f1']:.3f}")
    print(f"  Avg TTD:   {result['avg_time_to_detect_ms']:.1f} ms")

    if args.out:
        Path(args.out).write_text(json.dumps(result, indent=2))
        print(f"  → {args.out}")

    return 0 if result["f1"] > 0.0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
