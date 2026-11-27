class_name GameHud
extends CanvasLayer
## The in-game heads-up display: stage name, shard counter, realm, timer,
## a hint line under the bar and a toast message at the bottom.

# Custom signal (OS CONCEPT: Interrupts): the level listens for this.
signal pause_requested

var stage_label: Label
var shards_label: Label
var realm_label: Label
var time_label: Label
var hint_label: Label
var toast_label: Label
var _toast_time: float = 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	# --- Top bar ---
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.06, 0.1, 0.19, 0.9), Color("43627f"), 10))
	column.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	stage_label = UiTheme.make_label("SHADOW SWAP", 19, UiTheme.COLOR_TEXT, true)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stage_label)
	shards_label = UiTheme.make_label("SHARDS 0 / 0", 16, UiTheme.COLOR_GOLD, true)
	shards_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shards_label)
	realm_label = UiTheme.make_label("MATERIAL REALM", 15, UiTheme.COLOR_TEAL, true)
	realm_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(realm_label)
	time_label = UiTheme.make_label("0:00.0", 16, UiTheme.COLOR_TEXT, true)
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time_label)
	var pause_button := UiTheme.make_button("PAUSE", Vector2(96, 36))
	# No keyboard focus: otherwise pressing SPACE later would "click" this button.
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	row.add_child(pause_button)

	# --- Hint line (tutorial text / gate prompt) ---
	hint_label = UiTheme.make_label("", 14, Color("d6e4ff"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint_label)

	# --- Spacer pushes the toast to the bottom of the screen ---
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	toast_label = UiTheme.make_label("", 15, Color("ffe9ac"), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	column.add_child(toast_label)


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling - _process() runs once per rendered frame, so it is
	# used for visual-only work such as fading the toast message with delta.
	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		toast_label.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)


func set_stage(stage: int, stage_name: String) -> void:
	stage_label.text = "STAGE %d  -  %s" % [stage, stage_name]


func set_shards(count: int, total: int) -> void:
	shards_label.text = "SHARDS %d / %d" % [count, total]


func set_realm(is_shadow: bool) -> void:
	realm_label.text = "SHADOW REALM" if is_shadow else "MATERIAL REALM"
	realm_label.add_theme_color_override("font_color", UiTheme.COLOR_VIOLET if is_shadow else UiTheme.COLOR_TEAL)


func set_time(seconds: float) -> void:
	time_label.text = UiTheme.format_time(seconds)


func set_hint(text: String) -> void:
	if hint_label.text != text:
		hint_label.text = text


func show_toast(text: String, duration: float = 2.8) -> void:
	toast_label.text = text
	_toast_time = duration
	toast_label.modulate.a = 1.0
