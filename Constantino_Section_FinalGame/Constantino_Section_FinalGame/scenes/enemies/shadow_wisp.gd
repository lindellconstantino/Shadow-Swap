class_name ShadowWisp
extends Area2D
## A drifting spirit that only exists in the Shadow Realm. Touching it sends the player
## back to the stage's anchor. The level creates wisps on a timer with instantiate().

# Custom signals (OS CONCEPT: Interrupts). Both are connected in code by level.gd.
signal touched_player
signal retired(wisp: ShadowWisp)

const LIFETIME_LIMIT := 18.0

var _origin: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _age: float = 0.0
var _is_retired: bool = false


func _ready() -> void:
	_origin = position
	_phase = randf() * TAU
	GameState.note_spawned("wisp")
	# OS CONCEPT: Interrupts - built-in body_entered signal connected through code.
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling - frame-based drifting animation scaled by delta.
	_age += delta
	if _age >= LIFETIME_LIMIT:
		retire()
		return
	position = _origin + Vector2(cos(_age * 0.8 + _phase) * 36.0, sin(_age * 1.5 + _phase) * 24.0)
	queue_redraw()


# Wisps are visible and dangerous only while the player is in the Shadow Realm.
func set_active(active: bool) -> void:
	visible = active
	set_deferred("monitoring", active)


func retire() -> void:
	if _is_retired:
		return
	_is_retired = true
	set_deferred("monitoring", false)
	set_process(false)
	retired.emit(self)
	# OS CONCEPT: Memory Management - the expired wisp is freed (see GameState.dispose).
	GameState.dispose(self, "wisp")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		touched_player.emit()


func _draw() -> void:
	var grow := minf(1.0, _age / 0.5)          # pops in when it spawns
	var pulse := (8.0 + sin(_age * 5.0) * 2.0) * grow
	draw_circle(Vector2.ZERO, pulse + 9.0, Color("b17cff", 0.12))
	draw_circle(Vector2.ZERO, pulse, Color("9d66e8"))
	draw_circle(Vector2(-2, -2), pulse * 0.48, Color("e9d8ff"))
	draw_arc(Vector2.ZERO, pulse + 5.0, _age * 2.0, _age * 2.0 + PI * 1.25, 24, Color("d7a8ff"), 2.0)
