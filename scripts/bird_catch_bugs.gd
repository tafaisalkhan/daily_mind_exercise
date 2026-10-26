extends Control

const BACKGROUND := preload("res://assets/level_backgrounds/synonym-meadow.png")
const BACK_ICON := preload("res://assets/ui/back-arrow.svg")
const STAR_TEXTURE := preload("res://assets/generated/victory-star.png")
const BIRD_SHEET := preload("res://resources/birds/bird-parade-sprites.png")
const BUG_TEXTURE := preload("res://resources/birds/catch-bug.png")
const RESULT_EFFECTS := preload("res://scripts/result_effects.gd")
const BIRD_SIZE := 38.0
const BUG_ART_SIZE := Vector2(96, 78)
const CARRIED_BUG_SIZE := Vector2(30, 30)
const NOUNS := ["TREE", "BOOK", "CLOUD", "RIVER", "APPLE", "HOUSE", "MOON", "STAR", "CHAIR", "GARDEN", "FLOWER", "PENCIL", "WINDOW", "PLANET", "BRIDGE", "KITTEN"]
const VERBS := ["RUNNING", "JUMPING", "SWIMMING", "WRITING", "DANCING", "SINGING", "READING", "CLIMBING", "LAUGHING", "DRAWING", "SLEEPING", "COOKING", "BUILDING", "WALKING", "PAINTING", "HOPPING"]
const NOUNS_MEDIUM := ["BICYCLE", "LIBRARY", "DOCTOR", "KITCHEN", "DIAMOND", "RAINBOW", "AIRPLANE", "ELEPHANT", "THUNDER", "BACKPACK", "HOSPITAL", "COMPUTER", "COTTAGE", "PYRAMID", "VOLCANO", "BATTERY"]
const VERBS_MEDIUM := ["WHISPERING", "SKIPPING", "FOLDING", "SEARCHING", "REPAIRING", "GROWING", "WASHING", "COUNTING", "PULLING", "PUSHING", "HIDING", "CHASING", "PLANTING", "MENDING", "CARRYING", "TEACHING"]
const NOUNS_HARD := ["TELESCOPE", "MICROSCOPE", "SATELLITE", "COMPASS", "SCULPTURE", "ENGINE", "ANCHOR", "INSTRUMENT", "ARCHIVE", "FOSSIL", "EQUATOR", "OXYGEN", "GALAXY", "CHEMISTRY", "DINOSAUR", "MONUMENT"]
const VERBS_HARD := ["DISCOVERING", "MEASURING", "EXPLORING", "INVENTING", "CALCULATING", "OBSERVING", "CONSTRUCTING", "INVESTIGATING", "COMPARING", "ESTIMATING", "NAVIGATING", "COLLECTING", "TRANSLATING", "ANALYZING", "DESIGNING", "EXPERIMENTING"]
const TYPE_NAMES := ["NOUN", "VERB", "MULTIPLY", "DIVISIBLE"]

var current_level := 1
var current_mode := 0
var rng := RandomNumberGenerator.new()
var targets: Array[int] = []
var target_index := 0
var divisor := 5
var number_product := 10
var hearts := 3
var seconds_left := 75
var finished := false
var catching := false
var bugs: Array[Button] = []
var bug_area: Control
var bird_icon: TextureRect
var prompt_label: Label
var progress_label: Label
var hearts_label: Label
var timer_label: Label
var level_label: Label
var pause_button: Button
var hint_button: Button
var coins_label: Label
var result_panel: PanelContainer
var result_title: Label
var result_stars: HBoxContainer
var next_button: Button
var timer: Timer

func _ready() -> void:
	current_mode = clampi(GameState.bug_catch_mode, 0, 3)
	current_level = clampi(GameState.type_level, 1, 1000)
	rng.randomize()
	_build_ui()
	_load_level()

