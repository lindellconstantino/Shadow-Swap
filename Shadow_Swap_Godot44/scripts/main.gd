extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const WORLD := Rect2(32, 108, 896, 492)
const REALM_MATERIAL := 0
const REALM_SHADOW := 1

var player: CharacterBody2D
var ui_layer: CanvasLayer
var title_label: Label
var objective_label: Label
var message_label: Label
var controls_label: Label
var realm_label: Label
var player_light_time := 0.0
var realm := REALM_MATERIAL
var shards := 0
var won := false
var message_timer := 0.0
var message := "Find all 3 memory shards. Some paths only exist in the Shadow Realm."

# Obstacles: [rectangle, realm]. Material-only blocks vanish in Shadow Realm and vice versa.
var obstacle_data: Array[Dictionary] = []
var obstacle_nodes: Array[StaticBody2D] = []
var shard_positions: Array[Vector2] = [Vector2(180, 205), Vector2(770, 220), Vector2(480, 525)]
var shard_collected: Array[bool] = [false, false, false]
var portal_position := Vector2(850, 535)

func _ready() -> void:
	_setup_input()
	_build_level()
	player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	player.position = Vector2(95, 350)
	_create_ui()
	_update_ui()
	queue_redraw()

func _process(delta: float) -> void:
	player_light_time += delta
	if message_timer > 0.0:
		message_timer = maxf(0.0, message_timer - delta)
	if Input.is_action_just_pressed("restart_game"):
		get_tree().reload_current_scene()
		return
	if not won:
		if Input.is_action_just_pressed("swap_realm"):
			_swap_realm()
		if Input.is_action_just_pressed("interact"):
			_interact()
		_check_shards()
		_check_portal()
	_update_ui()
	queue_redraw()

func _build_level() -> void:
	# Shared outer walls keep the player in the play area.
	_add_obstacle(Rect2(32, 108, 896, 16), -1)
	_add_obstacle(Rect2(32, 584, 896, 16), -1)
	_add_obstacle(Rect2(32, 108, 16, 492), -1)
	_add_obstacle(Rect2(912, 108, 16, 492), -1)
	# Material Realm obstacles.
	_add_obstacle(Rect2(220, 170, 28, 150), REALM_MATERIAL)
	_add_obstacle(Rect2(350, 300, 170, 26), REALM_MATERIAL)
	_add_obstacle(Rect2(585, 160, 28, 145), REALM_MATERIAL)
	_add_obstacle(Rect2(675, 390, 125, 26), REALM_MATERIAL)
	# Shadow Realm obstacles create alternate routes.
	_add_obstacle(Rect2(300, 390, 28, 130), REALM_SHADOW)
	_add_obstacle(Rect2(430, 175, 150, 26), REALM_SHADOW)
	_add_obstacle(Rect2(690, 260, 28, 95), REALM_SHADOW)
	_add_obstacle(Rect2(120, 455, 110, 26), REALM_SHADOW)
	_update_obstacles()

func _add_obstacle(rect: Rect2, obstacle_realm: int) -> void:
	obstacle_data.append({"rect": rect, "realm": obstacle_realm})
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	body.position = rect.position + rect.size / 2.0
	add_child(body)
	obstacle_nodes.append(body)

func _update_obstacles() -> void:
	for i in range(obstacle_nodes.size()):
		var r: int = obstacle_data[i]["realm"]
		obstacle_nodes[i].set_deferred("collision_layer", 1 if r == -1 or r == realm else 0)
		obstacle_nodes[i].set_deferred("collision_mask", 1 if r == -1 or r == realm else 0)

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	title_label = _new_label(Vector2(28, 12), Vector2(600, 32), 25, Color("#f4f0ff"))
	objective_label = _new_label(Vector2(30, 48), Vector2(650, 25), 15, Color("#c6d5ff"))
	realm_label = _new_label(Vector2(700, 20), Vector2(230, 32), 18, Color("#77f5e5"))
	message_label = _new_label(Vector2(30, 610), Vector2(900, 22), 14, Color("#ffe7a6"))
	controls_label = _new_label(Vector2(30, 78), Vector2(900, 20), 13, Color("#92a6c7"))
	title_label.text = "SHADOW SWAP"
	controls_label.text = "MOVE: WASD / ARROWS     SHIFT REALM: SPACE     INTERACT: E     RESTART: R"

