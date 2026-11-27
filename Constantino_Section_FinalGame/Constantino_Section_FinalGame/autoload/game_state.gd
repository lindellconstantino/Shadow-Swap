extends Node
## Global game state (autoload "GameState").
## Holds data that must survive scene changes, plus the counters that the
## OS-concept monitor (F3) and the memory experiment use.

# Custom signal (OS CONCEPT: Interrupts) - emitted when the memory experiment switch is flipped.
signal cleanup_mode_changed(enabled: bool)

# The keys the game needs. If the project's Input Map is missing one, it is added at startup.
const REQUIRED_KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"swap_realm": [KEY_SPACE],
	"interact": [KEY_E],
	"pause": [KEY_ESCAPE],
	"restart_game": [KEY_R],
	"toggle_mute": [KEY_M],
	"toggle_debug": [KEY_F3],
	"toggle_cleanup": [KEY_F4],
	"record_memory": [KEY_F9],
	"toggle_auto_walk": [KEY_F10],
}

var current_stage: int = 1
var target_scene_path: String = "res://scenes/levels/level_1.tscn"

# --- Memory management experiment (see docs/MEMORY_REPORT.md) ---
# true  = final game: every temporary object is freed with queue_free().
# false = "before" baseline: temporary objects are NOT freed, so they pile up.
var cleanup_enabled: bool = true
# Debug helper: makes the player walk by itself so a 2-minute measurement is repeatable.
var auto_walk: bool = false

# --- Counters shown in the F3 overlay ---
var objects_spawned: Dictionary = {}
var objects_freed: Dictionary = {}
var leaked_objects: int = 0
var last_signal_text: String = "(none yet)"
var last_input_text: String = "(none yet)"
var last_load_ms: int = -1


func _ready() -> void:
	_ensure_input_actions()


func start_new_game() -> void:
	prepare_stage(1)


func prepare_stage(stage: int) -> void:
	current_stage = clampi(stage, 1, LevelData.STAGE_COUNT)
	target_scene_path = scene_path_for(current_stage)


func scene_path_for(stage: int) -> String:
	return "res://scenes/levels/level_%d.tscn" % stage


func set_cleanup_enabled(enabled: bool) -> void:
	cleanup_enabled = enabled
	cleanup_mode_changed.emit(enabled)


# ---------------------------------------------------------------------------
# OS CONCEPT: Memory Management
# Every temporary object (trail echo, burst effect, wisp) is handed to
# dispose() when it is finished. In the final game this simply calls
# queue_free(). With cleanup switched OFF (F4) the objects are deliberately
# left behind so the "before" numbers can be measured in the Debugger.
# ---------------------------------------------------------------------------
func dispose(node: Node, kind: String) -> void:
	if cleanup_enabled:
		note_freed(kind)
		node.queue_free()
		return
	# --- Baseline (bug demonstration) only: the node is NOT freed. ---
	leaked_objects += 1
	if kind == "wisp":
		# Leak type 1: "forgot to call queue_free()". The node stays in the tree, hidden.
		node.set_process(false)
		if node is CanvasItem:
			(node as CanvasItem).hide()
	else:
		# Leak type 2: removed from the tree but never freed = an ORPHAN node.
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child.call_deferred(node)


func note_spawned(kind: String) -> void:
	objects_spawned[kind] = int(objects_spawned.get(kind, 0)) + 1


func note_freed(kind: String) -> void:
	objects_freed[kind] = int(objects_freed.get(kind, 0)) + 1


func reset_object_stats() -> void:
	objects_spawned.clear()
	objects_freed.clear()
	leaked_objects = 0


func total_spawned() -> int:
	var total: int = 0
	for kind in objects_spawned:
		total += int(objects_spawned[kind])
	return total


func total_freed() -> int:
	var total: int = 0
	for kind in objects_freed:
		total += int(objects_freed[kind])
	return total


func log_signal(text: String) -> void:
	last_signal_text = text


func log_input(text: String) -> void:
	last_input_text = text


func _ensure_input_actions() -> void:
	for action in REQUIRED_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var keycodes: Array = REQUIRED_KEYS[action]
		for keycode in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
