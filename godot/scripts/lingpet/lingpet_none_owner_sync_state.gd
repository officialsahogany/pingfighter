extends RefCounted

var _has_synced := false


func update_none_state(
	owner: Object,
	registry: Object,
	collection_state: Object,
	host: Object
) -> bool:
	# Junior League keeps the egg/companion auto-present from battle start
	# (tutorial convenience). In Pro / Mythic leagues the lingpet must be earned
	# mid-battle through the lingpet_egg item, so the runtime stays STATE_NONE and
	# performs only a one-shot owner sync until the item deploys an egg.
	if collection_state == null or host == null:
		return false
	if not bool(collection_state.is_auto_present_league(owner)):
		_sync_owner_once(owner, registry, host)
		return false
	var owned_pet_id: String = str(collection_state.find_active_slot_pet_id(owner))
	if owned_pet_id != "":
		if host.has_method("_adopt_owned_pet"):
			host.call("_adopt_owned_pet", owner, owned_pet_id, registry)
			return true
		return false
	if bool(collection_state.should_spawn_egg(owner)):
		if host.has_method("_spawn_egg"):
			host.call("_spawn_egg", owner, registry)
			return true
		return false
	_sync_owner_once(owner, registry, host)
	return false


func should_sync_once() -> bool:
	if _has_synced:
		return false
	_has_synced = true
	return true


func reset() -> void:
	_has_synced = false


func _sync_owner_once(owner: Object, registry: Object, host: Object) -> void:
	if not should_sync_once():
		return
	if host != null and host.has_method("_sync_owner"):
		host.call("_sync_owner", owner, registry)
