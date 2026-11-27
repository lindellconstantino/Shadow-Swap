extends CanvasLayer
## Fade-to-black scene changes (autoload "Transition").
## Every menu, loading and level change goes through here so the game
## never "pops" from one screen to the next.

const FADE_TIME := 0.28

var _fade_rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the game is paused
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color("05070f")
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 1.0                # start black, fade in to the main menu
	add_child(_fade_rect)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_TIME * 2.0)


func change_scene(path: String) -> void:
	await _run_change(path, null)


func change_scene_packed(packed_scene: PackedScene) -> void:
	await _run_change("", packed_scene)


func _run_change(path: String, packed_scene: PackedScene) -> void:
	if _busy:
		return
	_busy = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks while fading
	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_TIME)
	await fade_out.finished
	get_tree().paused = false
	var error: Error = OK
	if packed_scene != null:
		error = get_tree().change_scene_to_packed(packed_scene)
	else:
		error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Transition: could not change scene (error %d)." % error)
	# Wait for the new scene to finish loading before fading back in.
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_TIME)
	await fade_in.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
