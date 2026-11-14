extends Node
## Journal — discovered-logs system.
##
## Autoloaded as `Journal`. Stores canonical entry IDs (localization-safe)
## and persists them inside GameState's single user://save.json slot.

signal entry_added(id: String)
signal cleared
signal loaded

var _entries: Array[String] = []


func discover(id: String) -> void:
	var clean_id := id.strip_edges()
	if clean_id == "" or clean_id in _entries:
		return
	_entries.append(clean_id)
	entry_added.emit(clean_id)


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


func clear() -> void:
	_entries.clear()
	cleared.emit()


func to_save_data() -> Dictionary:
	return {
		"entries": _entries.duplicate(),
	}


func from_save_data(data: Variant) -> void:
	_entries.clear()
	var raw: Variant = []
	if typeof(data) == TYPE_DICTIONARY:
		raw = data.get("entries", [])
	elif typeof(data) == TYPE_ARRAY:
		raw = data

	if typeof(raw) != TYPE_ARRAY:
		loaded.emit()
		return

	for item in raw:
		if item == null:
			continue
		var clean_id := str(item).strip_edges()
		if clean_id != "" and not (clean_id in _entries):
			_entries.append(clean_id)
	loaded.emit()
