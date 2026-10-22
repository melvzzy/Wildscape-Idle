class_name SaveGame
extends RefCounted

const PATH: String = "user://save_v1.json"
const VERSION: int = 1
const MAX_FILE_BYTES: int = 65536

static func save_state(state: GameState, path: String = PATH) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "state": state.snapshot()}))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	# Replace only after the complete temporary file has been flushed.
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

static func load_state(state: GameState, path: String = PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return ERR_FILE_CORRUPT
	var text := file.get_as_text()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return ERR_FILE_CORRUPT
	var data: Variant = parser.data
	if not data is Dictionary:
		return ERR_FILE_CORRUPT
	if not data.get("version") is float and not data.get("version") is int:
		return ERR_FILE_CORRUPT
	if data.version != VERSION or not data.get("state") is Dictionary:
		return ERR_FILE_CORRUPT
	if not state.restore(data.state):
		return ERR_FILE_CORRUPT
	return OK
