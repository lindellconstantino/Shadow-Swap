extends Control
## Loading screen that loads the next stage on a BACKGROUND THREAD.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const MIN_DISPLAY_TIME := 0.9   # keep the screen up briefly so the bar is readable
const TIPS := [
	"Tip: Faint barriers are ghosts - you can walk straight through them.",
	"Tip: You cannot shift realms while standing inside a barrier that would turn solid.",
	"Tip: Shadow Wisps only exist in the Shadow Realm.",
	"Tip: Sealed cages need the opposite realm to slip inside. Shift, collect, shift back.",
	"Tip: Press ESC at any time to pause.",
]

var _load_path: String = ""
var _elapsed: float = 0.0
var _started: bool = false
var _finished: bool = false
var _start_msec: int = 0
var _progress_bar: ProgressBar
var _status_label: Label
var _back_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_load_path = GameState.target_scene_path
	if _load_path.is_empty():
		_load_path = GameState.scene_path_for(1)
	if not ResourceLoader.exists(_load_path):
		_show_error("The stage file could not be found:\n%s" % _load_path)
		return
	_start_msec = Time.get_ticks_msec()
	# OS CONCEPT: Threads
	# load_threaded_request() asks Godot to load the scene on a separate worker thread,
	# so this screen keeps animating while the loading happens in the background.
	var request_error := ResourceLoader.load_threaded_request(_load_path)
	if request_error != OK:
		_show_error("Could not start background loading (error %d)." % request_error)
		return
	_started = true


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling - _process() polls the loader once per frame.
	if not _started or _finished:
		return
	_elapsed += delta
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_load_path, progress)
	var ratio: float = 0.0
	if progress.size() > 0:
		ratio = float(progress[0])
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		ratio = 1.0
	_progress_bar.value = lerpf(_progress_bar.value, ratio * 100.0, minf(1.0, delta * 8.0))
	_status_label.text = "ALIGNING THE REALMS...  %d%%" % int(_progress_bar.value)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if _elapsed >= MIN_DISPLAY_TIME:
			_finish_loading()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_show_error("The stage could not be loaded.")


func _finish_loading() -> void:
	_finished = true
	# The worker thread is done. The scene tree is only changed here, on the main thread.
	var packed_scene := ResourceLoader.load_threaded_get(_load_path) as PackedScene
	if packed_scene == null:
		_show_error("The loaded stage was not a valid scene.")
		return
	GameState.last_load_ms = Time.get_ticks_msec() - _start_msec
	_progress_bar.value = 100.0
	Transition.change_scene_packed(packed_scene)


func _show_error(message: String) -> void:
	_finished = true
	_status_label.text = message
	_progress_bar.visible = false
	_back_button.visible = true
	_back_button.grab_focus()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0a1022")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)

	var title := UiTheme.make_label("SHADOW SWAP", 38, UiTheme.COLOR_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stage_info := LevelData.get_stage(GameState.current_stage)
	var stage_label := UiTheme.make_label("STAGE %d  -  %s" % [GameState.current_stage, stage_info["name"]], 18, UiTheme.COLOR_GOLD, true)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stage_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(560, 22)
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = false
	box.add_child(_progress_bar)

	_status_label = UiTheme.make_label("PREPARING THE REALMS...", 14, UiTheme.COLOR_TEAL, true)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)

	var tip_label := UiTheme.make_label(TIPS[randi() % TIPS.size()], 13, UiTheme.COLOR_MUTED)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip_label)

	_back_button = UiTheme.make_button("BACK TO MAIN MENU", Vector2(280, 46))
	_back_button.visible = false
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(func() -> void: Transition.change_scene(MENU_SCENE))
	box.add_child(_back_button)
