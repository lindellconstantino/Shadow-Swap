class_name StageEndScreen
extends CanvasLayer
## Shown when a stage is cleared. After the last stage it becomes the
## "Shadow Swap Complete" ending screen.

# Custom signals (OS CONCEPT: Interrupts).
signal next_requested
signal replay_requested
signal menu_requested

var _title_label: Label
var _body_label: Label
var _stats_label: Label
var _button_box: VBoxContainer
var _primary_button: Button


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


# result comes from SaveManager.record_stage_clear(): {"new_best": bool, "best_time": float}
func show_result(stage: int, shards: int, total_shards: int, seconds: float, result: Dictionary) -> void:
	var is_final: bool = stage >= LevelData.STAGE_COUNT
	if is_final:
		_title_label.text = "SHADOW SWAP COMPLETE"
		_body_label.text = "You restored the balance between both realms.\nEvery memory has been recovered."
		_primary_button.text = "PLAY AGAIN FROM STAGE 1"
	else:
		_title_label.text = "STAGE %d CLEARED" % stage
		_body_label.text = "The eclipse fades. A new path opens beyond the ruins."
		_primary_button.text = "NEXT STAGE"
	var best_text := "NEW BEST TIME!" if bool(result.get("new_best", false)) else "Best: %s" % UiTheme.format_time(float(result.get("best_time", seconds)))
	_stats_label.text = "Shards  %d / %d        Time  %s\n%s" % [shards, total_shards, UiTheme.format_time(seconds), best_text]
	visible = true
	_primary_button.grab_focus()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.COLOR_PANEL, UiTheme.COLOR_TEAL, 26))
	center.add_child(panel)
	_button_box = VBoxContainer.new()
	_button_box.add_theme_constant_override("separation", 12)
	panel.add_child(_button_box)

	_title_label = UiTheme.make_label("STAGE CLEARED", 28, UiTheme.COLOR_TEXT, true)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button_box.add_child(_title_label)
	_body_label = UiTheme.make_label("", 15, Color("c4d1e8"))
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button_box.add_child(_body_label)
	_stats_label = UiTheme.make_label("", 16, UiTheme.COLOR_GOLD, true)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button_box.add_child(_stats_label)

	_primary_button = UiTheme.make_button("NEXT STAGE", Vector2(300, 48))
	_primary_button.pressed.connect(func() -> void: next_requested.emit())
	_button_box.add_child(_primary_button)
	var replay_button := UiTheme.make_button("REPLAY STAGE", Vector2(300, 46))
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	_button_box.add_child(replay_button)
	var menu_button := UiTheme.make_button("MAIN MENU", Vector2(300, 46))
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_button_box.add_child(menu_button)