func _new_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	ui_layer.add_child(label)
	return label

func _swap_realm() -> void:
	if won:
		return
	var old_realm := realm
	realm = REALM_SHADOW if realm == REALM_MATERIAL else REALM_MATERIAL
	_update_obstacles()
	# Prevent swapping into an obstacle. Revert if player overlaps a newly solid wall.
	await get_tree().physics_frame
	if _player_overlaps_active_obstacle():
		realm = old_realm
		_update_obstacles()
		_show_message("That realm is blocked here. Move to a safe spot before swapping.")
	else:
		_show_message("Realm shifted: " + _realm_name() + ". The world has changed around you.")
	_update_ui()
	queue_redraw()

func _player_overlaps_active_obstacle() -> bool:
	for i in range(obstacle_data.size()):
		var r: int = obstacle_data[i]["realm"]
		if r != -1 and r != realm:
			continue
		var rect: Rect2 = obstacle_data[i]["rect"]
		if rect.grow(13.0).has_point(player.global_position):
			return true
	return false

func _interact() -> void:
	if won:
		return
	if player.global_position.distance_to(portal_position) < 58.0:
		if shards >= shard_positions.size():
			_win_game()
		else:
			_show_message("The portal is asleep. Find all 3 memory shards first.")
		return
	_show_message("The realm responds to your shadow. Search for glowing memory shards.")

func _check_shards() -> void:
	for i in range(shard_positions.size()):
		if not shard_collected[i] and player.global_position.distance_to(shard_positions[i]) < 24.0:
			shard_collected[i] = true
			shards += 1
			_show_message("Memory shard recovered! (%d/3)" % shards)

func _check_portal() -> void:
	if player.global_position.distance_to(portal_position) < 42.0 and Input.is_action_just_pressed("interact"):
		if shards == shard_positions.size():
			_win_game()
		else:
			_show_message("Portal sealed: %d memory shard(s) remaining." % (shard_positions.size() - shards))

func _win_game() -> void:
	won = true
	player.controls_enabled = false
	_show_message("YOU ESCAPED THE ECLIPSE! Press R to play again.")

func _show_message(text: String) -> void:
	message = text
	message_timer = 4.0

func _update_ui() -> void:
	if not is_instance_valid(objective_label):
		return
	objective_label.text = "MEMORY SHARDS: %d / 3     DESTINATION: ECLIPSE GATE" % shards
	realm_label.text = "REALM: " + _realm_name()
	if message_timer > 0.0 or won:
		message_label.text = message
	elif realm == REALM_MATERIAL:
		message_label.text = "The Material Realm is stable. Shift realms to reveal the hidden route."
	else:
		message_label.text = "The Shadow Realm is unstable. Watch for glowing paths and dark barriers."

func _realm_name() -> String:
	return "MATERIAL" if realm == REALM_MATERIAL else "SHADOW"

