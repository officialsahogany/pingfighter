extends RefCounted

const PREFIX := "perk_fusion_pair:"


static func build(fusion_id: String, fusion_revision: int, sources: Array) -> String:
	if sources.size() != 2:
		return "perk_fusion"
	var left := str(sources[0]).strip_edges()
	var right := str(sources[1]).strip_edges()
	if left.is_empty() or right.is_empty() or left == right:
		return "perk_fusion"
	var clean_fusion_id := fusion_id.strip_edges()
	if clean_fusion_id.is_empty():
		clean_fusion_id = "fusion"
	return "%s%s@%d|%s|%s" % [
		PREFIX,
		clean_fusion_id,
		maxi(0, fusion_revision),
		left,
		right,
	]


static func parse(draw_id: String) -> Dictionary:
	if not draw_id.begins_with(PREFIX):
		return {}
	var parts := draw_id.trim_prefix(PREFIX).split("|", false)
	if parts.size() != 3:
		return {}
	var metadata := str(parts[0])
	var separator := metadata.rfind("@")
	if separator <= 0:
		return {}
	var fusion_id := metadata.left(separator).strip_edges()
	var revision_text := metadata.substr(separator + 1)
	if fusion_id.is_empty() or not revision_text.is_valid_int():
		return {}
	var fusion_revision := maxi(0, int(revision_text))
	var sources: Array[String] = []
	for index in range(1, 3):
		var source_id := str(parts[index]).strip_edges()
		if source_id.is_empty() or source_id in sources:
			return {}
		sources.append(source_id)
	return {
		"fusion_id": fusion_id,
		"fusion_revision": fusion_revision,
		"sources": sources,
	}
