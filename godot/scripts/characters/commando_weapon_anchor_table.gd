extends RefCounted

## Commando B2 weapon visual anchor + pivot table.
##
## Replaces the failed Option A overlay (which baked gripping hands into the
## weapon PNG and ran into hand-double / position-offset bugs in
## `_draw_commando_weapon_overlay`).
##
## B2 contract (full spec at `.tmp/commando_b2_asset_contract.md`):
##   - Base commando sheets show empty grip hands (no weapon, no pistol baked
##     in). Hands are posed as relaxed grip fists, not open palms.
##   - Weapon PNGs contain only the weapon body (no hands, no arms, no body).
##   - Runtime aligns weapon to character via:
##       weapon_top_left = frame_grip_anchor - weapon_pivot * scale
##       weapon_rotation = frame_anchor.rot + weapon.base_rot
##
## This file owns:
##   - `FRAME_ANCHORS` — per animation state, per frame index, the stable
##     grip / pivot anchor coordinates in 160x160 source-cell space. In
##     side/back-3/4 views the literal hand can be occluded, so the first
##     B2 pass uses a body-center hip anchor instead of chasing unreliable
##     hand pixels.
##   - `WEAPON_PIVOTS` — per weapon id, the pivot points inside the weapon
##     PNG (also in 160x160 source-cell-equivalent coords) plus the draw
##     size and any base rotation offset.
##
## Weapon pivots are populated for the first six Commando firearms as a
## reference / rollback path. The idle / walk overlay renderer is currently
## gated off; the intended production path is empty-handed idle / walk plus
## weapon-specific firing sheets. Unknown weapons and animations without
## anchors still fail closed.

# Animation states match the renderer's branching:
# - `idle_back`: stationary (player_move_active = false)
# - `walk_back`: moving with directional walk sheet absent (commando does
#   not currently emit walk_back at runtime — placeholder for future)
# - `walk_left`: moving + player_walk_direction < 0
# - `walk_right`: moving + player_walk_direction >= 0
const ANIMATION_IDLE_BACK := "idle_back"
const ANIMATION_WALK_BACK := "walk_back"
const ANIMATION_WALK_LEFT := "walk_left"
const ANIMATION_WALK_RIGHT := "walk_right"

# Weapon ids match `commando_weapon_controller.WEAPON_DATA` keys. `pistol`
# is included so the same overlay path can render the default pistol once
# the base sheets become weapon-less; until then, the baked-in pistol on
# the legacy sheets will continue to be visible and the pistol pivot here
# is unused.
const WEAPON_PISTOL := "pistol"
const WEAPON_AK47 := "ak47"
const WEAPON_BAZOOKA := "bazooka"
const WEAPON_NET_GUN := "net_gun"
const WEAPON_BOWLING_TRAP := "bowling_trap"
const WEAPON_SUICIDE_DRONE := "suicide_drone"

## Per-animation, per-frame grip anchors. Each entry is a Dictionary with:
##   - `primary` (Vector2): grip / pivot anchor in 160x160 source-cell
##     space. The weapon's `pivot_primary` will land at this point. For
##     the current Gemini base-grip sheets this is a body-center hip anchor
##     measured from the 100px-tall chibi bbox, not a literal skin-cluster
##     hand centroid.
##   - `secondary` (Vector2): left-hand grip anchor (optional, used for
##     two-handed weapons or future visual QA).
##   - `rot` (float): rotation in degrees applied to the weapon for this
##     frame. 0 = no rotation, positive = clockwise (Godot canvas math).
##
## The array length matches the animation's frame count (8 for the
## current 4x2 base sheets). Keep the order matching `player_idle_frame`
## / `player_walk_frame` so the renderer can index directly.
##
## Perspective v2 calibration: the weapon PNG's top points toward the boss
## and its bottom-center alpha bbox lands on the grip anchor. QA compositing
## showed the proposed y=80 anchor lands on the head / neck line for these
## base sheets, so the first in-game-safe pass keeps the grip at the visible
## hand / hip line while the new vertical perspective art points upward.
## `walk_back` remains empty because the runtime does not currently emit it.
const FRAME_ANCHORS := {
	ANIMATION_IDLE_BACK: [
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 119.0), "secondary": Vector2.ZERO, "rot": 0.0},
	],
	ANIMATION_WALK_BACK: [],
	ANIMATION_WALK_LEFT: [
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
	],
	ANIMATION_WALK_RIGHT: [
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
		{"primary": Vector2(80.0, 116.0), "secondary": Vector2.ZERO, "rot": 0.0},
	],
}

