extends RefCounted

const STREET := &"street"
const RUNTIME_PERK := &"runtime_perk"
const CHARACTER_INFO := &"character_info"
const PLAZA_WARP := &"plaza_warp"
const BUILDING_TRANSITION := &"building_transition"
const INTERIOR_MENU := &"interior_menu"


static func resolve(
	runtime_perk_active: bool,
	character_info_active: bool,
	plaza_warp_active: bool,
	building_transition_active: bool,
	menu_open: bool
) -> StringName:
	if runtime_perk_active:
		return RUNTIME_PERK
	if character_info_active:
		return CHARACTER_INFO
	if plaza_warp_active:
		return PLAZA_WARP
	if building_transition_active:
		return BUILDING_TRANSITION
	if menu_open:
		return INTERIOR_MENU
	return STREET


static func blocks_street_update(gate: StringName) -> bool:
	return gate != STREET
