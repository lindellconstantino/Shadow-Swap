extends Node
## Saving and loading progress (autoload "SaveManager").
##
## OS CONCEPT: File Systems
## "user://" is a folder the operating system lets the game write to, even
## after the game is exported. Data saved there is still present when the game
## is closed and opened again. (Project > Open User Data Folder shows it.)

const SAVE_PATH := "user://shadow_swap_save.json"
const SAVE_VERSION := 1

# A short sentence describing what the last save/load did (shown in the System panel).
var last_status: String = "Save file not checked yet."


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"unlocked_stage": 1,
		"last_stage": 1,
		"total_shards": 0,
		"best_times": {},
		"completed": false,
		"muted": false,
	}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_progress(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		last_status = "Could not write the save file (error %d)." % FileAccess.get_open_error()
		push_warning(last_status)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	last_status = "Progress saved to user://shadow_swap_save.json"
	return true


# Always returns a complete, valid dictionary - never crashes on a missing or damaged file.
func load_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		last_status = "No save file yet. Using default progress."
		return default_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		last_status = "Save file could not be opened. Using default progress."
		return default_data()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		last_status = "Save file is damaged (invalid JSON). Using default progress."
		return default_data()
	if typeof(json.data) != TYPE_DICTIONARY:
		last_status = "Save file has the wrong format. Using default progress."
		return default_data()
	var raw: Dictionary = json.data
	last_status = "Save file loaded."
	return _sanitize(raw)


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("shadow_swap_save.json"):
		dir.remove("shadow_swap_save.json")
	last_status = "Save file erased."


# Called by the level when a stage is finished. Returns info for the end screen.
func record_stage_clear(stage: int, seconds: float, shards: int) -> Dictionary:
	var data := load_progress()
	var key := str(stage)
	var best_times: Dictionary = data["best_times"]
	var previous_best: float = float(best_times.get(key, 0.0))
	var is_new_best: bool = previous_best <= 0.0 or seconds < previous_best
	if is_new_best:
		best_times[key] = snappedf(seconds, 0.01)
	data["best_times"] = best_times
	data["unlocked_stage"] = mini(maxi(int(data["unlocked_stage"]), stage + 1), LevelData.STAGE_COUNT)
	data["last_stage"] = stage
	data["total_shards"] = int(data["total_shards"]) + shards
	if stage >= LevelData.STAGE_COUNT:
		data["completed"] = true
	save_progress(data)
	return {"new_best": is_new_best, "best_time": float(best_times[key])}


func is_muted() -> bool:
	return bool(load_progress()["muted"])


func set_muted(muted: bool) -> void:
	var data := load_progress()
	data["muted"] = muted
	save_progress(data)


# Copies only known keys and checks every value's type and range, so a hand-edited
# or corrupted file can never put the game into a broken state.
func _sanitize(raw: Dictionary) -> Dictionary:
	var data := default_data()
	if _is_number(raw.get("unlocked_stage")):
		data["unlocked_stage"] = clampi(int(raw["unlocked_stage"]), 1, LevelData.STAGE_COUNT)
	if _is_number(raw.get("last_stage")):
		data["last_stage"] = clampi(int(raw["last_stage"]), 1, LevelData.STAGE_COUNT)
	if _is_number(raw.get("total_shards")):
		data["total_shards"] = maxi(int(raw["total_shards"]), 0)
	if typeof(raw.get("completed")) == TYPE_BOOL:
		data["completed"] = raw["completed"]
	if typeof(raw.get("muted")) == TYPE_BOOL:
		data["muted"] = raw["muted"]
	if typeof(raw.get("best_times")) == TYPE_DICTIONARY:
		var clean_times: Dictionary = {}
		var raw_times: Dictionary = raw["best_times"]
		for key in raw_times:
			var key_text := str(key)
			if key_text.is_valid_int() and _is_number(raw_times[key]) and float(raw_times[key]) > 0.0:
				clean_times[key_text] = float(raw_times[key])
		data["best_times"] = clean_times
	return data


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