func _process(_delta: float) -> void:
	if finished or get_tree().paused:
		return
	var elapsed := Time.get_ticks_msec() / 1000.0
	var speed := minf(3.6, 0.85 + current_level * 0.002 + target_index * 0.08)
	for bug in bugs:
		if not is_instance_valid(bug) or bug.disabled:
			continue
		var base: Vector2 = bug.get_meta("base_position")
		var phase: float = bug.get_meta("phase")
		bug.position = base + Vector2(sin(elapsed * speed + phase) * 12.0, cos(elapsed * speed * 1.3 + phase) * 9.0)
		bug.rotation = sin(elapsed * speed * 1.7 + phase) * 0.045

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
	timer_label = _pill_label("01:15", Color("#fff0c8"), Color("#193d60"), 24)
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
	var prompt_panel := PanelContainer.new()
	prompt_panel.custom_minimum_size.y = 112
	prompt_panel.add_theme_stylebox_override("panel", _style(Color("#8d4d22"), Color("#f7bd48"), 22))
	column.add_child(prompt_panel)
	var instruction_box := VBoxContainer.new()
	instruction_box.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_panel.add_child(instruction_box)
	instruction_box.add_child(_label("BIRD CATCH BUGS", 28, Color("#ffd53d")))
	prompt_label = _label("CATCH A NOUN", 20, Color.WHITE)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_box.add_child(prompt_label)
	var mode_tag := _pill_label("MODE: %s" % TYPE_NAMES[current_mode], Color("#fff0c8"), Color("#8c4c21"), 17)
	mode_tag.custom_minimum_size.y = 38
	column.add_child(mode_tag)
	bug_area = Control.new()
	bug_area.custom_minimum_size.y = 428
	bug_area.clip_contents = true
	column.add_child(bug_area)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	bird_icon = TextureRect.new()
	bird_icon.custom_minimum_size = Vector2(BIRD_SIZE, BIRD_SIZE)
	bird_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bird_icon.texture = _bird_texture()
	bird_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bird_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	footer.add_child(bird_icon)
	var footer_text := VBoxContainer.new()
	footer_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_text)
	progress_label = _pill_label("0 / 9 BUGS", Color("#fff0c8"), Color("#4d2512"), 20)
	footer_text.add_child(progress_label)
	footer_text.add_child(_label("TAP THE RIGHT FLYING BUG", 16, Color("#4d2512")))
	hint_button = Button.new()
	hint_button.text = "HINT" if OS.get_name() != "Android" else "WATCH AD FOR HINT"
	hint_button.custom_minimum_size = Vector2(170, 58)
	hint_button.add_theme_font_size_override("font_size", 19)
	hint_button.add_theme_stylebox_override("normal", _style(Color("#258dcc"), Color("#11517c")))
	hint_button.pressed.connect(_hint)
	var tools_row := HBoxContainer.new()
	tools_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tools_row.add_theme_constant_override("separation", 16)
	column.add_child(tools_row)
	tools_row.add_child(hint_button)
	coins_label = _pill_label("%d COINS" % GameState.coins, Color("#fff0c8"), Color("#4d2512"), 19)
	coins_label.custom_minimum_size = Vector2(150, 58)
	tools_row.add_child(coins_label)
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
	targets.clear()
	for _round in range(mini(12, 5 + int(current_level / 60))):
		targets.append(current_mode)
	target_index = 0
	hearts = 3
	hearts_label.text = "♥ ♥ ♥"
	seconds_left = 65 + mini(35, int(current_level / 25))
	timer_label.text = "%02d:%02d" % [int(seconds_left / 60), seconds_left % 60]
	finished = false
	catching = false
	result_panel.visible = false
	level_label.text = "LEVEL %d" % current_level
	_update_prompt()
	_refresh_bugs.call_deferred()
	timer.start()

func _update_prompt() -> void:
	if target_index >= targets.size():
		return
	divisor = 5 if (current_level + target_index) % 2 == 1 else 7
	var factor := 2 + (current_level * 7 + target_index * 5) % mini(22, 5 + int(current_level / 40))
	number_product = divisor * factor
	if current_mode == 2:
		prompt_label.text = "CATCH %d × %d" % [divisor, factor]
	elif current_mode == 3:
		prompt_label.text = "CATCH A NUMBER DIVISIBLE BY %d" % divisor
	else:
		prompt_label.text = "CATCH A %s" % TYPE_NAMES[current_mode]
	progress_label.text = "%d / %d BUGS" % [target_index, targets.size()]

