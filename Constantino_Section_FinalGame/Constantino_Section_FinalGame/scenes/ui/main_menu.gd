extends Control
## Title screen: Play, Continue, Stage Select, How To Play, System Info, Quit.

const LOADING_SCENE := "res://scenes/ui/loading_screen.tscn"

var save_data: Dictionary = {}
var _time: float = 0.0
var _stars: Array[Vector3] = []          # x, y, twinkle speed
var _continue_button: Button
var _play_button: Button
var _modal: Control = null
var _erase_armed: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append(Vector3(rng.randf_range(0.0, 960.0), rng.randf_range(0.0, 640.0), rng.randf_range(0.6, 2.4)))
	save_data = SaveManager.load_progress()
	_build_ui()
	_play_button.grab_focus()


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling - the animated background advances with delta every frame.
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# OS CONCEPT: I/O Management (event-driven): ESC closes an open panel.
	if event.is_action_pressed("pause") and _modal != null:
		_close_modal()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var sz := size
	# Vertical gradient background.
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
		PackedColorArray([Color("0a1022"), Color("0a1022"), Color("1a1233"), Color("1a1233")]))
	for star in _stars:
		var twinkle := 0.5 + 0.5 * sin(_time * star.z + star.x)
		draw_circle(Vector2(star.x, star.y), 1.0 + twinkle * 1.2, Color("9fb4ee", 0.2 + twinkle * 0.45))
	# Two overlapping "realms": a Material ring (teal) and a Shadow ring (violet).
	var centre := Vector2(sz.x * 0.74, sz.y * 0.46)
	draw_circle(centre, 150.0, Color("8b5bd1", 0.07))
	draw_circle(centre + Vector2(48, 10), 118.0, Color("5ff3d8", 0.05))
	draw_arc(centre, 128.0, _time * 0.25, _time * 0.25 + TAU * 0.78, 72, Color("9f78eb", 0.5), 3.0)
	draw_arc(centre + Vector2(48, 10), 100.0, -_time * 0.3 + 1.0, -_time * 0.3 + 1.0 + TAU * 0.7, 72, Color("6ce5d5", 0.5), 3.0)
	# Floating memory shards.
	for i in 5:
		var angle := _time * 0.35 + i * TAU / 5.0
		var shard_pos := centre + Vector2(cos(angle) * 170.0, sin(angle) * 120.0 + sin(_time * 2.0 + i) * 6.0)
		var diamond := PackedVector2Array([
			shard_pos + Vector2(0, -11), shard_pos + Vector2(8, 0),
			shard_pos + Vector2(0, 11), shard_pos + Vector2(-8, 0)])
		draw_colored_polygon(diamond, Color("ffe69c", 0.9))


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 64)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 36)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 40)
	margin.add_child(layout)

	# --- Left: title ---
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	layout.add_child(left)
	var title := UiTheme.make_label("SHADOW\nSWAP", 64, UiTheme.COLOR_TEXT, true)
	title.add_theme_color_override("font_shadow_color", Color("6c52a8", 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	left.add_child(title)
	left.add_child(UiTheme.make_label("A REALM-SHIFTING PUZZLE ADVENTURE", 14, UiTheme.COLOR_MUTED, true))
	var description := UiTheme.make_label("Two worlds. One path.\nCollect the memory shards and find the Eclipse Gate.", 17, Color("c8d5e9"))
	left.add_child(description)
	var footer := UiTheme.make_label("Final Period Edition   |   %s  -  %s" % [PlatformInfo.get_platform_name(), PlatformInfo.get_build_label()], 12, Color("6f83a4"))
	left.add_child(footer)

	# --- Right: buttons ---
	var right := PanelContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(right)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	right.add_child(column)

	_play_button = UiTheme.make_button("PLAY", Vector2(270, 48))
	_play_button.pressed.connect(_on_play_pressed)
	column.add_child(_play_button)

	_continue_button = UiTheme.make_button("CONTINUE", Vector2(270, 48))
	_continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(_continue_button)
	_refresh_continue_button()

	var select_button := UiTheme.make_button("STAGE SELECT", Vector2(270, 48))
	select_button.pressed.connect(_open_stage_select)
	column.add_child(select_button)

	var help_button := UiTheme.make_button("HOW TO PLAY", Vector2(270, 48))
	help_button.pressed.connect(_open_how_to_play)
	column.add_child(help_button)

	var system_button := UiTheme.make_button("SYSTEM INFO", Vector2(270, 48))
	system_button.pressed.connect(_open_system_info)
	column.add_child(system_button)

	var quit_button := UiTheme.make_button("QUIT", Vector2(270, 48))
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit_button)


func _refresh_continue_button() -> void:
	if SaveManager.has_save():
		_continue_button.disabled = false
		_continue_button.text = "CONTINUE  -  STAGE %d" % int(save_data["unlocked_stage"])
	else:
		_continue_button.disabled = true
		_continue_button.text = "CONTINUE"


func _on_play_pressed() -> void:
	GameState.start_new_game()
	Transition.change_scene(LOADING_SCENE)


func _on_continue_pressed() -> void:
	_start_stage(int(save_data["unlocked_stage"]))


func _start_stage(stage: int) -> void:
	GameState.prepare_stage(stage)
	Transition.change_scene(LOADING_SCENE)


# ---------------------------------------------------------------------------
# Pop-up panels (all built from containers so they stay centred)
# ---------------------------------------------------------------------------
func _begin_modal(title_text: String) -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := UiTheme.make_label(title_text, 26, UiTheme.COLOR_TEXT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	_modal.modulate.a = 0.0
	create_tween().tween_property(_modal, "modulate:a", 1.0, 0.15)
	return box


func _end_modal(box: VBoxContainer, back_text: String = "BACK") -> void:
	var back_button := UiTheme.make_button(back_text, Vector2(220, 44))
	back_button.pressed.connect(_close_modal)
	box.add_child(back_button)
	back_button.grab_focus()


func _close_modal() -> void:
	_erase_armed = false
	if _modal != null:
		_modal.queue_free()
		_modal = null
	if _play_button != null:
		_play_button.grab_focus()


func _open_how_to_play() -> void:
	var box := _begin_modal("HOW TO PLAY")
	var goal := UiTheme.make_label("GOAL\nCollect every glowing memory shard, then stand at the\nEclipse Gate and press E.", 15, UiTheme.COLOR_GOLD)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(goal)
	var controls := UiTheme.make_label(
		"WASD / ARROW KEYS    Move\nSPACE    Shift between the Material and Shadow realms\nE    Use the Eclipse Gate\nESC    Pause          R    Restart stage          M    Sound on/off", 15)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(controls)
	var tips := UiTheme.make_label(
		"TIPS\nTeal barriers are solid only in the Material Realm.\nPurple barriers are solid only in the Shadow Realm.\nFaint barriers are ghosts: you can walk through them.\nYou cannot shift while standing inside a barrier that would turn solid.\nFrom Stage 2, Shadow Wisps drift in the Shadow Realm. Touching one\nsends you back to the glowing anchor.", 14, Color("c4d1e8"))
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tips)
	_end_modal(box)


func _open_stage_select() -> void:
	var box := _begin_modal("STAGE SELECT")
	var unlocked: int = int(save_data["unlocked_stage"])
	var best_times: Dictionary = save_data["best_times"]
	for stage in range(1, LevelData.STAGE_COUNT + 1):
		var info: Dictionary = LevelData.get_stage(stage)
		var line := "STAGE %d  -  %s" % [stage, info["name"]]
		if best_times.has(str(stage)):
			line += "   (best %s)" % UiTheme.format_time(float(best_times[str(stage)]))
		var stage_button := UiTheme.make_button(line, Vector2(420, 46))
		if stage > unlocked:
			stage_button.text = "STAGE %d  -  LOCKED" % stage
			stage_button.disabled = true
		else:
			stage_button.pressed.connect(_start_stage.bind(stage))
		box.add_child(stage_button)
	_end_modal(box)


func _open_system_info() -> void:
	# OS CONCEPT: OS as a Platform - this panel shows what the operating system reports.
	var box := _begin_modal("SYSTEM INFO")
	var info_label := UiTheme.make_label(PlatformInfo.get_summary(), 13, Color("c4d1e8"))
	box.add_child(info_label)
	var status_label := UiTheme.make_label("Save status: %s" % SaveManager.last_status, 13, UiTheme.COLOR_GOLD)
	box.add_child(status_label)
	var keys_label := UiTheme.make_label("Developer keys in game:  F3 OS monitor   F4 memory cleanup on/off\nF9 record memory log   F10 auto-walk test", 12, UiTheme.COLOR_MUTED)
	box.add_child(keys_label)
	var open_button := UiTheme.make_button("OPEN SAVE FOLDER", Vector2(300, 44))
	open_button.pressed.connect(PlatformInfo.open_save_folder)
	box.add_child(open_button)
	var erase_button := UiTheme.make_button("ERASE SAVE DATA", Vector2(300, 44))
	erase_button.pressed.connect(_on_erase_pressed.bind(erase_button, status_label))
	box.add_child(erase_button)
	_end_modal(box)


# Two-step button so progress is never erased by accident.
func _on_erase_pressed(erase_button: Button, status_label: Label) -> void:
	if not _erase_armed:
		_erase_armed = true
		erase_button.text = "PRESS AGAIN TO CONFIRM"
		return
	_erase_armed = false
	SaveManager.delete_save()
	save_data = SaveManager.load_progress()
	_refresh_continue_button()
	erase_button.text = "ERASE SAVE DATA"
	status_label.text = "Save status: %s" % SaveManager.last_status
