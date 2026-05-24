extends SceneTree

func _initialize() -> void:
	var paths: Array[String] = []
	_collect_scripts("res://scripts", paths)
	_collect_scripts("res://tests", paths)
	_collect_scripts("res://tools", paths)
	paths.sort()
	print("gd_warning_scan: scanning %d scripts" % paths.size())
	var verbose_files := OS.get_cmdline_user_args().has("--verbose-files")
	for index in range(paths.size()):
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
		print("gd_warning_scan: checked %d/%d" % [paths.size(), paths.size()])
	print("gd_warning_scan: done")
	quit()


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
