extends Node2D
## One playable stage. level_1.tscn, level_2.tscn and level_3.tscn all use this
## script; the only difference is the exported stage_index. The layout itself
## (barriers, shards, gate position) comes from level_data.gd.

# Custom signals (OS CONCEPT: Interrupts). They are connected in code in _connect_signals().
signal shard_count_changed(count: int)
signal realm_changed(realm: int)
signal stage_completed(stage: int, time_seconds: float)

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SHARD_SCENE: PackedScene = preload("res://scenes/levels/memory_shard.tscn")
const WISP_SCENE: PackedScene = preload("res://scenes/enemies/shadow_wisp.tscn")
const BURST_SCENE: PackedScene = preload("res://scenes/levels/burst_effect.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const END_SCENE: PackedScene = preload("res://scenes/ui/stage_end_screen.tscn")
const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const LOADING_PATH := "res://scenes/ui/loading_screen.tscn"

const SCREEN_SIZE := Vector2(960, 640)
const WORLD := Rect2(32, 112, 896, 488)
const OUTER_WALLS := [
	Rect2(32, 112, 896, 16), Rect2(32, 584, 896, 16),
	Rect2(32, 112, 16, 488), Rect2(912, 112, 16, 488),
]
const WALL_REALM := -1          # walls are solid in both realms
const PORTAL_RANGE := 60.0      # how close the player must be to use the gate
const SWAP_MARGIN := 12.0       # a shift is refused if the player is this close to a barrier that would become solid
const WISP_SPAWN_INTERVAL := 5.5
const WISP_SAFE_DISTANCE := 170.0
const HIT_GRACE_TIME := 1.0
const DEFAULT_HINT := "SPACE  Shift realm        E  Use gate        ESC  Pause"

@export var stage_index: int = 1

var stage_data: Dictionary = {}
var player: ShadowSwapPlayer
var camera: Camera2D
var hud: GameHud
var pause_menu: PauseMenu
var end_screen: StageEndScreen
var spawn_timer: Timer

var checkpoint: Vector2 = Vector2.ZERO
var portal_position: Vector2 = Vector2.ZERO
var wisp_cap: int = 0
var shard_positions: Array[Vector2] = []
var barriers: Array[Dictionary] = []      # each: {"rect": Rect2, "realm": int, "body": StaticBody2D}
var wisps: Array[ShadowWisp] = []

var realm: int = LevelData.MATERIAL_REALM
var shard_count: int = 0
var shard_total: int = 0
var stage_time: float = 0.0
var won: bool = false
var has_moved: bool = false
var has_swapped: bool = false
var collected_ids: Array[int] = []

var _animation_time: float = 0.0
var _realm_blend: float = 0.0       # 0 = Material look, 1 = Shadow look (eases between them)
var _swap_flash: float = 0.0
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _hit_grace: float = 0.0


func _ready() -> void:
	add_to_group("game")
	GameState.reset_object_stats()
	GameState.current_stage = stage_index
	stage_data = LevelData.get_stage(stage_index)
	_load_stage_data()
	_build_barriers()
	_create_player()
	_create_camera()
	_create_ui()
	_connect_signals()
	_spawn_shards()
	if wisp_cap > 0:
		_setup_wisp_spawner()
	hud.set_stage(stage_index, stage_data["name"])
	hud.set_shards(shard_count, shard_total)
	hud.set_realm(false)
	hud.show_toast(stage_data["intro"], 4.5)


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling
	# _process() runs once per rendered frame. It is used for visuals and timers
	# (background blend, flash, shake, stage clock). All of them are scaled by delta.
	_animation_time += delta
	_realm_blend = move_toward(_realm_blend, 1.0 if realm == LevelData.SHADOW_REALM else 0.0, delta * 5.0)
	_swap_flash = maxf(0.0, _swap_flash - delta * 2.5)
	_hit_grace = maxf(0.0, _hit_grace - delta)
	_update_shake(delta)
	if not has_moved and player.position.distance_to(checkpoint) > 40.0:
		has_moved = true
	if not won:
		stage_time += delta
		hud.set_time(stage_time)
	_update_hint()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# OS CONCEPT: I/O Management (event-driven)
	# _unhandled_input() is only called when an input EVENT happens (a key press).
	# The game does not have to check the keyboard every frame for these actions.
	if won:
		return
	if event.is_action_pressed("swap_realm"):
		GameState.log_input("SPACE pressed (event) -> swap realm")
		_try_swap_realm()
	elif event.is_action_pressed("interact"):
		GameState.log_input("E pressed (event) -> interact")
		_interact()
	elif event.is_action_pressed("restart_game"):
		GameState.log_input("R pressed (event) -> restart stage")
		_restart_stage()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func _load_stage_data() -> void:
	checkpoint = stage_data["checkpoint"]
	portal_position = stage_data["portal"]
	wisp_cap = stage_data["wisp_cap"]
	var shard_list: Array = stage_data["shards"]
	for point in shard_list:
		shard_positions.append(point)
	shard_total = shard_positions.size()


func _build_barriers() -> void:
	for wall in OUTER_WALLS:
		_add_barrier(wall, WALL_REALM)
	var barrier_list: Array = stage_data["barriers"]
	for entry in barrier_list:
		var info: Dictionary = entry
		_add_barrier(info["rect"], info["realm"])
	_apply_realm_collisions()


func _add_barrier(rect: Rect2, barrier_realm: int) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	body.position = rect.get_center()
	add_child(body)
	barriers.append({"rect": rect, "realm": barrier_realm, "body": body})


func _create_player() -> void:
	# OS CONCEPT: Processes and Programs - the player scene is instantiated at runtime.
	player = PLAYER_SCENE.instantiate() as ShadowSwapPlayer
	player.add_to_group("player")
	player.position = checkpoint
	add_child(player)


func _create_camera() -> void:
	# The camera is only used to shake the screen when something bad happens.
	camera = Camera2D.new()
	camera.position = SCREEN_SIZE / 2.0
	add_child(camera)
	camera.make_current()


func _create_ui() -> void:
	hud = HUD_SCENE.instantiate() as GameHud
	add_child(hud)
	pause_menu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child(pause_menu)
	end_screen = END_SCENE.instantiate() as StageEndScreen
	add_child(end_screen)


# OS CONCEPT: Interrupts
# A signal is a software "interrupt": an object announces that something happened and
# every function connected to it is called automatically - nobody has to keep checking.
# Here the connections are made IN CODE with connect().
func _connect_signals() -> void:
	shard_count_changed.connect(_on_shard_count_changed)
	realm_changed.connect(_on_realm_changed)
	stage_completed.connect(_on_stage_completed)
	hud.pause_requested.connect(pause_menu.open)
	pause_menu.restart_requested.connect(_restart_stage)
	pause_menu.menu_requested.connect(_return_to_menu)
	end_screen.next_requested.connect(_on_next_requested)
	end_screen.replay_requested.connect(_restart_stage)
	end_screen.menu_requested.connect(_return_to_menu)


func _spawn_shards() -> void:
	for shard_id in shard_positions.size():
		# OS CONCEPT: Processes and Programs
		# memory_shard.tscn is a template (the "program"). instantiate() creates a new
		# running copy (like a process) for each shard in the stage.
		var shard := SHARD_SCENE.instantiate() as MemoryShard
		shard.shard_id = shard_id
		shard.position = shard_positions[shard_id]
		shard.collected.connect(_on_shard_collected)     # custom signal, connected in code
		add_child(shard)


func _setup_wisp_spawner() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = WISP_SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_wisp)             # built-in signal, connected in code
	add_child(spawn_timer)
	spawn_timer.start()
	_spawn_wisp()


