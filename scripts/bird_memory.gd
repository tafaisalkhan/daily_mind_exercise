extends Control

const BACKGROUND := preload("res://assets/level_backgrounds/word-garden.png")
const BACK_ICON := preload("res://assets/ui/back-arrow.svg")
const STAR_TEXTURE := preload("res://assets/generated/victory-star.png")
const RESULT_EFFECTS := preload("res://scripts/result_effects.gd")
const BIRD_SHEET := preload("res://resources/birds/bird-parade-sprites.png")
const BIRDS := [
	{"name": "ROBIN", "color": Color("#f27b65")},
	{"name": "FINCH", "color": Color("#f6ca59")},
	{"name": "PARROT", "color": Color("#65d6a0")},
	{"name": "OWL", "color": Color("#89aeed")}
]

var current_level := 1
var sequence: Array[int] = []
var answer_index := 0
var hearts := 3
var seconds_left := 60
var finished := false
var showing := false
var playback_id := 0
var bird_buttons: Array[Button] = []
var timer: Timer
var timer_label: Label
var hearts_label: Label
var level_label: Label
var pause_button: Button
var coins_label: Label
var instruction_label: Label
var preview_icon: TextureRect
var preview_name: Label
var progress_label: Label
var hint_button: Button
var replay_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_stars: HBoxContainer
var next_button: Button

func _ready() -> void:
	current_level = clampi(GameState.type_level, 1, 1000)
	_build_ui()
	_load_level()

func _build_ui() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.12)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 60
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var back := Button.new()
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(58, 58)
	back.process_mode = Node.PROCESS_MODE_ALWAYS
	back.add_theme_stylebox_override("normal", _style(Color("#e95545"), Color("#8c211b")))
	back.pressed.connect(_back)
	header.add_child(back)
	timer_label = _pill_label("01:00", Color("#fff0c8"), Color("#193d60"), 24)
	timer_label.custom_minimum_size = Vector2(120, 58)
	header.add_child(timer_label)
	level_label = _pill_label("LEVEL %d" % current_level, Color("#8c4c21"), Color.WHITE, 20)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(level_label)
	hearts_label = _pill_label("♥ ♥ ♥", Color("#fff0c8"), Color("#e62e36"), 25)
	hearts_label.custom_minimum_size = Vector2(118, 58)
	header.add_child(hearts_label)
	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.custom_minimum_size = Vector2(58, 58)
	pause_button.add_theme_font_size_override("font_size", 25)
	pause_button.add_theme_stylebox_override("normal", _style(Color("#f5a31d"), Color("#a34e0c")))
	pause_button.pressed.connect(_toggle_pause)
	header.add_child(pause_button)

	var instruction := PanelContainer.new()
	instruction.custom_minimum_size.y = 112
	instruction.add_theme_stylebox_override("panel", _style(Color("#8d4d22"), Color("#f7bd48"), 22))
	column.add_child(instruction)
	var instruction_box := VBoxContainer.new()
	instruction_box.alignment = BoxContainer.ALIGNMENT_CENTER
	instruction.add_child(instruction_box)
	instruction_box.add_child(_label("BIRD PARADE", 28, Color("#ffd53d")))
	instruction_label = _label("Watch the birds, then repeat their order!", 19, Color.WHITE)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_box.add_child(instruction_label)

	var preview := PanelContainer.new()
	preview.custom_minimum_size.y = 208
	preview.add_theme_stylebox_override("panel", _style(Color("#fff0c8"), Color("#f7bd48"), 22))
	column.add_child(preview)
	var preview_box := VBoxContainer.new()
	preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(preview_box)
	preview_icon = TextureRect.new()
	preview_icon.custom_minimum_size = Vector2(150, 150)
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_box.add_child(preview_icon)
	preview_name = _label("GET READY", 23, Color("#8c4c21"))
	preview_box.add_child(preview_name)

	progress_label = _pill_label("0 / 4 BIRDS", Color("#fff0c8"), Color("#4d2512"), 20)
	column.add_child(progress_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for index in range(BIRDS.size()):
		var bird: Dictionary = BIRDS[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 135)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _style(Color("#fff0c8"), bird.color, 18))
		button.add_theme_stylebox_override("hover", _style(Color("#fff8e2"), bird.color, 18))
		button.add_theme_stylebox_override("pressed", _style(Color("#f8dc9d"), bird.color, 18))
		button.add_theme_stylebox_override("disabled", _style(Color("#e8dcc3"), Color("#b6a486"), 18))
		button.pressed.connect(_choose_bird.bind(index))
		grid.add_child(button)
		bird_buttons.append(button)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(78, 78)
		icon.texture = _bird_texture(index)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var name := _label(str(bird.name), 20, Color("#4d2512"))
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	column.add_child(action_row)
	replay_button = Button.new()
	replay_button.text = "REPLAY"
	replay_button.custom_minimum_size.y = 58
	replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_button.add_theme_font_size_override("font_size", 19)
	replay_button.add_theme_stylebox_override("normal", _style(Color("#f5a31d"), Color("#a34e0c")))
	replay_button.pressed.connect(_replay)
	action_row.add_child(replay_button)
	hint_button = Button.new()
	hint_button.text = "HINT" if OS.get_name() != "Android" else "WATCH AD FOR HINT"
	hint_button.custom_minimum_size.y = 58
	hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_button.add_theme_font_size_override("font_size", 19)
	hint_button.add_theme_stylebox_override("normal", _style(Color("#258dcc"), Color("#11517c")))
	hint_button.pressed.connect(_hint)
	action_row.add_child(hint_button)
	coins_label = _pill_label("%d COINS" % GameState.coins, Color("#fff0c8"), Color("#4d2512"), 19)
	coins_label.custom_minimum_size.y = 58
	column.add_child(coins_label)

	result_panel = PanelContainer.new()
	result_panel.visible = false
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -205
	result_panel.offset_top = -220
	result_panel.offset_right = 205
	result_panel.offset_bottom = 220
	result_panel.z_index = 50
	result_panel.add_theme_stylebox_override("panel", _style(Color("#fff2cf"), Color("#f2aa24"), 28))
	add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_box)
	result_title = _label("", 32, Color("#653317"))
	result_box.add_child(result_title)
	result_stars = HBoxContainer.new()
	result_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_child(result_stars)
	for _index in range(3):
		var star := TextureRect.new()
		star.custom_minimum_size = Vector2(82, 82)
		star.texture = STAR_TEXTURE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		result_stars.add_child(star)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(260, 64)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.add_theme_font_size_override("font_size", 22)
	next_button.add_theme_stylebox_override("normal", _style(Color("#35a84d"), Color("#12642c")))
	next_button.pressed.connect(_next)
	result_box.add_child(next_button)

	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)

