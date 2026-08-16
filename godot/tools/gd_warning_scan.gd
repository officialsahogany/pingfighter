extends SceneTree

func _initialize() -> void:
	var paths: Array[String] = []
	_collect_scripts("res://scripts", paths)
	_collect_scripts("res://tests", paths)
	_collect_scripts("res://tools", paths)
	paths.sort()
	var include_paths := _get_string_args("--include-path=")
	if not include_paths.is_empty():
		var all_paths := paths
		paths = []
		for include_path in include_paths:
			if not all_paths.has(include_path):
				push_error("gd_warning_scan: requested path not found: %s" % include_path)
				continue
			if not paths.has(include_path):
				paths.append(include_path)
		paths.sort()
	print("gd_warning_scan: scanning %d scripts" % paths.size())
	var args := OS.get_cmdline_user_args()
	var verbose_files := args.has("--verbose-files")
	var start_index := clampi(_get_int_arg("--start-index=", 0), 0, paths.size())
	var max_count := _get_int_arg("--max-count=", -1)
	var end_index := paths.size()
	if max_count >= 0:
		end_index = min(paths.size(), start_index + max_count)
	if start_index > 0 or end_index < paths.size():
		print("gd_warning_scan: chunk %d..%d/%d" % [start_index, end_index, paths.size()])
	for index in range(start_index, end_index):
		var path := paths[index]
		if verbose_files:
			print("gd_warning_scan: check %s" % path)
		elif index % 100 == 0:
			print("gd_warning_scan: checked %d/%d" % [index, paths.size()])
		if path == "res://tools/gd_warning_scan.gd":
			continue
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script is GDScript:
			script.reload(true)
		script = null
		if not verbose_files and index > 0 and index % 50 == 0:
			OS.delay_msec(1)
	if not verbose_files:
		print("gd_warning_scan: checked %d/%d" % [end_index, paths.size()])
	print("gd_warning_scan: done")
	quit()


func _get_int_arg(prefix: String, default_value: int) -> int:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with(prefix):
			return int(text.substr(prefix.length()))
	return default_value


func _get_string_args(prefix: String) -> Array[String]:
	var values: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with(prefix):
			values.append(text.substr(prefix.length()))
	return values


func _collect_scripts(dir_path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_scripts(child_path, paths)
		elif entry.ends_with(".gd"):
			paths.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
