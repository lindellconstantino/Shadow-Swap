class_name PauseMenu
extends CanvasLayer
## The pause overlay: Resume, Restart Stage, Sound toggle and Main Menu.
## It keeps running while the game tree is paused (process_mode = ALWAYS).

# Custom signals (OS CONCEPT: Interrupts). The level connects to these in code.
signal resumed
signal restart_requested
signal menu_requested

var enabled: bool = true      # the level turns this off when the stage ends
var is_open: bool = false
var _resume_button: Button
var _sound_button: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	# OS CONCEPT: I/O Management (event-driven): ESC is handled once per key press.
	if event.is_action_pressed("pause") and enabled:
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	_refresh_sound_text()
	_resume_button.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	resumed.emit()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := UiTheme.make_label("PAUSED", 30, UiTheme.COLOR_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var controls := UiTheme.make_label("WASD / ARROWS  Move      SPACE  Shift realm\nE  Use the Eclipse Gate      R  Restart      M  Sound", 13, UiTheme.COLOR_MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(controls)

	_resume_button = UiTheme.make_button("RESUME")
	_resume_button.pressed.connect(close)
	box.add_child(_resume_button)

	var restart_button := UiTheme.make_button("RESTART STAGE")
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(restart_button)

	_sound_button = UiTheme.make_button("SOUND: ON")
	_sound_button.pressed.connect(_on_sound_pressed)
	box.add_child(_sound_button)

	var menu_button := UiTheme.make_button("MAIN MENU")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(menu_button)


func _on_sound_pressed() -> void:
	AudioManager.toggle_mute()
	_refresh_sound_text()


func _refresh_sound_text() -> void:
	_sound_button.text = "SOUND: OFF" if AudioManager.muted else "SOUND: ON"
