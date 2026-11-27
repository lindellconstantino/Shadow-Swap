class_name UiTheme
extends RefCounted
## Shared look of every menu: colors, fonts, button/panel styles and small helpers.
## All UI scenes call UiTheme.get_theme() so the game looks consistent and the
## styling code is written only once.

const FONT_REGULAR_PATH := "res://assets/fonts/Montserrat-Regular.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/Montserrat-Bold.ttf"

const COLOR_TEXT := Color("eaf2ff")
const COLOR_MUTED := Color("8fa6c8")
const COLOR_TEAL := Color("75f0df")
const COLOR_VIOLET := Color("d2a0ff")
const COLOR_GOLD := Color("ffdf91")
const COLOR_PANEL := Color("0f1830")
const COLOR_PANEL_BORDER := Color("4a6a8c")

static var _theme: Theme = null
static var _regular_font: Font = null
static var _bold_font: Font = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


static func body_font() -> Font:
	get_theme()
	return _regular_font if _regular_font != null else ThemeDB.fallback_font


static func bold_font() -> Font:
	get_theme()
	return _bold_font if _bold_font != null else ThemeDB.fallback_font


static func make_label(text: String, font_size: int = 16, color: Color = COLOR_TEXT, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", bold_font())
	return label


static func make_button(text: String, min_size: Vector2 = Vector2(250, 46)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	return button


static func panel_style(fill: Color = COLOR_PANEL, border: Color = COLOR_PANEL_BORDER, margin: int = 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style


static func button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


# Minutes:seconds.tenths, e.g. 1:07.4
static func format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	var whole_seconds := int(seconds) % 60
	var tenths := int(seconds * 10.0) % 10
	return "%d:%02d.%d" % [minutes, whole_seconds, tenths]


static func _build_theme() -> Theme:
	var theme := Theme.new()
	_regular_font = load(FONT_REGULAR_PATH) as Font
	_bold_font = load(FONT_BOLD_PATH) as Font
	if _regular_font != null:
		theme.default_font = _regular_font
	theme.default_font_size = 16

	# Labels
	theme.set_color("font_color", "Label", COLOR_TEXT)

	# Buttons
	if _bold_font != null:
		theme.set_font("font", "Button", _bold_font)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", COLOR_TEAL)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("56657d"))
	theme.set_stylebox("normal", "Button", button_style(Color("22334d"), Color("3f5c7c")))
	theme.set_stylebox("hover", "Button", button_style(Color("314e6e"), COLOR_TEAL))
	theme.set_stylebox("pressed", "Button", button_style(Color("16263d"), COLOR_VIOLET))
	theme.set_stylebox("focus", "Button", button_style(Color("22334d"), COLOR_GOLD))
	theme.set_stylebox("disabled", "Button", button_style(Color("161f30"), Color("2a364b")))

	# Panels
	theme.set_stylebox("panel", "PanelContainer", panel_style())

	# Progress bar (loading screen)
	var bar_back := button_style(Color("131c2f"), Color("34506f"))
	var bar_fill := button_style(COLOR_TEAL, COLOR_TEAL)
	bar_fill.set_corner_radius_all(6)
	theme.set_stylebox("background", "ProgressBar", bar_back)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme
