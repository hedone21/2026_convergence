"""DXF (floor JSON) vs Godot 탑다운 PNG 자동 비교.

DXF JSON에서 wall mask를 같은 viewport 픽셀 크기로 렌더하고,
Godot 06_topdown_40m.png에서 wall mask를 edge detection으로 추출한 뒤
side-by-side + alpha overlay + diff highlight + IoU 점수를 생성.

가정:
- Godot 카메라: pos=(0,40,0) pitch=-89° fov=75° (desktop_rig.tscn 기본)
- 카메라 위치 = bbox 중심 (시뮬 site origin = bbox center)
- 카메라 높이 40m, fov 75° → 가로 시야 ≈ 61.4m / pixel
- bbox는 floor JSON metadata.bbox_m

usage:
  python tools/screenshot_compare.py \\
      --json data/calpoly_b001/floor_1.json \\
      --godot _workspace/diagnosis/no_ceiling/06_topdown_40m.png \\
      --out _workspace/diagnosis/compare_floor_1.png
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import binary_dilation


# Godot 카메라 가정 (desktop_rig.tscn — Camera3D 기본값)
GODOT_CAM_HEIGHT_M = 40.0
GODOT_CAM_FOV_DEG = 75.0
GODOT_CAM_ASPECT = 16.0 / 9.0

# Godot 캡처 PNG 우상단 미니맵 영역 (1152px 폭 기준)
# minimap.tscn: anchor_right=1.0, offset_left=-300, offset_top=16, offset_bottom=220
# 안전 마진 두고 잘라냄
MINIMAP_CROP_RIGHT_PX_RATIO = 320.0 / 1152.0   # 우측에서 28% 이내
MINIMAP_CROP_TOP_PX_RATIO = 240.0 / 648.0      # 상단 37% 이내

# DXF wall mask dilate 반경 (m). wall 두께 0.3m이지만 약간 더 부풀려서
# Godot 그림자 영역과 매칭률 ↑
DXF_WALL_DILATE_M = 0.30


def _render_dxf_mask(data: dict, view_w_m: float, view_h_m: float,
                     px_w: int, px_h: int) -> np.ndarray:
    """floor JSON의 wall을 (px_w x px_h) 흑백 mask로 렌더.

    bbox 중심을 viewport 중심에 두고, 양옆 view_w_m / 위아래 view_h_m로 캡처.
    리턴: bool ndarray (True = wall 픽셀)
    """
    bbox = data["metadata"]["bbox_m"]
    (x0, y0), (x1, y1) = bbox
    cx_m = (x0 + x1) * 0.5
    cy_m = (y0 + y1) * 0.5

    fig, ax = plt.subplots(figsize=(px_w / 100.0, px_h / 100.0), dpi=100)
    ax.set_xlim(cx_m - view_w_m / 2, cx_m + view_w_m / 2)
    ax.set_ylim(cy_m - view_h_m / 2, cy_m + view_h_m / 2)
    ax.set_aspect("equal")
    ax.set_facecolor("white")
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, bottom=0, top=1)

    cats = data["categories"]
    # wall 두께 0.18m 가정 (Cal Poly inner 표준)
    lw_outer = max(2.0, 0.30 * px_w / view_w_m)
    lw_inner = max(1.0, 0.18 * px_w / view_w_m)

    for w in cats.get("outer_walls", []):
        s, e = w["start"], w["end"]
        ax.plot([s[0], e[0]], [s[1], e[1]],
                color="black", linewidth=lw_outer, solid_capstyle="round")
    for w in cats.get("inner_walls", []):
        s, e = w["start"], w["end"]
        ax.plot([s[0], e[0]], [s[1], e[1]],
                color="black", linewidth=lw_inner, solid_capstyle="round")

    fig.canvas.draw()
    rgba = np.asarray(fig.canvas.buffer_rgba())
    plt.close(fig)
    gray = rgba[:, :, :3].mean(axis=2)
    mask = gray < 128  # True = wall outline

    # 0.3m 반경으로 dilate — Godot mask와 두께 매칭
    px_per_m = px_w / view_w_m
    dilate_px = max(1, int(round(DXF_WALL_DILATE_M * px_per_m)))
    structure = np.ones((dilate_px * 2 + 1, dilate_px * 2 + 1), dtype=bool)
    return binary_dilation(mask, structure=structure)


def _extract_godot_mask(godot_png: Path,
                        target_w: int, target_h: int) -> np.ndarray:
    """Godot 탑다운 PNG에서 wall mask 추출.

    1. 우상단 미니맵 영역 흰색으로 채워 노이즈 제거
    2. RGB → HSV
    3. value < threshold 픽셀을 wall로 분류 (ground는 밝은 회색, wall은 어두움)
    4. target 크기로 resize
    """
    im = Image.open(godot_png).convert("RGB")
    W, H = im.size

    # 미니맵 영역 mask out
    crop_x = int(W - W * MINIMAP_CROP_RIGHT_PX_RATIO)
    crop_y = int(H * MINIMAP_CROP_TOP_PX_RATIO)
    draw = ImageDraw.Draw(im)
    draw.rectangle([crop_x, 0, W, crop_y], fill=(220, 220, 220))

    hsv = np.array(im.convert("HSV"))
    value = hsv[:, :, 2].astype(np.int16)
    # ground floor의 평균 value를 동적으로 추정 — 이미지 중간 50% 영역의 평균
    cy, cx = H // 2, W // 2
    sample = value[cy - H // 4:cy + H // 4, cx - W // 4:cx + W // 4]
    ground_value = int(np.median(sample))
    # ground 대비 어두운 픽셀 = wall + 그림자
    wall_threshold = ground_value - 18
    mask = value < wall_threshold

    mask_im = Image.fromarray((mask.astype(np.uint8) * 255))
    mask_im = mask_im.resize((target_w, target_h), Image.NEAREST)
    return np.array(mask_im) > 127


def _iou(a: np.ndarray, b: np.ndarray) -> float:
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return float(inter) / float(union) if union > 0 else 0.0


def _compose_collage(dxf_mask: np.ndarray, godot_mask: np.ndarray,
                     iou: float, label: str, out_path: Path) -> None:
    """4-panel: DXF | Godot | overlay | diff."""
    h, w = dxf_mask.shape

    def _mask_to_rgb(m: np.ndarray, fg: tuple, bg: tuple) -> np.ndarray:
        rgb = np.empty((h, w, 3), dtype=np.uint8)
        rgb[:] = bg
        rgb[m] = fg
        return rgb

    dxf_rgb = _mask_to_rgb(dxf_mask, (40, 40, 40), (245, 245, 245))
    god_rgb = _mask_to_rgb(godot_mask, (40, 40, 40), (245, 245, 245))

    # overlay: DXF=red, Godot=blue, both=purple, neither=white
    over = np.full((h, w, 3), 245, dtype=np.uint8)
    over[dxf_mask & ~godot_mask] = (220, 60, 60)   # DXF only — red
    over[godot_mask & ~dxf_mask] = (60, 100, 220)  # Godot only — blue
    over[dxf_mask & godot_mask] = (140, 80, 180)   # both — purple

    # diff: 일치=옅음, 불일치=강한 색
    diff = np.full((h, w, 3), 250, dtype=np.uint8)
    diff[dxf_mask & ~godot_mask] = (255, 60, 60)
    diff[godot_mask & ~dxf_mask] = (60, 130, 255)

    gap_px = 16
    header_h = 36
    summary_h = 44
    canvas_w = w * 2 + gap_px
    canvas_h = h * 2 + header_h * 2 + gap_px + summary_h
    canvas = Image.new("RGB", (canvas_w, canvas_h), (28, 30, 38))

    try:
        font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans.ttf", 16)
        font_big = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
        font_big = ImageFont.load_default()

    panels = [
        (dxf_rgb, "DXF (ground truth, dilated)"),
        (god_rgb, "Godot (sim, HSV value mask)"),
        (over, "Overlay  (R=DXF only, B=Godot only, P=both)"),
        (diff, "Diff  (red=DXF only, blue=Godot only)"),
    ]
    positions = [(0, 0), (1, 0), (0, 1), (1, 1)]
    draw = ImageDraw.Draw(canvas)
    for (panel, title), (col, row) in zip(panels, positions):
        x = col * (w + gap_px)
        y = summary_h + row * (h + header_h + gap_px) + header_h
        canvas.paste(Image.fromarray(panel), (x, y))
        draw.text((x + 8, y - header_h + 8), title,
                  fill=(220, 220, 220), font=font)

    summary = f"{label}   |   IoU = {iou:.3f}   |   panel {h}x{w}px"
    draw.text((16, 12), summary, fill=(240, 220, 160), font=font_big)

    canvas.save(out_path)


def compare(json_path: Path, godot_path: Path, out_path: Path,
            target_h: int = 720) -> float:
    data = json.loads(json_path.read_text())

    # Godot 카메라 가로 시야 (m)
    view_w_m = 2.0 * math.tan(math.radians(GODOT_CAM_FOV_DEG / 2)) * GODOT_CAM_HEIGHT_M
    view_h_m = view_w_m / GODOT_CAM_ASPECT

    target_w = int(target_h * GODOT_CAM_ASPECT)

    dxf_mask = _render_dxf_mask(data, view_w_m, view_h_m, target_w, target_h)
    god_mask = _extract_godot_mask(godot_path, target_w, target_h)

    iou = _iou(dxf_mask, god_mask)
    label = f"{json_path.stem} vs {godot_path.name}"
    _compose_collage(dxf_mask, god_mask, iou, label, out_path)
    print(f"wrote {out_path}  IoU={iou:.3f}  view={view_w_m:.1f}x{view_h_m:.1f}m")
    return iou


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", required=True, help="floor JSON path")
    parser.add_argument("--godot", required=True, help="Godot topdown PNG")
    parser.add_argument("--out", required=True, help="output collage PNG")
    parser.add_argument("--height", type=int, default=720,
                        help="output panel pixel height (width = 16/9 * height)")
    args = parser.parse_args()

    compare(Path(args.json), Path(args.godot), Path(args.out),
            target_h=args.height)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