func _spawn_wisp() -> void:
	if won or wisps.size() >= wisp_cap:
		return
	# Only spawn far enough from the player so a wisp never appears on top of them.
	var spawn_points: Array = stage_data["wisp_spawns"]
	var candidates: Array[Vector2] = []
	for point in spawn_points:
		var candidate: Vector2 = point
		if player.position.distance_to(candidate) > WISP_SAFE_DISTANCE:
			candidates.append(candidate)
	if candidates.is_empty():
		return
	# OS CONCEPT: Processes and Programs - a new wisp object is created while the game runs.
	var wisp := WISP_SCENE.instantiate() as ShadowWisp
	wisp.position = candidates[randi() % candidates.size()]
	wisp.touched_player.connect(_on_wisp_touched)         # custom signal, connected in code
	wisp.retired.connect(_on_wisp_retired)                # custom signal, connected in code
	add_child(wisp)
	wisp.set_active(realm == LevelData.SHADOW_REALM)
	wisps.append(wisp)


# ---------------------------------------------------------------------------
# Realm swapping
# ---------------------------------------------------------------------------
func _is_solid_in(barrier_realm: int, in_realm: int) -> bool:
	return barrier_realm == WALL_REALM or barrier_realm == in_realm


func _apply_realm_collisions() -> void:
	for barrier in barriers:
		var barrier_realm: int = barrier["realm"]
		var body: StaticBody2D = barrier["body"]
		var layer_value: int = 1 if _is_solid_in(barrier_realm, realm) else 0
		body.set_deferred("collision_layer", layer_value)
		body.set_deferred("collision_mask", layer_value)


