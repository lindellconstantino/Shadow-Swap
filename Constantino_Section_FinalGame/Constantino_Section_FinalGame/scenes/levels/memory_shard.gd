class_name MemoryShard
extends Area2D
## A glowing collectible. The level creates one for every shard with instantiate().

# Custom signal (OS CONCEPT: Interrupts). It is connected in code by level.gd.
signal collected(shard_id: int)

@export var shard_id: int = 0
var _glow_time: float = 0.0
var _is_collected: bool = false


func _ready() -> void:
	GameState.note_spawned("shard")
	# OS CONCEPT: Interrupts - body_entered is a built-in signal connected through code.
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# OS CONCEPT: CPU Scheduling - purely visual pulse, so it lives in _process(delta).
	_glow_time += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _is_collected or not body.is_in_group("player"):
		return
	_is_collected = true
	collected.emit(shard_id)
	# OS CONCEPT: Memory Management - the collected shard is removed from memory.
	GameState.note_freed("shard")
	queue_free()


func _draw() -> void:
	var radius := 10.0 + sin(_glow_time * 4.0 + shard_id) * 2.0
	draw_circle(Vector2.ZERO, radius + 10.0, Color("ffd978", 0.10))
	draw_circle(Vector2.ZERO, radius + 5.0, Color("ffd978", 0.12))
	var diamond := PackedVector2Array([
		Vector2(0, -radius - 2.0), Vector2(radius * 0.7, 0),
		Vector2(0, radius + 2.0), Vector2(-radius * 0.7, 0)])
	draw_colored_polygon(diamond, Color("ffe69c"))
	draw_line(Vector2(-radius * 0.25, -radius * 0.5), Vector2(radius * 0.2, radius * 0.5), Color("ffffff", 0.7), 2.0)
