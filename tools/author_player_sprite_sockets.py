# -*- coding: utf-8 -*-
"""Semi-automatic sprite-socket authoring for player character sheets.

Extracts per-frame anchor ("socket") coordinates from a sprite sheet by
alpha analysis, so runtime composition layers (perk glows, attachments)
can track the body frame-by-frame instead of riding a fixed offset.

Current extractors:
  foot_l / foot_r : left/right contact points of the lowest solid band
                    (for board-riding characters this is the board's
                    underside edges).
  head_top        : centroid-x of the topmost solid band at its top row
                    (anchor for hats / floating charms above the head).

Outputs per sheet:
  <out_dir>/<sheet_stem>_sockets.json   : frame -> {socket: [x, y]} (cell-local px)
  <out_dir>/<sheet_stem>_sockets_qa.png : sheet copy with socket markers
  and a combined GDScript const block printed to stdout.

Usage:
  py tools/author_player_sprite_sockets.py --out-dir <dir>

Socket coordinates are CELL-LOCAL pixels (0..cell_w, 0..cell_h).
Left-facing sheets that are pure mirrors of right-facing sheets are NOT
re-authored: the runtime resolver mirrors x (cell_w - x).
"""

import argparse
import json
import os

from PIL import Image, ImageDraw

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Alpha threshold: high enough to skip faint ground-splash / energy wisps,
# low enough to keep the solid board silhouette.
SOLID_ALPHA = 96
# Bottom band: rows within this many px above the lowest solid row are
# considered "contact band" for foot/board extraction.
BOTTOM_BAND_PX = 10
# A column inside the band counts as "board body" only when it is at least
# this many solid px thick. Ground-splash / energy wisps are thin strokes
# (2-4 px) while the board body is 8+ px thick, so this isolates the board.
MIN_COLUMN_THICKNESS = 5
# Top band height for the head_top centroid (hair silhouette rows).
TOP_BAND_PX = 6


def _is_energy_prop_pixel(rgba):
    """Bright cyan energy props (raised paddle disc, glide trails) that can
    rise above the head and steal the head_top anchor. Palette heuristic
    tuned for the current Mika sheets (dark navy hair vs luminous cyan
    props) -- re-tune per character when authoring other rosters, and always
    verify with the marker QA strip."""
    r, g, b, a = rgba
    return a >= SOLID_ALPHA and g >= 140 and b >= 170 and r <= 160

SHEETS = [
    {
        "motion": "walk",
        "direction": "right",
        "path": "godot/assets/sprites/smasher/smasher_rear_move_right_sd_blue_energy_glide_bodyweight_v9_4x2_160_clean.png",
        "cols": 4,
        "rows": 2,
        "frames": 8,
    },
    {
        "motion": "dash",
        "direction": "right",
        "path": "godot/assets/sprites/smasher/smasher_dash_right_rugby_shoulder_charge_autosprite_v4_4x2_160_clean.png",
        "cols": 4,
        "rows": 2,
        "frames": 8,
    },
    {
        "motion": "idle",
        "direction": "any",
        "path": "godot/assets/sprites/smasher/smasher_rear_idle_breathe_sd_idle_layout_autosprite_v2_4x2_160_clean.png",
        "cols": 4,
        "rows": 2,
        "frames": 8,
    },
    # Attack sheets are authored per-direction (no mirror assumption: the
    # left sheet is an independently shipped file, not a runtime flip).
    {
        "motion": "attack",
        "direction": "left",
        "path": "godot/assets/sprites/smasher/smasher_attack_left_sheet_16f.png",
        "cols": 4,
        "rows": 4,
        "frames": 16,
    },
    {
        "motion": "attack",
        "direction": "right",
        "path": "godot/assets/sprites/smasher/smasher_attack_right_sheet_16f.png",
        "cols": 4,
        "rows": 4,
        "frames": 16,
    },
]