# True if the player is standing too close to a barrier that would turn solid in new_realm.
func _is_player_blocking_swap(new_realm: int) -> bool:
	for barrier in barriers:
		var barrier_realm: int = barrier["realm"]
		if barrier_realm == WALL_REALM or barrier_realm != new_realm:
			continue
		var rect: Rect2 = barrier["rect"]
		if rect.grow(SWAP_MARGIN).has_point(player.position):
			return true
	return false


func _try_swap_realm() -> void:
	var new_realm: int = 1 - realm
	if _is_player_blocking_swap(new_realm):
		AudioManager.play_sfx("blocked")
		hud.show_toast("Blocked! Step away from the glowing barrier before shifting.")
		_start_shake(3.0, 0.18)
		return
	realm = new_realm
	has_swapped = true
	_apply_realm_collisions()
	player.set_realm_color(_realm_color())
	_swap_flash = 1.0
	_spawn_burst(player.position, _realm_color(), BurstEffect.Style.RING)
	for wisp in wisps:
		if is_instance_valid(wisp):
			wisp.set_active(realm == LevelData.SHADOW_REALM)
	AudioManager.play_sfx("realm_shift")
	realm_changed.emit(realm)


func _realm_color() -> Color:
	return UiTheme.COLOR_VIOLET if realm == LevelData.SHADOW_REALM else UiTheme.COLOR_TEAL


func _realm_name() -> String:
	return "SHADOW" if realm == LevelData.SHADOW_REALM else "MATERIAL"


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------
func _on_shard_collected(shard_id: int) -> void:
	shard_count += 1
	collected_ids.append(shard_id)
	GameState.log_signal("collected(shard %d) -> Level._on_shard_collected" % shard_id)
	_spawn_burst(shard_positions[shard_id], Color("ffe69c"), BurstEffect.Style.SPARKS)
	AudioManager.play_sfx("collect", 1.0 + shard_count * 0.06)
	shard_count_changed.emit(shard_count)
	if shard_count >= shard_total:
		hud.show_toast("All shards recovered! Reach the Eclipse Gate and press E.", 3.5)
	else:
		hud.show_toast("Memory shard %d / %d recovered" % [shard_count, shard_total])


func _on_shard_count_changed(count: int) -> void:
	hud.set_shards(count, shard_total)


func _on_realm_changed(new_realm: int) -> void:
	GameState.log_signal("realm_changed(%s) -> Level._on_realm_changed" % _realm_name())
	hud.set_realm(new_realm == LevelData.SHADOW_REALM)
	hud.show_toast("Shifted to the %s Realm" % _realm_name(), 1.6)


func _on_wisp_touched() -> void:
	if _hit_grace > 0.0 or won:
		return
	_hit_grace = HIT_GRACE_TIME
	GameState.log_signal("touched_player -> Level._on_wisp_touched")
	_spawn_burst(player.position, Color("b17cff"), BurstEffect.Style.SPARKS)
	player.respawn_at(checkpoint)
	_spawn_burst(checkpoint, Color("8adfff"), BurstEffect.Style.RING)
	AudioManager.play_sfx("wisp_touch")
	_start_shake(8.0, 0.35)
	hud.show_toast("A shadow echo disrupted your path. Returned to the anchor.")


func _on_wisp_retired(wisp: ShadowWisp) -> void:
	GameState.log_signal("retired(wisp) -> Level._on_wisp_retired")
	wisps.erase(wisp)