func _load_level() -> void:
	playback_id += 1
	finished = false
	showing = false
	answer_index = 0
	hearts = 3
	hearts_label.text = "♥ ♥ ♥"
	seconds_left = 45 + mini(45, int(current_level / 25))
	timer_label.text = "%02d:%02d" % [int(seconds_left / 60), seconds_left % 60]
	var length := mini(7, 3 + int((current_level - 1) / 20))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4729 + current_level * 7919
	sequence.clear()
	for index in range(length):
		var value := rng.randi_range(0, BIRDS.size() - 1)
		if index > 0 and value == sequence[index - 1]:
			value = (value + rng.randi_range(1, BIRDS.size() - 1)) % BIRDS.size()
		sequence.append(value)
	_update_progress()
	_play_sequence.call_deferred()

func _play_sequence() -> void:
	if finished or showing:
		return
	showing = true
	playback_id += 1
	var run_id := playback_id
	timer.stop()
	_set_buttons_enabled(false)
	replay_button.disabled = true
	hint_button.disabled = true
	instruction_label.text = "WATCH THE BIRD PARADE"
	preview_icon.texture = null
	preview_name.text = "GET READY"
	await get_tree().create_timer(0.65, false).timeout
	for bird_index in sequence:
		if not is_inside_tree() or finished or run_id != playback_id:
			return
		var bird: Dictionary = BIRDS[bird_index]
		preview_icon.texture = _bird_texture(bird_index)
		preview_name.text = str(bird.name)
		AudioManager.play_tap()
		await get_tree().create_timer(maxf(0.55, 1.2 - current_level * 0.0005), false).timeout
		if not is_inside_tree() or finished or run_id != playback_id:
			return
		preview_icon.texture = null
		preview_name.text = "•"
		await get_tree().create_timer(0.25, false).timeout
	if not is_inside_tree() or finished or run_id != playback_id:
		return
	showing = false
	preview_name.text = "YOUR TURN"
	instruction_label.text = "Tap the birds in the order you saw."
	_set_buttons_enabled(true)
	replay_button.disabled = false
	hint_button.disabled = false
	timer.start()