func _refresh_bugs() -> void:
	for bug in bugs:
		if is_instance_valid(bug):
			bug.queue_free()
	bugs.clear()
	if finished or not is_inside_tree():
		return
	var noun_pool: Array = NOUNS if current_level < 100 else (NOUNS_MEDIUM if current_level < 400 else NOUNS_HARD)
	var verb_pool: Array = VERBS if current_level < 100 else (VERBS_MEDIUM if current_level < 400 else VERBS_HARD)
	var level_offset := (current_level * 7 + target_index * 3 + rng.randi_range(0, 15)) % noun_pool.size()
	var labels := [
		{"kind": 0, "value": noun_pool[level_offset]},
		{"kind": 0, "value": noun_pool[(level_offset + 5) % noun_pool.size()]},
		{"kind": 1, "value": verb_pool[level_offset]},
		{"kind": 1, "value": verb_pool[(level_offset + 6) % verb_pool.size()]}
	]
	var maximum := maxi(30, number_product + 12 + int(current_level / 4))
	labels.append({"kind": 2, "value": str(number_product)})
	var decoy := rng.randi_range(3, maximum)
	while decoy == number_product or (current_mode == 3 and decoy % divisor == 0):
		decoy = rng.randi_range(3, maximum)
	labels.append({"kind": 2, "value": str(decoy)})
	labels.shuffle()
	var column_width := bug_area.size.x / 2.0
	for index in range(labels.size()):
		var data: Dictionary = labels[index]
		var bug := Button.new()
		bug.size = Vector2(148, 124)
		bug.pivot_offset = bug.size * 0.5
		var base := Vector2(column_width * (index % 2) + (column_width - bug.size.x) / 2.0, 6 + int(index / 2) * 140)
		bug.position = base
		bug.set_meta("base_position", base)
		bug.set_meta("phase", float(index) * 1.83)
		bug.set_meta("kind", data.kind)
		bug.set_meta("value", data.value)
		bug.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		bug.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		bug.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		bug.pressed.connect(_tap_bug.bind(bug))
		bug_area.add_child(bug)
		bugs.append(bug)
		var image := TextureRect.new()
		image.position = Vector2((bug.size.x - BUG_ART_SIZE.x) * 0.5, 5)
		image.size = BUG_ART_SIZE
		image.texture = BUG_TEXTURE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bug.add_child(image)
		var word_length := str(data.value).length()
		var label := _label(str(data.value), 17 if word_length <= 7 else (14 if word_length <= 11 else 12), Color("#fff8e8"))
		label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_left = 6
		label.offset_right = -6
		label.offset_top = -35
		label.offset_bottom = -2
		label.add_theme_stylebox_override("normal", _style(Color("#202c5d"), Color("#79eadc"), 11))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bug.add_child(label)

func _is_correct_bug(bug: Button) -> bool:
	var target_kind := 2 if current_mode >= 2 else current_mode
	if int(bug.get_meta("kind")) != target_kind:
		return false
	if current_mode < 2:
		return true
	var value := int(str(bug.get_meta("value")))
	return value == number_product if current_mode == 2 else value % divisor == 0

func _tap_bug(bug: Button) -> void:
	if finished or catching or not is_instance_valid(bug):
		return
	if _is_correct_bug(bug):
		_catch_bug(bug)
	else:
		hearts -= 1
		hearts_label.text = " ".join(["♥", "♥", "♥"].slice(0, hearts))
		AudioManager.play_place(false)
		var flash := create_tween()
		flash.tween_property(bug, "modulate", Color("#ff6b6b"), 0.10)
		flash.tween_property(bug, "modulate", Color.WHITE, 0.18)
		if hearts <= 0:
			_fail()