func _on_stage_completed(stage: int, _time_seconds: float) -> void:
	GameState.log_signal("stage_completed(%d) -> Level._on_stage_completed" % stage)
	hud.show_toast("STAGE %d CLEARED" % stage, 3.0)


# ---------------------------------------------------------------------------
# Gate, win condition and flow
# ---------------------------------------------------------------------------
func _interact() -> void:
	if player.position.distance_to(portal_position) > PORTAL_RANGE:
		hud.show_toast("Nothing here. Look for the glowing Eclipse Gate.")
		return
	if shard_count < shard_total:
		AudioManager.play_sfx("blocked")
		hud.show_toast("The gate is sealed. %d shard(s) remain." % (shard_total - shard_count))
		return
	_complete_stage()


func _complete_stage() -> void:
	won = true
	player.controls_enabled = false
	pause_menu.enabled = false
	if spawn_timer != null:
		spawn_timer.stop()
	# OS CONCEPT: File Systems - progress is written to user:// when a stage is cleared.
	var result := SaveManager.record_stage_clear(stage_index, stage_time, shard_count)
	AudioManager.play_sfx("stage_complete")
	for i in 3:
		_spawn_burst(portal_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), Color("a6fff0"), BurstEffect.Style.SPARKS)
	_spawn_burst(portal_position, Color("a6fff0"), BurstEffect.Style.RING)
	stage_completed.emit(stage_index, stage_time)
	end_screen.show_result(stage_index, shard_count, shard_total, stage_time, result)


func _on_next_requested() -> void:
	if stage_index >= LevelData.STAGE_COUNT:
		GameState.start_new_game()          # "Play again" after the ending
	else:
		GameState.prepare_stage(stage_index + 1)
	Transition.change_scene(LOADING_PATH)


func _restart_stage() -> void:
	Transition.change_scene(scene_file_path)


func _return_to_menu() -> void:
	Transition.change_scene(MENU_PATH)


func _update_hint() -> void:
	var text := DEFAULT_HINT
	if won:
		text = ""
	elif player.position.distance_to(portal_position) < PORTAL_RANGE:
		if shard_count >= shard_total:
			text = "E  -  ENTER THE ECLIPSE GATE"
		else:
			text = "THE GATE IS SEALED  -  %d SHARD(S) LEFT" % (shard_total - shard_count)
	elif stage_index == 1:
		text = _tutorial_text()
	hud.set_hint(text)


# Step-by-step help for first-time players (Stage 1 only).
const CAGED_SHARD_ID := 1      # in Stage 1 the second shard sits inside a Material cage

func _tutorial_text() -> String:
	if not has_moved:
		return "Move with  WASD  or the  ARROW KEYS"
	if not has_swapped:
		return "Collect the glowing shards.  Press  SPACE  to shift realms and walk through barriers."
	if not collected_ids.has(CAGED_SHARD_ID):
		return "One shard is caged by Material barriers.  Stay in the Shadow Realm to slip inside!"
	if shard_count < shard_total:
		return "Keep collecting.  Teal barriers block the Material Realm, purple ones block the Shadow Realm."
	return DEFAULT_HINT


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------
func _spawn_burst(burst_position: Vector2, burst_color: Color, burst_style: BurstEffect.Style) -> void:
	# OS CONCEPT: Processes and Programs - effects are instantiated at runtime and freed
	# again when finished (see burst_effect.gd).
	var burst := BURST_SCENE.instantiate() as BurstEffect
	burst.position = burst_position
	burst.color = burst_color
	burst.style = burst_style
	add_child(burst)


func _start_shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = duration


func _update_shake(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var falloff := clampf(_shake_time / 0.35, 0.0, 1.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * falloff
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


# ---------------------------------------------------------------------------
# Drawing (everything is drawn with code, so no image files are needed)
# ---------------------------------------------------------------------------
func _draw() -> void:
	var background := Color("0c1224").lerp(Color("130d26"), _realm_blend)
	var floor_color := Color("182943").lerp(Color("241a38"), _realm_blend)
	var grid_color := Color("28415f").lerp(Color("4b3361"), _realm_blend)
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), background, true)
	draw_rect(WORLD, floor_color, true)
	for x in range(48, 928, 32):
		draw_line(Vector2(x, 112), Vector2(x, 600), grid_color, 1.0)
	for y in range(112, 600, 32):
		draw_line(Vector2(32, y), Vector2(928, y), grid_color, 1.0)
	_draw_dust()
	_draw_barriers()
	_draw_anchors()
	_draw_checkpoint()
	_draw_portal()
	draw_rect(WORLD, Color("526b8b"), false, 3.0)
	if _swap_flash > 0.0:
		draw_rect(WORLD, Color(_realm_color(), _swap_flash * 0.16), true)


