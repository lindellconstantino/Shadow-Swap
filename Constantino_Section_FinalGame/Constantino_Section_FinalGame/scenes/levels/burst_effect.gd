class_name BurstEffect
extends Node2D
## A short-lived visual effect (spark burst or expanding ring).
## It is created with instantiate() and removes itself when it is finished.

enum Style { SPARKS, RING }

var style: Style = Style.SPARKS
var color: Color = Color.WHITE
var duration: float = 0.6
var _age: float = 0.0
var _directions: Array[Vector2] = []


func _ready() -> void:
	GameState.note_spawned("burst")
	for i in 14:
		_directions.append(Vector2.from_angle(randf() * TAU) * randf_range(50.0, 150.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		set_process(false)
		# OS CONCEPT: Memory Management - the finished effect is freed (see GameState.dispose).
		GameState.dispose(self, "burst")
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / duration, 0.0, 1.0)
	if style == Style.RING:
		draw_arc(Vector2.ZERO, 12.0 + t * 95.0, 0.0, TAU, 48, Color(color, 1.0 - t), 3.0)
		draw_arc(Vector2.ZERO, 6.0 + t * 60.0, 0.0, TAU, 40, Color(color, (1.0 - t) * 0.5), 2.0)
	else:
		for direction in _directions:
			draw_circle(direction * t, 3.5 * (1.0 - t) + 0.6, Color(color, 1.0 - t))
