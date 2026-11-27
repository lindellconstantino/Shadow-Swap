class_name PlayerEcho
extends Node2D
## A fading "afterimage" left behind the player while moving.
## Many of these are created every second, so they must be freed -
## this is the main object used for the memory-management measurements.

const LIFETIME := 0.45

var color: Color = Color.WHITE
var _age: float = 0.0


func _ready() -> void:
	GameState.note_spawned("echo")


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		set_process(false)
		# OS CONCEPT: Memory Management - free the finished echo (see GameState.dispose).
		GameState.dispose(self, "echo")
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 11.0 * (1.0 - t * 0.45), Color(color, 0.32 * (1.0 - t)))
