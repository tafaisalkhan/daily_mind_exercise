extends Control

@onready var background: TextureRect = $Background
@onready var mascot: TextureRect = $Center/Brand/MascotSpace/Mascot
@onready var title: Label = $Center/Brand/Title
@onready var subtitle: Label = $Center/Brand/Subtitle
@onready var loader: VBoxContainer = $Bottom/Loader
@onready var progress: ProgressBar = $Bottom/Loader/ProgressBar
@onready var loading_label: Label = $Bottom/Loader/LoadingLabel

func _ready() -> void:
	AudioManager.play_start()
	_style_loader()
	background.modulate.a = 0.0
	mascot.modulate.a = 0.0
	mascot.scale = Vector2(0.78, 0.78)
	mascot.pivot_offset = mascot.size * 0.5
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	loader.modulate.a = 0.0
	progress.value = 0.0
	var intro := create_tween().set_parallel(true)
	intro.tween_property(background, "modulate:a", 1.0, 0.5)
	intro.tween_property(mascot, "modulate:a", 1.0, 0.5).set_delay(0.12)
	intro.tween_property(mascot, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	intro.tween_property(title, "modulate:a", 1.0, 0.5).set_delay(0.38)
	intro.tween_property(subtitle, "modulate:a", 1.0, 0.5).set_delay(0.6)
	intro.tween_property(loader, "modulate:a", 1.0, 0.4).set_delay(0.65)
	intro.tween_property(progress, "value", 100.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shimmer := create_tween().set_loops()
	shimmer.tween_property(loading_label, "modulate:a", 0.58, 0.55).set_trans(Tween.TRANS_SINE)
	shimmer.tween_property(loading_label, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.95).timeout
	var breathe := create_tween().set_loops()
	breathe.tween_property(mascot, "scale", Vector2(1.025, 1.025), 0.75).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(mascot, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE)
	await intro.finished
	breathe.kill()
	shimmer.kill()
	var exit_tween := create_tween()
	exit_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await exit_tween.finished
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _style_loader() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.04, 0.04, 0.22, 0.9)
	track.border_color = Color("#80eedc")
	track.set_border_width_all(2)
	track.set_corner_radius_all(12)
	track.content_margin_left = 3
	track.content_margin_right = 3
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	progress.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#72ead7")
	fill.set_corner_radius_all(9)
	fill.shadow_color = Color(0.35, 0.9, 0.95, 0.45)
	fill.shadow_size = 5
	progress.add_theme_stylebox_override("fill", fill)
