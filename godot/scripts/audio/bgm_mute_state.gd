extends RefCounted

const BGM_MUTED_META := "bgm_muted"
const LEGACY_MAIN_MENU_BGM_MUTED_META := "main_menu_bgm_muted"


static func is_muted(tree: SceneTree) -> bool:
	var root := _get_root(tree)
	if root == null:
		return false
	if root.has_meta(BGM_MUTED_META):
		return bool(root.get_meta(BGM_MUTED_META, false))
	return bool(root.get_meta(LEGACY_MAIN_MENU_BGM_MUTED_META, false))


static func set_muted(tree: SceneTree, muted: bool) -> bool:
	var root := _get_root(tree)
	if root != null:
		root.set_meta(BGM_MUTED_META, muted)
		root.set_meta(LEGACY_MAIN_MENU_BGM_MUTED_META, muted)
	return muted


static func toggle(tree: SceneTree) -> bool:
	return set_muted(tree, not is_muted(tree))


static func _get_root(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root