func _catch_bug(bug: Button) -> void:
	catching = true
	bug.disabled = true
	AudioManager.play_place(true)
	var swoop := TextureRect.new()
	swoop.texture = _bird_texture()
	swoop.size = Vector2(BIRD_SIZE, BIRD_SIZE)
	swoop.pivot_offset = swoop.size * 0.5
	swoop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swoop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swoop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swoop.z_index = 20
	add_child(swoop)
	swoop.global_position = bird_icon.global_position + (bird_icon.size - swoop.size) * 0.5
	bird_icon.visible = false
	var target_position := bug.global_position + Vector2(bug.size.x * 0.5, 44) - swoop.size * 0.5
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(swoop, "global_position", target_position, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(swoop, "rotation_degrees", -12.0, 0.30)
	await fly.finished
	if not is_inside_tree() or finished:
		bird_icon.visible = true
		swoop.queue_free()
		return
	var pickup := create_tween().set_parallel(true)
	pickup.tween_property(bug, "scale", Vector2(0.2, 0.2), 0.12)
	pickup.tween_property(bug, "modulate:a", 0.0, 0.12)
	await pickup.finished
	if not is_inside_tree() or finished:
		bird_icon.visible = true
		swoop.queue_free()
		return
	var carried_bug := TextureRect.new()
	carried_bug.texture = BUG_TEXTURE
	carried_bug.size = CARRIED_BUG_SIZE
	carried_bug.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carried_bug.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	carried_bug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carried_bug.z_index = 21
	add_child(carried_bug)
	carried_bug.global_position = target_position + Vector2(9, 25)
	var home := bird_icon.global_position + (bird_icon.size - swoop.size) * 0.5
	var carry := create_tween().set_parallel(true)
	carry.tween_property(swoop, "global_position", home, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	carry.tween_property(carried_bug, "global_position", home + Vector2(9, 25), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	carry.tween_property(swoop, "rotation_degrees", 0.0, 0.30)
	await carry.finished
	if not is_inside_tree() or finished:
		bird_icon.visible = true
		swoop.queue_free()
		carried_bug.queue_free()
		return
	swoop.queue_free()
	carried_bug.queue_free()
	bird_icon.visible = true
	target_index += 1
	if target_index >= targets.size():
		_complete()
		return
	_update_prompt()
	_refresh_bugs()
	catching = false

func _hint() -> void:
	if finished or catching:
		return
	if OS.get_name() != "Android":
		_grant_hint()
	else:
		AdManager.request_rewarded_hint(Callable(self, "_grant_hint"), Callable(self, "_hint_unavailable"))

func _hint_unavailable(message: String) -> void:
	prompt_label.text = message

func _grant_hint() -> void:
	if finished or catching:
		return
	for bug in bugs:
		if is_instance_valid(bug) and _is_correct_bug(bug):
			AudioManager.play_hint()
			_tap_bug(bug)
			return

func _tick() -> void:
	if finished:
		return
	seconds_left -= 1
	timer_label.text = "%02d:%02d" % [int(seconds_left / 60), seconds_left % 60]
	if seconds_left <= 0:
		_fail()

func _complete() -> void:
	finished = true
	timer.stop()
	var stars := GameState.stars_for_mistakes(3 - hearts)
	var reward := GameState.coins_for_stars(stars)
	GameState.register_bug_catch_win(current_mode, current_level, stars, reward)
	coins_label.text = "%d COINS" % GameState.coins
	result_title.text = "ALL BUGS CAUGHT!\n+%d COINS" % reward
	result_stars.visible = true
	for index in range(3):
		result_stars.get_child(index).modulate = Color.WHITE if index < stars else Color(0.2, 0.2, 0.2, 0.25)
	next_button.text = "BACK TO DAILY" if GameState.game_mode == "daily" else "PLAY ANOTHER MODE"
	result_panel.visible = true
	AudioManager.play_victory()
	RESULT_EFFECTS.celebrate(self, result_stars, stars)
	var ad_tween := create_tween()
	ad_tween.tween_interval(1.5)
	ad_tween.tween_callback(AdManager.show_interstitial)

func _fail() -> void:
	finished = true
	timer.stop()
	result_title.text = "TRY AGAIN"
	result_stars.visible = false
	next_button.text = "RETRY"
	result_panel.visible = true
	AudioManager.play_level_fail()

func _next() -> void:
	if result_title.text == "TRY AGAIN":
		_load_level()
	elif GameState.game_mode == "daily":
		get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn")
	else:
		GameState.start_game_type(9)
		get_tree().reload_current_scene()

func _back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn" if GameState.game_mode == "daily" else "res://scenes/game_type_select.tscn")

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "▶" if get_tree().paused else "Ⅱ"

func _bird_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = BIRD_SHEET
	var half := BIRD_SHEET.get_size() / 2.0
	texture.region = Rect2(half, half)
	return texture

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
