extends Control

const PrivacyDialogScene = preload("res://scenes/privacy_dialog.tscn")

@onready var play_button: Button = $Margin/VBox/PlayButton
@onready var daily_button: Button = $Margin/VBox/DailyButton
@onready var settings_button: Button = $Margin/VBox/SettingsButton
@onready var chapter_label: Label = $Margin/VBox/ChapterPanel/ChapterLabel
@onready var mascot: TextureRect = $Margin/VBox/Mascot
@onready var brand_title: Label = $Margin/VBox/BrandTitle

func _ready() -> void:
	_apply_game_styles()
	play_button.pressed.connect(_start_play)
	daily_button.pressed.connect(_start_daily)
	settings_button.pressed.connect(_open_settings)
	chapter_label.text = "7 GAME TYPES  •  14 STARTER LEVELS"
	_animate_entrance()
	_start_idle_motion()
	if not GameState.privacy_accepted or GameState.show_privacy_on_start:
		_show_privacy_policy()
	if GameState.privacy_accepted and DailyReminder.consume_open_daily_request():
		print("[DailyReminder] Opening today's exercises from notification")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/daily_challenge.tscn")

func _show_privacy_policy() -> void:
	var dialog := PrivacyDialogScene.instantiate()
	add_child(dialog)

func _start_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game_type_select.tscn")

func _start_daily() -> void:
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn")

func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _apply_game_styles() -> void:
	_style_button_3d(play_button, Color("#79eadc"), Color("#27aeb4"), Color("#142442"))
	_style_button_3d(daily_button, Color("#ff9b82"), Color("#b94d72"), Color("#302046"))
	_style_button_3d(settings_button, Color("#434cb0"), Color("#9098eb"), Color.WHITE)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.11, 0.37, 0.88)
	panel_style.border_color = Color("#77e4df")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.01, 0.01, 0.11, 0.5)
	panel_style.shadow_size = 7
	panel_style.shadow_offset = Vector2(0, 4)
	$Margin/VBox/ChapterPanel.add_theme_stylebox_override("panel", panel_style)

func _style_button_3d(button: Button, fill: Color, dark: Color, text_color: Color) -> void:
	button.add_theme_stylebox_override("normal", _button_style(fill, dark, 9, 7))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.12), dark, 11, 8))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.12), dark, 3, 2))
	button.add_theme_stylebox_override("focus", _button_style(fill, Color("#fff0a6"), 9, 7))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, text_color)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.18))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 3)
	button.button_down.connect(_animate_button.bind(button, true))
	button.button_up.connect(_animate_button.bind(button, false))

func _button_style(fill: Color, border: Color, shadow_size: int, shadow_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(19)
	style.shadow_color = Color(0.01, 0.01, 0.12, 0.55)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, shadow_y)
	style.anti_aliasing = true
	return style

func _animate_button(button: Button, pressed: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(0.97, 0.97) if pressed else Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_entrance() -> void:
	mascot.modulate.a = 0.0
	mascot.scale = Vector2(0.88, 0.88)
	mascot.pivot_offset = mascot.size * 0.5
	brand_title.modulate.a = 0.0
	for button in [play_button, daily_button, settings_button]:
		button.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(brand_title, "modulate:a", 1.0, 0.45)
	tween.tween_property(mascot, "modulate:a", 1.0, 0.55).set_delay(0.12)
	tween.tween_property(mascot, "scale", Vector2.ONE, 0.7).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(play_button, "modulate:a", 1.0, 0.4).set_delay(0.42)
	tween.tween_property(daily_button, "modulate:a", 1.0, 0.4).set_delay(0.55)
	tween.tween_property(settings_button, "modulate:a", 1.0, 0.4).set_delay(0.68)

func _start_idle_motion() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	var tween := create_tween().set_loops()
	tween.tween_property(mascot, "modulate", Color(1.08, 1.08, 1.08, 1), 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mascot, "modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)