func _draw() -> void:
	var bg := Color("#111a30") if realm == REALM_MATERIAL else Color("#100f24")
	var floor_color := Color("#1a2b47") if realm == REALM_MATERIAL else Color("#211936")
	var grid_color := Color("#294263") if realm == REALM_MATERIAL else Color("#49305d")
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 640)), bg, true)
	draw_rect(WORLD, floor_color, true)
	for x in range(48, 928, 32):
		draw_line(Vector2(x, 108), Vector2(x, 600), grid_color, 1.0)
	for y in range(108, 600, 32):
		draw_line(Vector2(32, y), Vector2(928, y), grid_color, 1.0)
	# Realm-specific platforms / barriers.
	for data in obstacle_data:
		var r: int = data["realm"]
		var rect: Rect2 = data["rect"]
		if r == -1:
			draw_rect(rect, Color("#526783"), true)
		elif r == realm:
			var c := Color("#526c8d") if realm == REALM_MATERIAL else Color("#8251a0")
			draw_rect(rect, c, true)
			draw_rect(rect, Color("#9ad6ff") if realm == REALM_MATERIAL else Color("#f1a5ff"), false, 2.0)
		else:
			var ghost := Color("#78a8ff", 0.13) if realm == REALM_MATERIAL else Color("#e7a0ff", 0.13)
			draw_rect(rect, ghost, true)
	# Portal.
	var portal_pulse := 25.0 + sin(player_light_time * 3.0) * 4.0
	draw_circle(portal_position, portal_pulse, Color("#55f0d2", 0.12))
	draw_arc(portal_position, portal_pulse, 0.0, TAU, 48, Color("#79ffe5"), 3.0)
	draw_circle(portal_position, 11.0, Color("#eafffb"))
	draw_string(ThemeDB.fallback_font, portal_position + Vector2(-38, 42), "ECLIPSE GATE", HORIZONTAL_ALIGNMENT_LEFT, 110, 12, Color("#9effe8"))
	# Memory shards.
	for i in range(shard_positions.size()):
		if shard_collected[i]:
			continue
		var p: Vector2 = shard_positions[i]
		var pulse := 10.0 + sin(player_light_time * 4.0 + float(i)) * 2.0
		draw_circle(p, pulse + 6.0, Color("#ffd66b", 0.13))
		var diamond := PackedVector2Array([p + Vector2(0, -pulse), p + Vector2(pulse * 0.7, 0), p + Vector2(0, pulse), p + Vector2(-pulse * 0.7, 0)])
		draw_colored_polygon(diamond, Color("#ffe18a") if realm == REALM_MATERIAL else Color("#bda0ff"))
	# Player halo and simple character sprite.
	if is_instance_valid(player):
		var ppos := player.global_position
		var halo_color := Color("#69f2e0", 0.18) if realm == REALM_MATERIAL else Color("#d58aff", 0.2)
		draw_circle(ppos, 25.0 + sin(player_light_time * 5.0) * 2.0, halo_color)
		draw_circle(ppos + Vector2(0, 3), 12.0, Color("#080d1b"))
		draw_circle(ppos, 11.0, Color("#e5f7ff") if realm == REALM_MATERIAL else Color("#f0d8ff"))
		draw_circle(ppos + Vector2(3, -3), 3.0, Color("#17243b"))
	# A subtle realm badge.
	draw_rect(Rect2(750, 55, 178, 5), Color("#28364e"), true)
	draw_rect(Rect2(750, 55, 178 * (1.0 if realm == REALM_MATERIAL else 0.55), 5), Color("#69f2e0") if realm == REALM_MATERIAL else Color("#d58aff"), true)
	if won:
		draw_rect(Rect2(230, 265, 500, 95), Color("#0b1728"), true)
		draw_rect(Rect2(230, 265, 500, 95), Color("#79ffe5"), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(330, 322), "ECLIPSE ESCAPED!", HORIZONTAL_ALIGNMENT_LEFT, 340, 30, Color("#9effe8"))

func _setup_input() -> void:
	_add_key_action("move_up", KEY_W, KEY_UP)
	_add_key_action("move_down", KEY_S, KEY_DOWN)
	_add_key_action("move_left", KEY_A, KEY_LEFT)
	_add_key_action("move_right", KEY_D, KEY_RIGHT)
	_add_key_action("swap_realm", KEY_SPACE)
	_add_key_action("interact", KEY_E)
	_add_key_action("restart_game", KEY_R)

func _add_key_action(action_name: String, key_one: Key, key_two: Key = KEY_NONE) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event_one := InputEventKey.new()
	event_one.physical_keycode = key_one
	if not InputMap.action_has_event(action_name, event_one):
		InputMap.action_add_event(action_name, event_one)
	if key_two != KEY_NONE:
		var event_two := InputEventKey.new()
		event_two.physical_keycode = key_two
		if not InputMap.action_has_event(action_name, event_two):
			InputMap.action_add_event(action_name, event_two)
