class_name VfxLibrary
extends RefCounted
## Loads a one-shot effect's frames from game/assets/vfx/<effect_id>/frame_NN.png.
##
## Deliberately not the LPC pipeline: these are flat sprite-sheet cutouts, not a
## paperdoll with directions and zPos layers. Same rule as everywhere else in
## the art pipeline though — frames are read straight off disk, cached once.

static var _cache: Dictionary = {}


static func frames_for(effect_id: String) -> Array[Texture2D]:
	if _cache.has(effect_id):
		return _cache[effect_id]

	var out: Array[Texture2D] = []
	var dir_path := "res://assets/vfx/%s" % effect_id
	var dir := DirAccess.open(dir_path)
	if dir:
		var names: Array = []
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".png"):
				names.append(f)
			f = dir.get_next()
		dir.list_dir_end()
		names.sort()
		for name in names:
			var tex := load("%s/%s" % [dir_path, name]) as Texture2D
			if tex:
				out.append(tex)

	_cache[effect_id] = out
	return out