func _choose_bird(index: int) -> void:
	if finished or showing:
		return
	if index == sequence[answer_index]:
		answer_index += 1
		_update_progress()
		AudioManager.play_place(true)
		preview_icon.texture = _bird_texture(index)
		preview_name.text = "CORRECT!"
		if answer_index >= sequence.size():
			_complete()
	else:
		hearts -= 1
		hearts_label.text = " ".join(["♥", "♥", "♥"].slice(0, hearts))
		preview_name.text = "TRY AGAIN"
		AudioManager.play_place(false)
		if hearts <= 0:
			_fail()

func _update_progress() -> void:
	progress_label.text = "%d / %d BIRDS" % [answer_index, sequence.size()]

func _set_buttons_enabled(enabled: bool) -> void:
	for button in bird_buttons:
		button.disabled = not enabled

func _replay() -> void:
	if not finished and not showing:
		_play_sequence()

func _hint() -> void:
	if finished or showing:
		return
	if OS.get_name() != "Android":
		_grant_hint()
	else:
		AdManager.request_rewarded_hint(Callable(self, "_grant_hint"), Callable(self, "_hint_unavailable"))

func _hint_unavailable(message: String) -> void:
	instruction_label.text = message

func _grant_hint() -> void:
	if finished or showing or answer_index >= sequence.size():
		return
	AudioManager.play_hint()
	_choose_bird(sequence[answer_index])

func _tick() -> void:
	if finished or showing:
		return
	seconds_left -= 1
	timer_label.text = "%02d:%02d" % [int(seconds_left / 60), seconds_left % 60]
	if seconds_left <= 0:
		_fail()

func _complete() -> void:
	finished = true
	timer.stop()
	_set_buttons_enabled(false)
	var stars := GameState.stars_for_mistakes(3 - hearts)
	var reward := GameState.coins_for_stars(stars)
	GameState.register_game_type_win(8, current_level, stars, reward)
	coins_label.text = "%d COINS" % GameState.coins
	result_title.text = "PARADE COMPLETE!\n+%d COINS" % reward
	result_stars.visible = true
	for index in range(3):
		result_stars.get_child(index).modulate = Color.WHITE if index < stars else Color(0.2, 0.2, 0.2, 0.25)
	next_button.text = "BACK TO DAILY" if GameState.game_mode == "daily" else "NEXT LEVEL ▶"
	result_panel.visible = true
	AudioManager.play_victory()
	RESULT_EFFECTS.celebrate(self, result_stars, stars)
	var ad_tween := create_tween()
	ad_tween.tween_interval(1.5)
	ad_tween.tween_callback(AdManager.show_interstitial)

func _fail() -> void:
	finished = true
	timer.stop()
	_set_buttons_enabled(false)
	result_title.text = "TRY AGAIN"
	result_stars.visible = false
	next_button.text = "RETRY"
	result_panel.visible = true
	AudioManager.play_level_fail()

func _next() -> void:
	if result_title.text == "TRY AGAIN":
		get_tree().reload_current_scene()
	elif GameState.game_mode == "daily":
		get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn")
	else:
		GameState.type_level = GameState.next_game_type_level(8)
		get_tree().reload_current_scene()

func _back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn" if GameState.game_mode == "daily" else "res://scenes/game_type_select.tscn")

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "▶" if get_tree().paused else "Ⅱ"

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _pill_label(value: String, fill: Color, ink: Color, font_size: int) -> Label:
	var label := _label(value, font_size, ink)
	label.add_theme_stylebox_override("normal", _style(fill, Color("#95501d"), 17))
	return label

func _bird_texture(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = BIRD_SHEET
	var half := BIRD_SHEET.get_size() / 2.0
	texture.region = Rect2(Vector2(index % 2, int(index / 2)) * half, half)
	return texture

func _style(fill: Color, border: Color, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0.01, 0.01, 0.12, 0.4)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style
