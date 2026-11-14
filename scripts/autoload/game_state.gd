extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds narrative flags and coordinates
## single-slot persistence to user://save.json (Steam Cloud friendly).

signal state_changed

const DEFAULT_SCENE := "res://scenes/game.tscn"
const SAVE_PATH := "user://save.json"
const SAVE_TMP_PATH := "user://save.json.tmp"
const SAVE_BAK_PATH := "user://save.json.bak"
const SAVE_VERSION := 2

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = DEFAULT_SCENE


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	Journal.clear()
	current_scene = DEFAULT_SCENE
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BAK_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags.duplicate(true),
		"journal": Journal.to_save_data(),
	}
	var json_text := JSON.stringify(payload, "\t")

	var file := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open temp save file for writing.")
		return false
	file.store_string(json_text)
	file.flush()
	file.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("GameState: could not open user:// directory.")
		return false
	if dir.file_exists("save.json"):
		dir.copy("save.json", "save.json.bak")
	var err := dir.rename("save.json.tmp", "save.json")
	if err != OK:
		push_error("GameState: failed to finalize save file (err %d)." % err)
		return false
	return true


func load_game() -> bool:
	var data := _read_save_dict(SAVE_PATH)
	if data.is_empty() and FileAccess.file_exists(SAVE_BAK_PATH):
		push_warning("GameState: primary save unreadable; falling back to backup.")
		data = _read_save_dict(SAVE_BAK_PATH)
	if data.is_empty():
		return false

	var scene_path := str(data.get("scene", DEFAULT_SCENE))
	current_scene = scene_path if ResourceLoader.exists(scene_path) else DEFAULT_SCENE

	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags.duplicate(true) if typeof(loaded_flags) == TYPE_DICTIONARY else {}

	var version := int(data.get("version", 1))
	if version >= 2 and data.has("journal"):
		Journal.from_save_data(data["journal"])
	else:
		Journal.clear()

	state_changed.emit()
	return true


func delete_save() -> void:
	for path in [SAVE_PATH, SAVE_BAK_PATH, SAVE_TMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read_save_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
## choices and persists them to user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	current_scene = "res://scenes/game.tscn"
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	# Future-proofing: migrate older save versions here.
	current_scene = data.get("scene", "res://scenes/game.tscn")
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
