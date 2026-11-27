extends Node
## Plays sound effects and music (autoload "AudioManager").
##
## OS CONCEPT: Memory Management (pooling)
## Instead of creating a new AudioStreamPlayer for every sound and freeing it,
## a fixed pool of 8 players is created once and re-used over and over.

const SFX := {
	"collect": preload("res://assets/audio/shard_collect.wav"),
	"realm_shift": preload("res://assets/audio/realm_shift.wav"),
	"wisp_touch": preload("res://assets/audio/wisp_touch.wav"),
	"stage_complete": preload("res://assets/audio/stage_complete.wav"),
	"blocked": preload("res://assets/audio/blocked.wav"),
	"ui_click": preload("res://assets/audio/ui_click.wav"),
	"ui_hover": preload("res://assets/audio/ui_hover.wav"),
}
const MUSIC_STREAM: AudioStream = preload("res://assets/audio/music_ambient.wav")
const POOL_SIZE := 8

var muted: bool = false
var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = -5.0
		add_child(player)
		_pool.append(player)
	_start_music()
	set_muted(SaveManager.is_muted())
	# OS CONCEPT: Interrupts - node_added is a built-in signal, connected through code.
	# Every Button that enters the game automatically gets hover/click sounds.
	get_tree().node_added.connect(_on_node_added)


func _unhandled_input(event: InputEvent) -> void:
	# OS CONCEPT: I/O Management (event-driven): M is handled only when it is pressed.
	if event.is_action_pressed("toggle_mute"):
		toggle_mute()


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not SFX.has(sfx_name):
		return
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = SFX[sfx_name]
	player.pitch_scale = pitch
	player.play()


func toggle_mute() -> void:
	set_muted(not muted)
	SaveManager.set_muted(muted)


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.volume_db = -13.0
	var stream := MUSIC_STREAM
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2   # 16-bit mono: 2 bytes per sample
	_music.stream = stream
	add_child(_music)
	_music.finished.connect(_music.play)     # fallback: restart if the loop ever ends
	_music.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		button.pressed.connect(play_sfx.bind("ui_click"))
		button.mouse_entered.connect(play_sfx.bind("ui_hover"))