## Per-weapon pivot + draw metadata. Each entry is a Dictionary with:
##   - `texture_key` (String): cache key in `battle_resources` for the
##     weapon-only PNG (no hands).
##   - `draw_size` (Vector2): rendered size in 160x160 source-cell space.
##     The runtime scales this to the actual `player_visual_rect` size.
##   - `pivot_primary` (Vector2): grip pivot inside the weapon PNG. The
##     primary frame anchor will align to this point.
##   - `pivot_secondary` (Vector2): optional secondary grip pivot for
##     two-handed weapon QA.
##   - `base_rot` (float): rotation offset applied on top of the per-frame
##     rotation. Use this when the weapon PNG is authored at a non-zero
##     angle and you do not want to redraw it.
##   - `anchor_overrides` (Dictionary): optional per-animation primary
##     anchor override. Keep this empty for the perspective v2 weapons
##     unless in-game calibration proves a specific weapon needs it.
##
const WEAPON_PIVOTS := {
	WEAPON_PISTOL: {
		"texture_key": "commando_weapon_b2v2_pistol",
		"draw_size": Vector2(26.0, 42.0),
		"pivot_primary": Vector2(12.0, 41.0),
		"pivot_secondary": Vector2.ZERO,
		"base_rot": 0.0,
	},
	WEAPON_AK47: {
		"texture_key": "commando_weapon_b2v2_ak47",
		"draw_size": Vector2(44.0, 110.0),
		"pivot_primary": Vector2(21.0, 109.0),
		"pivot_secondary": Vector2.ZERO,
		"base_rot": 0.0,
	},
	WEAPON_BAZOOKA: {
		"texture_key": "commando_weapon_b2v2_bazooka",
		"draw_size": Vector2(32.0, 118.0),
		"pivot_primary": Vector2(15.0, 117.0),
		"pivot_secondary": Vector2.ZERO,
		"base_rot": 0.0,
	},
	WEAPON_NET_GUN: {
		"texture_key": "commando_weapon_b2v2_net_gun",
		"draw_size": Vector2(42.0, 95.0),
		"pivot_primary": Vector2(20.0, 94.0),
		"pivot_secondary": Vector2.ZERO,
		"base_rot": 0.0,
	},
	WEAPON_BOWLING_TRAP: {
		"texture_key": "commando_weapon_b2v2_bowling_trap",
		"draw_size": Vector2(32.0, 75.0),
		"pivot_primary": Vector2(15.0, 74.0),
		"pivot_secondary": Vector2.ZERO,
		"base_rot": 0.0,
	},
	WEAPON_SUICIDE_DRONE: {
		"texture_key": "commando_weapon_b2v2_suicide_drone",
		"draw_size": Vector2(90.0, 90.0),
		"pivot_primary": Vector2(44.0, 89.0),
		"pivot_secondary": Vector2.ZERO,
		"base_rot": 0.0,
	},
}


## Returns the grip anchor for a given animation state + frame index.
## Falls back to `Vector2.ZERO` rotation 0 when the table is empty or
## the index is out of range, signaling "no overlay should be drawn".
func get_frame_anchor(animation_state: String, frame_index: int) -> Dictionary:
	if not FRAME_ANCHORS.has(animation_state):
		return {}
	var frames: Array = FRAME_ANCHORS[animation_state]
	if frames.is_empty():
		return {}
	var clamped: int = clamp(frame_index, 0, frames.size() - 1)
	var entry = frames[clamped]
	if not (entry is Dictionary):
		return {}
	return entry


## Returns the pivot + draw metadata for a given weapon id, or an empty
## Dictionary if the weapon is not configured (renderer skips overlay).
func get_weapon_pivot(weapon_id: String) -> Dictionary:
	if not WEAPON_PIVOTS.has(weapon_id):
		return {}
	var entry = WEAPON_PIVOTS[weapon_id]
	if not (entry is Dictionary):
		return {}
	return entry


## True when both the animation has at least one frame anchor AND the
## weapon is configured. Used by the renderer to decide whether to call
## the overlay draw path at all.
func is_overlay_renderable(animation_state: String, frame_index: int, weapon_id: String) -> bool:
	var frame_anchor: Dictionary = get_frame_anchor(animation_state, frame_index)
	if frame_anchor.is_empty():
		return false
	var weapon: Dictionary = get_weapon_pivot(weapon_id)
	if weapon.is_empty():
		return false
	# Required keys for a renderable overlay.
	if not (frame_anchor.has("primary") and frame_anchor["primary"] is Vector2):
		return false
	if not (weapon.has("pivot_primary") and weapon["pivot_primary"] is Vector2):
		return false
	if not (weapon.has("draw_size") and weapon["draw_size"] is Vector2):
		return false
	return true
