extends Node

const BACKGROUND_MUSIC := preload("res://assets/sound/background_music.wav")
const COIN_SOUND := preload("res://assets/sound/coin_sound.wav")
const STAR_SOUND := preload("res://assets/sound/star_sound.mp3")
const RIGHT_SOUND := preload("res://assets/sound/right_answer.mp3")
const WRONG_SOUND := preload("res://assets/sound/wrong_answer.mp3")
const TAP_SOUND := preload("res://assets/sound/tab_sound.wav")
const COMPLETE_SOUND := preload("res://assets/sound/level_complete.mp3")
const FAIL_SOUND := preload("res://assets/sound/level_fail.mp3")

var music_player: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _next_effect := 0
var _last_tap_msec := -1000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.stream = BACKGROUND_MUSIC
	music_player.volume_db = -22.0
	music_player.finished.connect(_restart_music)
	add_child(music_player)
	for _index in range(5):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_effects.append(player)
	if GameState.music_enabled:
		music_player.play()

func _input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	var now := Time.get_ticks_msec()
	if now - _last_tap_msec < 80:
		return
	_last_tap_msec = now
	play_tap()

func _restart_music() -> void:
	if GameState.music_enabled:
		music_player.call_deferred("play")

func set_music_enabled(enabled: bool) -> void:
	if enabled and not music_player.playing:
		music_player.play()
	elif not enabled:
		music_player.stop()

func play_start() -> void:
	_play(STAR_SOUND, -12.0)

func play_tap() -> void:
	_play(TAP_SOUND, -10.0)

func play_coin() -> void:
	_play(COIN_SOUND, -7.0)

func play_star() -> void:
	_play(STAR_SOUND, -9.0)

func play_place(correct: bool) -> void:
	_play(RIGHT_SOUND if correct else WRONG_SOUND, -8.0)

func play_undo() -> void:
	_play(RIGHT_SOUND, -15.0)

func play_hint() -> void:
	_play(STAR_SOUND, -13.0)

func play_victory() -> void:
	_play(COMPLETE_SOUND, -5.0)

func play_level_fail() -> void:
	_play(FAIL_SOUND, -6.0)

func _play(stream: AudioStream, volume: float) -> void:
	if not GameState.sfx_enabled:
		return
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume
	player.play()