func _draw_dust() -> void:
	# Slowly drifting specks that make the floor feel alive.
	for i in 26:
		var x := fposmod(i * 97.0 + _animation_time * (5.0 + (i % 5) * 2.0), 880.0) + 40.0
		var y := fposmod(i * 53.0 - _animation_time * (3.0 + (i % 3) * 2.0), 470.0) + 118.0
		draw_circle(Vector2(x, y), 1.4, Color(_realm_color(), 0.18))


func _draw_barriers() -> void:
	var active_fill := Color("476c8e").lerp(Color("6d458c"), _realm_blend)
	var active_edge := _realm_color().lerp(Color.WHITE, 0.15)
	for barrier in barriers:
		var barrier_realm: int = barrier["realm"]
		var rect: Rect2 = barrier["rect"]
		if barrier_realm == WALL_REALM:
			draw_rect(rect, Color("4a6382"), true)
			draw_rect(rect, Color("91aac9"), false, 2.0)
		elif barrier_realm == realm:
			# Solid barrier of the current realm.
			draw_rect(rect, active_fill, true)
			draw_rect(rect, active_edge, false, 2.0)
			var long_side := maxf(rect.size.x, rect.size.y)
			for stripe in int(long_side / 18.0):
				var offset := stripe * 18.0
				if rect.size.x > rect.size.y:
					draw_line(rect.position + Vector2(offset, 3), rect.position + Vector2(offset + 8, rect.size.y - 3), Color(active_edge, 0.24), 2.0)
				else:
					draw_line(rect.position + Vector2(3, offset), rect.position + Vector2(rect.size.x - 3, offset + 8), Color(active_edge, 0.24), 2.0)
		else:
			# Ghost barrier: belongs to the other realm, so the player can walk through it.
			var ghost_color := Color("9d79ed") if barrier_realm == LevelData.SHADOW_REALM else Color("86d5e0")
			draw_rect(rect, Color(ghost_color, 0.08), true)
			draw_rect(rect, Color(ghost_color, 0.22), false, 1.0)


func _draw_anchors() -> void:
	var anchor_list: Array = stage_data["anchors"]
	for anchor in anchor_list:
		var anchor_position: Vector2 = anchor
		draw_circle(anchor_position, 18.0 + sin(_animation_time * 2.2) * 2.0, Color("9d79ed", 0.09))
		draw_arc(anchor_position, 17.0, _animation_time, _animation_time + TAU * 0.72, 28, Color("c59aff", 0.6), 2.0)


func _draw_checkpoint() -> void:
	draw_circle(checkpoint, 21.0, Color("8adfff", 0.08))
	draw_arc(checkpoint, 18.0, _animation_time, _animation_time + TAU * 0.75, 32, Color("8adfff", 0.55), 2.0)


func _draw_portal() -> void:
	var unlocked := shard_count >= shard_total
	var ring_color := Color("73ffe6") if unlocked else Color("6f7fa8")
	var pulse := 27.0 + sin(_animation_time * (2.8 if unlocked else 1.2)) * (4.0 if unlocked else 1.5)
	draw_circle(portal_position, pulse + 10.0, Color(ring_color, 0.10))
	draw_arc(portal_position, pulse, 0.0, TAU, 48, ring_color, 3.0)
	draw_arc(portal_position, pulse - 7.0, _animation_time, _animation_time + TAU * 0.7, 48, Color(ring_color, 0.75), 2.0)
	draw_circle(portal_position, 10.0, Color("f0fffc") if unlocked else Color("8a97b8"))
	var label := "ECLIPSE GATE" if unlocked else "SEALED"
	draw_string(UiTheme.bold_font(), portal_position + Vector2(-44, 48), label, HORIZONTAL_ALIGNMENT_CENTER, 88, 12, Color(ring_color, 0.95))
