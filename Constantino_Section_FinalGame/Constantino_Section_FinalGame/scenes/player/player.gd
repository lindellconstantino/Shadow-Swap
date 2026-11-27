class_name ShadowSwapPlayer
extends CharacterBody2D
## The traveler. Moves in 8 directions and leaves a fading trail of echoes.

const ECHO_SCENE: PackedScene = preload("res://scenes/player/player_echo.tscn")
const ECHO_INTERVAL := 0.07

@export var speed: float = 230.0
@export var acceleration: float = 1900.0
@export var friction: float = 2300.0

var controls_enabled: bool = true
var realm_color: Color = Color("75f0df")
var _animation_time: float = 0.0
var _echo_timer: float = 0.0
var _flash_time: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _auto_time: float = 0.0


func _physics_process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling
	# _physics_process() runs at a FIXED rate (60 times per second by default), which keeps
	# movement and collisions consistent. delta is the time step, so speed * delta is the
	# same distance per second on any computer.
	var direction := Vector2.ZERO
	if controls_enabled:
		# OS CONCEPT: I/O Management (polling)
		# Every physics tick the game ASKS the keyboard "which keys are held right now?"
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if GameState.auto_walk:
			_auto_time += delta
			direction = Vector2(cos(_auto_time * 0.9), sin(_auto_time * 1.3)).normalized()
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
		_facing = direction
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_update_echo_trail(delta)


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling - drawing/animation is frame-based, so it uses _process().
	_animation_time += delta
	_flash_time = maxf(0.0, _flash_time - delta * 3.0)
	queue_redraw()


func set_realm_color(color: Color) -> void:
	realm_color = color


# Used when a Shadow Wisp sends the player back to the checkpoint.
func respawn_at(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	_flash_time = 1.0


func _update_echo_trail(delta: float) -> void:
	if velocity.length() < 40.0:
		return
	_echo_timer += delta
	if _echo_timer >= ECHO_INTERVAL:
		_echo_timer = 0.0
		_spawn_echo()


func _spawn_echo() -> void:
	# OS CONCEPT: Processes and Programs
	# player_echo.tscn is the "program" (a template saved on disk). instantiate() creates
	# a new running copy of it, like starting a new process from an executable.
	var echo := ECHO_SCENE.instantiate() as PlayerEcho
	echo.color = realm_color
	echo.position = position          # player and level share the same coordinates
	var level := get_parent()
	level.add_child(echo)
	level.move_child(echo, get_index())   # draw the echo underneath the player


func _draw() -> void:
	var bob := sin(_animation_time * 7.0) * 1.5
	# Soft shadow on the floor.
	draw_circle(Vector2(0, 9), 9.0, Color(0, 0, 0, 0.25))
	# Realm-coloured glow, brighter right after being hit.
	draw_circle(Vector2(0, bob), 17.0, Color(realm_color, 0.10 + _flash_time * 0.3))
	draw_circle(Vector2(0, bob + 1.0), 10.5, Color("0a1020"))
	draw_circle(Vector2(0, bob), 10.0, Color("f1f6ff").lerp(Color.WHITE, _flash_time))
	# Eye that looks where the player is heading.
	draw_circle(_facing.normalized() * 4.0 + Vector2(0, bob - 1.0), 3.0, Color("25304a"))
	draw_arc(Vector2(0, bob), 13.0, 0.0, TAU, 32, realm_color, 2.0)
