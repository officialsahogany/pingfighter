extends RefCounted


static func snapshot(source: Array, copy_arrays: bool, deep: bool = true) -> Array:
	return source.duplicate(deep) if copy_arrays else source
