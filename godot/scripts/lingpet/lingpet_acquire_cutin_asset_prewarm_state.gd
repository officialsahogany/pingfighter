extends RefCounted

var done_for_pet_id := ""


func reset() -> void:
	done_for_pet_id = ""


func prewarm_step(
	pet_id: String,
	host: Object,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> bool:
	if pet_id == "":
		return true
	if done_for_pet_id == pet_id:
		return true
	if host == null or not host.has_method("prewarm_pet_assets_step"):
		return false
	var finished := false
	if perf_label_prefix != "":
		finished = bool(host.prewarm_pet_assets_step(pet_id, false, perf_logger, perf_label_prefix))
	else:
		finished = bool(host.prewarm_pet_assets_step(pet_id))
	if finished:
		done_for_pet_id = pet_id
		return true
	return false


func prewarm_registry_step(
	pet_id: String,
	registry: Object,
	overlay_host_resolver: Object,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> bool:
	if registry == null or overlay_host_resolver == null or not overlay_host_resolver.has_method("resolve"):
		return false
	return prewarm_step(pet_id, overlay_host_resolver.resolve(registry), perf_logger, perf_label_prefix)
