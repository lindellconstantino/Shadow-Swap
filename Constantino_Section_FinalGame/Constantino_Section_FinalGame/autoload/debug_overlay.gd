extends CanvasLayer
## Developer overlay (autoload "DebugOverlay"). Press F3 to show/hide it.
## It makes every OS concept visible while the game runs, which helps during the oral defense.
##
##   F3  show / hide this panel
##   F4  memory cleanup ON/OFF  (OFF = the "before" baseline used in the memory report)
##   F9  start / stop recording memory numbers to user://memory_log.csv (one row every 5 s)
##   F10 auto-walk: the player walks by itself, for a repeatable 2-minute measurement
##
## OS CONCEPT: I/O Management (event-driven) - these keys are handled in _unhandled_input().

const LOG_PATH := "user://memory_log.csv"
const LOG_INTERVAL := 5.0

var _panel: PanelContainer
var _label: Label
var _recording: bool = false
var _record_time: float = 0.0
var _log_timer: float = 0.0
var _refresh_timer: float = 0.0


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_panel.visible = not _panel.visible
		GameState.log_input("F3 pressed (event) -> toggle overlay")
	elif event.is_action_pressed("toggle_cleanup"):
		GameState.set_cleanup_enabled(not GameState.cleanup_enabled)
		GameState.log_input("F4 pressed (event) -> cleanup %s" % ("ON" if GameState.cleanup_enabled else "OFF"))
	elif event.is_action_pressed("record_memory"):
		_toggle_recording()
	elif event.is_action_pressed("toggle_auto_walk"):
		GameState.auto_walk = not GameState.auto_walk
		GameState.log_input("F10 pressed (event) -> auto-walk %s" % ("ON" if GameState.auto_walk else "OFF"))


func _process(delta: float) -> void:
	if _recording:
		_record_time += delta
		_log_timer += delta
		if _log_timer >= LOG_INTERVAL:
			_log_timer = 0.0
			_append_log_row()
	if not _panel.visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.2:
		_refresh_timer = 0.0
		_label.text = _build_text()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(10, 118)
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.03, 0.05, 0.1, 0.86), Color("3f6a5c"), 10))
	_label = UiTheme.make_label("", 12, Color("c9f5e6"))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	add_child(_panel)


func _build_text() -> String:
	var lines: PackedStringArray = []
	lines.append("OS CONCEPT MONITOR   (F3 hide)")
	lines.append("")
	lines.append("[8] PLATFORM  %s - %s" % [PlatformInfo.get_platform_name(), PlatformInfo.get_build_label()])
	lines.append("[1] PROCESSES  spawned %d | freed %d | alive %d" % [
		GameState.total_spawned(), GameState.total_freed(),
		GameState.total_spawned() - GameState.total_freed() - GameState.leaked_objects])
	lines.append("      " + _kind_summary())
	lines.append("[2] SCHEDULING  %d FPS | physics %d/s" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second])
	lines.append("      process frames %d | physics frames %d" % [Engine.get_process_frames(), Engine.get_physics_frames()])
	lines.append("[3] INTERRUPTS  last signal:")
	lines.append("      " + GameState.last_signal_text)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	lines.append("[4] I/O  polled move (%.1f, %.1f)" % [move.x, move.y])
	lines.append("      last event: " + GameState.last_input_text)
	lines.append("[5] MEMORY  cleanup: %s  (F4)" % ("ON" if GameState.cleanup_enabled else "OFF - leaking!"))
	lines.append("      nodes %s | orphans %s | static %s" % [_monitor_text(Performance.OBJECT_NODE_COUNT, false), _monitor_text(Performance.OBJECT_ORPHAN_NODE_COUNT, false), _monitor_text(Performance.MEMORY_STATIC, true)])
	lines.append("      leaked objects: %d" % GameState.leaked_objects)
	lines.append("[6] FILES  " + SaveManager.last_status)
	var load_text := "not used yet" if GameState.last_load_ms < 0 else "%d ms" % GameState.last_load_ms
	lines.append("[7] THREADS  last threaded load: " + load_text)
	lines.append("")
	if _recording:
		lines.append("REC  memory log  %ds  (F9 stop)" % int(_record_time))
	else:
		lines.append("F9 record memory log   F10 auto-walk: %s" % ("ON" if GameState.auto_walk else "off"))
	return "\n".join(lines)


func _kind_summary() -> String:
	var parts: PackedStringArray = []
	for kind in GameState.objects_spawned:
		var spawned: int = int(GameState.objects_spawned[kind])
		var freed: int = int(GameState.objects_freed.get(kind, 0))
		parts.append("%s %d/%d" % [kind, freed, spawned])
	return "freed/spawned: " + (", ".join(parts) if not parts.is_empty() else "-")


# Some monitors only exist in the editor / debug builds. Show "n/a" instead of a misleading 0.
func _monitor_text(monitor: Performance.Monitor, as_megabytes: bool) -> String:
	var value: float = Performance.get_monitor(monitor)
	if as_megabytes:
		return "%.1f MB" % (value / 1048576.0) if value > 0.0 else "n/a"
	return "%d" % int(value)


func _toggle_recording() -> void:
	_recording = not _recording
	GameState.log_input("F9 pressed (event) -> memory log %s" % ("recording" if _recording else "stopped"))
	if _recording:
		_record_time = 0.0
		_log_timer = 0.0
		_append_log_row()


# Appends one line to user://memory_log.csv. The report compares a run with cleanup OFF
# and a run with cleanup ON. (OS CONCEPT: File Systems + Memory Management)
func _append_log_row() -> void:
	var file: FileAccess
	if FileAccess.file_exists(LOG_PATH):
		file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if file != null:
			file.store_line("time_s,cleanup,nodes,orphan_nodes,static_mb,leaked_objects")
	if file == null:
		return
	var static_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	file.store_line("%d,%s,%d,%d,%.2f,%d" % [
		int(_record_time), "ON" if GameState.cleanup_enabled else "OFF",
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		static_mb, GameState.leaked_objects])
	file.close()
