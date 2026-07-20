extends RefCounted

# Perk-driven cosmetic part manifest: maps an owned runtime perk to a
# socket-anchored customization overlay entry, so acquiring the perk changes
# the character's appearance through runtime composition instead of baked
# sheet variants (socket composition contract, lane A --
# docs/sprite_socket_composition_contract.md).
#
# Injection rules (battle_draw_actor_context):
#  - a part is injected only while its perk is owned (level > 0)
#  - an existing user customization entry in the same slot always wins
#  - the part texture must already be loaded in the battle texture cache
#    (BattleResources spec) -- parts never load from disk on the draw path
#
# Coordinates in `entry` are in the authored socket cell space (160px) and
# scale with the live body draw via the overlay renderer's socket placement.

const PARTS := {
	"item_luck": {
		"slot_id": "accessory",
		"texture_key": "perk_visual_part_lucky_coin",
		"entry": {
			"texture_key": "perk_visual_part_lucky_coin",
			"socket_id": "head_top",
			"socket_offset": Vector2(0.0, -15.0),
			"socket_part_size": Vector2(20.0, 20.0),
			"grid_cols": 1,
			"grid_rows": 1,
			"frame_count": 1,
			"cell_width": 1024.0,
			"cell_height": 1024.0,
		},
	},
}


# Projects the owner's runtime perk levels down to just the manifest perks
# (draw-path consumers get a tiny bounded dict, never the raw perk dict).
static func project_owned_levels(perk_levels: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	for perk_id in PARTS:
		var level: int = int(perk_levels.get(perk_id, 0))
		if level > 0:
			owned[perk_id] = level
	return owned


static func texture_keys() -> Array:
	var keys: Array = []
	for perk_id in PARTS:
		var texture_key := str((PARTS[perk_id] as Dictionary).get("texture_key", ""))
		if texture_key != "" and not keys.has(texture_key):
			keys.append(texture_key)
	return keys


# Merges owned parts into the overlay slot dict (mutates the passed copies the
# actor context already duplicated). User customization entries keep priority;
# parts whose texture is absent from overlay_textures are skipped fail-closed.
static func inject_overlay_slots(
	overlay_slots: Dictionary,
	overlay_textures: Dictionary,
	owned_levels: Dictionary
) -> void:
	for perk_id in owned_levels:
		if int(owned_levels.get(perk_id, 0)) <= 0:
			continue
		var part: Variant = PARTS.get(perk_id, null)
		if not (part is Dictionary):
			continue
		var part_dict: Dictionary = part
		var slot_id := str(part_dict.get("slot_id", ""))
		if slot_id == "" or overlay_slots.has(slot_id):
			continue
		var texture_key := str(part_dict.get("texture_key", ""))
		if not (overlay_textures.get(texture_key, null) is Texture2D):
			continue
		var entry: Variant = part_dict.get("entry", null)
		if not (entry is Dictionary):
			continue
		overlay_slots[slot_id] = (entry as Dictionary).duplicate(true)