def extract_cell_sockets(cell):
    """Return {socket_id: (x, y)} for one cell image (RGBA), or None."""
    alpha = cell.getchannel("A")
    w, h = cell.size
    data = alpha.load()

    lowest_y = -1
    for y in range(h - 1, -1, -1):
        row_has = any(data[x, y] >= SOLID_ALPHA for x in range(w))
        if row_has:
            lowest_y = y
            break
    if lowest_y < 0:
        return None

    band_top = max(0, lowest_y - BOTTOM_BAND_PX)
    body_xs = []
    for x in range(w):
        thickness = sum(
            1 for y in range(band_top, lowest_y + 1) if data[x, y] >= SOLID_ALPHA
        )
        if thickness >= MIN_COLUMN_THICKNESS:
            body_xs.append(x)
    if not body_xs:
        return None
    x_lo = float(body_xs[0])
    x_hi = float(body_xs[-1])
    # Contact y: lowest solid row within the body columns (ignores wisp tips
    # that dip below the board between the body edges).
    contact_y = lowest_y
    for y in range(lowest_y, band_top - 1, -1):
        if any(data[x, y] >= SOLID_ALPHA for x in body_xs):
            contact_y = y
            break

    rgba = cell.load()
    # Prop mask: bright-cyan energy pixels DILATED by a few px so the props'
    # dark outline rows (which are not cyan themselves) are excluded too --
    # the raised paddle disc's navy rim otherwise survives a color-only
    # filter and steals the head anchor.
    prop = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if _is_energy_prop_pixel(rgba[x, y]):
                prop[y][x] = True
    PROP_DILATE = 3
    prop_near = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if not prop[y][x]:
                continue
            for dy in range(-PROP_DILATE, PROP_DILATE + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                for dx in range(-PROP_DILATE, PROP_DILATE + 1):
                    xx = x + dx
                    if 0 <= xx < w:
                        prop_near[yy][xx] = True

    def is_head_pixel(x, y):
        return data[x, y] >= SOLID_ALPHA and not prop_near[y][x]

    top_y = -1
    for y in range(h):
        if any(is_head_pixel(x, y) for x in range(w)):
            top_y = y
            break
    sockets = {
        "foot_l": (x_lo, float(contact_y)),
        "foot_r": (x_hi, float(contact_y)),
    }
    if top_y >= 0:
        band_bottom = min(h - 1, top_y + TOP_BAND_PX)
        weighted_x = 0
        count = 0
        for y in range(top_y, band_bottom + 1):
            for x in range(w):
                if is_head_pixel(x, y):
                    weighted_x += x
                    count += 1
        if count > 0:
            sockets["head_top"] = (round(weighted_x / count, 1), float(top_y))
    return sockets


def process_sheet(spec, out_dir):
    sheet_path = os.path.join(REPO_ROOT, spec["path"])
    img = Image.open(sheet_path).convert("RGBA")
    cols, rows, frames = spec["cols"], spec["rows"], spec["frames"]
    cell_w = img.width // cols
    cell_h = img.height // rows

    qa = img.copy()
    draw = ImageDraw.Draw(qa)
    frame_sockets = []
    for f in range(frames):
        col = f % cols
        row = f // cols
        cell = img.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        sockets = extract_cell_sockets(cell)
        frame_sockets.append(sockets)
        if sockets is None:
            continue
        for sid, (sx, sy) in sockets.items():
            gx = col * cell_w + sx
            gy = row * cell_h + sy
            if sid.endswith("_l"):
                color = (255, 64, 64, 255)
            elif sid.endswith("_r"):
                color = (64, 160, 255, 255)
            else:
                color = (80, 255, 120, 255)
            draw.line([(gx - 5, gy), (gx + 5, gy)], fill=color, width=1)
            draw.line([(gx, gy - 5), (gx, gy + 5)], fill=color, width=1)
            draw.ellipse([gx - 2, gy - 2, gx + 2, gy + 2], outline=color, width=1)

    stem = os.path.splitext(os.path.basename(spec["path"]))[0]
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, stem + "_sockets.json")
    qa_path = os.path.join(out_dir, stem + "_sockets_qa.png")
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "sheet": spec["path"],
                "motion": spec["motion"],
                "direction": spec["direction"],
                "cell_size": [cell_w, cell_h],
                "frames": frame_sockets,
            },
            fh,
            indent=2,
        )
    qa.save(qa_path)
    return {
        "spec": spec,
        "cell_size": (cell_w, cell_h),
        "frames": frame_sockets,
        "json_path": json_path,
        "qa_path": qa_path,
    }


def emit_gdscript(results):
    lines = []
    lines.append("# Generated by tools/author_player_sprite_sockets.py -- cell-local px in the")
    lines.append("# sheet's cell space. Left direction resolves by mirroring right (x -> cell_w - x).")
    lines.append("const SMASHER_SOCKET_CELL_SIZE := Vector2(160.0, 160.0)")
    lines.append("const SMASHER_SOCKETS := {")
    by_motion = {}
    for res in results:
        by_motion.setdefault(res["spec"]["motion"], []).append(res)
    for motion, motion_results in by_motion.items():
        lines.append('\t"%s": {' % motion)
        for res in motion_results:
            lines.append('\t\t"%s": [' % res["spec"]["direction"])
            for sockets in res["frames"]:
                if sockets is None:
                    lines.append("\t\t\t{},")
                    continue
                parts = []
                for sid in sorted(sockets.keys()):
                    x, y = sockets[sid]
                    parts.append('"%s": Vector2(%.1f, %.1f)' % (sid, x, y))
                lines.append("\t\t\t{%s}," % ", ".join(parts))
            lines.append("\t\t],")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=os.path.join(REPO_ROOT, ".tmp", "sprite_sockets"))
    args = parser.parse_args()

    results = [process_sheet(spec, args.out_dir) for spec in SHEETS]
    for res in results:
        print("sheet: %s" % res["spec"]["path"])
        print("  json: %s" % res["json_path"])
        print("  qa:   %s" % res["qa_path"])
    print()
    print(emit_gdscript(results))


if __name__ == "__main__":
    main()
