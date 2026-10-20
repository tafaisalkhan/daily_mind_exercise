extends Control

const DATA_PATH := "res://assets/data/game_types/synonyms.json"
const BALLOON_TEXTURE := preload("res://assets/gameplay_sprites/balloon-flat-2d-v3.png")
const BACK_ICON := preload("res://assets/ui/back-arrow.svg")
const BALLOON_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BALLOON_SIZE := 176.0
const STAR_TEXTURE := preload("res://assets/generated/victory-star.png")
const RESULT_EFFECTS = preload("res://scripts/result_effects.gd")

var current_level := 1
var level_data: Dictionary = {}
var balloons: Array[TextureButton] = []
var pending_balloons: Array = []
var selected: TextureButton
var completed_pairs := 0
var hearts := 3
var seconds_left := 60
var finished := false
var spawn_area: Control
var dock_panel: PanelContainer
var dock_label: Label
var timer_label: Label
var hearts_label: Label
var progress_label: Label
var result_panel: PanelContainer
var result_title: Label
var result_stars: HBoxContainer
var next_button: Button
var mode_title: Label
var prompt_label: Label
var timer: Timer
var spawn_timer: Timer

func _ready() -> void:
	current_level = clampi(GameState.type_level, 1, 1000)
	_build_ui()
	_load_level()

func _process(delta: float) -> void:
	if finished or get_tree().paused:
		return
	var float_time := Time.get_ticks_msec() / 1000.0
	for balloon in balloons.duplicate():
		if not is_instance_valid(balloon):
			continue

		# Gentle idle motion keeps settled balloons alive.
		var float_phase := float(balloon.get_meta("float_phase", 0.0))
		var float_speed := float(balloon.get_meta("float_speed", 1.0))
		var float_wave: float = sin(float_time * float_speed + float_phase)
		var lateral_velocity: float = float(balloon.get_meta("lateral_velocity", 0.0))
		var drift_velocity: float = float(balloon.get_meta("drift_velocity", 24.0))
		balloon.rotation = float_wave * 0.035 + lateral_velocity * 0.0015
		var breathe := 1.0 + float_wave * 0.009
		balloon.scale = Vector2(breathe, 1.0 - float_wave * 0.004)

		# Proportional repulsion: overlapping balloons push each other sideways.
		var balloon_center: Vector2 = balloon.position + balloon.size * 0.5
		for other in balloons:
			if other == balloon or not is_instance_valid(other):
				continue
			var other_center: Vector2 = other.position + other.size * 0.5
			var separation: Vector2 = balloon_center - other_center
			var distance: float = separation.length()
			var minimum_distance: float = BALLOON_SIZE - 8.0
			if distance < minimum_distance:
				var overlap: float = minimum_distance - distance
				var direction_x: float = separation.x / maxf(distance, 1.0)
				if absf(direction_x) < 0.08:
					direction_x = 1.0 if float_phase > float(other.get_meta("float_phase", 0.0)) else -1.0
				lateral_velocity += direction_x * overlap * 11.0 * delta
		# Keep every balloon travelling sideways; damping to zero made upper
		# balloons stop and trap the balloons below them.
		lateral_velocity = move_toward(lateral_velocity, drift_velocity, 45.0 * delta)
		lateral_velocity = clampf(lateral_velocity, -90.0, 90.0)
		var max_x: float = maxf(0.0, spawn_area.size.x - balloon.size.x)
		var next_x: float = clampf(balloon.position.x + lateral_velocity * delta, 0.0, max_x)
		if next_x <= 0.0 or next_x >= max_x:
			drift_velocity = -drift_velocity
			lateral_velocity = drift_velocity
			balloon.set_meta("drift_velocity", drift_velocity)
		balloon.position.x = next_x
		balloon.set_meta("lateral_velocity", lateral_velocity)

		# Constant buoyancy: pause only while a balloon above blocks the path.
		var speed := float(balloon.get_meta("speed", 76.0))
		var proposed_y := maxf(4.0, balloon.position.y - speed * delta)
		var proposed_rect := Rect2(Vector2(balloon.position.x, proposed_y), balloon.size).grow(-2.0)
		var blocked := false
		var escape_direction: float = 0.0
		for other in balloons:
			if other == balloon or not is_instance_valid(other):
				continue
			if other.position.y < balloon.position.y and proposed_rect.intersects(Rect2(other.position, other.size).grow(-2.0)):
				blocked = true
				var center_difference: float = balloon.position.x - other.position.x
				if absf(center_difference) > 2.0:
					escape_direction = signf(center_difference)
				else:
					escape_direction = 1.0 if float_phase > float(other.get_meta("float_phase", 0.0)) else -1.0
				break
		if blocked:
			# Steer decisively around the obstacle instead of applying a tiny nudge.
			drift_velocity = escape_direction * maxf(absf(drift_velocity), 48.0)
			lateral_velocity = move_toward(lateral_velocity, drift_velocity, 260.0 * delta)
			balloon.position.x = clampf(balloon.position.x + lateral_velocity * delta, 0.0, max_x)
			balloon.set_meta("drift_velocity", drift_velocity)
			balloon.set_meta("lateral_velocity", lateral_velocity)
		else:
			balloon.position.y = proposed_y
func _build_ui() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/level_backgrounds/synonym-meadow.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 14
	header.offset_top = 14
	header.offset_right = -14
	header.offset_bottom = 76
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	var back := Button.new()
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.tooltip_text = "Back"
	back.custom_minimum_size = Vector2(58, 58)
	back.add_theme_font_size_override("font_size", 36)
	back.add_theme_stylebox_override("normal", _style(Color("#e95545"), Color("#8c211b"), 18))
	back.pressed.connect(_back)
	header.add_child(back)
	timer_label = _label_panel("01:00", Color("#fff0c8"), Color("#193d60"), 24)
	timer_label.custom_minimum_size = Vector2(120, 58)
	header.add_child(timer_label)
	var level_label := _label_panel("LEVEL %d" % current_level, Color("#8c4c21"), Color.WHITE, 20)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(level_label)
	hearts_label = _label_panel("♥ ♥ ♥", Color("#fff0c8"), Color("#e62e36"), 25)
	hearts_label.custom_minimum_size = Vector2(118, 58)
	header.add_child(hearts_label)
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.custom_minimum_size = Vector2(58, 58)
	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.add_theme_font_size_override("font_size", 25)
	pause.add_theme_stylebox_override("normal", _style(Color("#f5a31d"), Color("#a34e0c"), 18))
	pause.pressed.connect(_toggle_pause)
	header.add_child(pause)

	var instruction := PanelContainer.new()
	instruction.set_anchors_preset(Control.PRESET_TOP_WIDE)
	instruction.offset_left = 36
	instruction.offset_top = 92
	instruction.offset_right = -36
	instruction.offset_bottom = 202
	instruction.add_theme_stylebox_override("panel", _style(Color("#8d4d22"), Color("#f7bd48"), 22))
	add_child(instruction)
	var instruction_box := VBoxContainer.new()
	instruction_box.alignment = BoxContainer.ALIGNMENT_CENTER
	instruction.add_child(instruction_box)
	mode_title = Label.new()
	mode_title.text = "BALLOON MATCH"
	mode_title.name = "ModeTitle"
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.add_theme_font_size_override("font_size", 28)
	mode_title.add_theme_color_override("font_color", Color("#ffd53d"))
	instruction_box.add_child(mode_title)
	prompt_label = Label.new()
	prompt_label.name = "Prompt"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_box.add_child(prompt_label)

	spawn_area = Control.new()
	spawn_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spawn_area.offset_top = 210
	spawn_area.offset_bottom = -150
	spawn_area.clip_contents = true
	add_child(spawn_area)

	dock_panel = PanelContainer.new()
	dock_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock_panel.offset_left = 72
	dock_panel.offset_top = -138
	dock_panel.offset_right = -72
	dock_panel.offset_bottom = -70
	dock_panel.add_theme_stylebox_override("panel", _style(Color(1, 0.94, 0.74, 0.96), Color("#dd8a22"), 20))
	add_child(dock_panel)
	dock_label = Label.new()
	dock_label.text = "Tap a balloon to select it"
	dock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dock_label.add_theme_font_size_override("font_size", 20)
	dock_label.add_theme_color_override("font_color", Color("#50260f"))
	dock_panel.add_child(dock_label)

	progress_label = _label_panel("0 / 4 PAIRS", Color("#126b50"), Color.WHITE, 17)
	progress_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	progress_label.offset_left = 14
	progress_label.offset_top = -60
	progress_label.offset_right = 170
	progress_label.offset_bottom = -12
	add_child(progress_label)
	var hint := Button.new()
	hint.text = "WATCH AD HINT"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -164
	hint.offset_top = -60
	hint.offset_right = -14
	hint.offset_bottom = -12
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_stylebox_override("normal", _style(Color("#258dcc"), Color("#11517c"), 16))
	hint.pressed.connect(_hint)
	add_child(hint)

	result_panel = PanelContainer.new()
	result_panel.visible = false
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -200
	result_panel.offset_top = -205
	result_panel.offset_right = 200
	result_panel.offset_bottom = 205
	result_panel.z_index = 50
	result_panel.add_theme_stylebox_override("panel", _style(Color("#fff1c8"), Color("#efad28"), 28))
	add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_box)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 31)
	result_title.add_theme_color_override("font_color", Color("#613115"))
	result_box.add_child(result_title)
	result_stars = HBoxContainer.new()
	result_stars.name = "Stars"
	result_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_child(result_stars)
	for index in range(3):
		var star := TextureRect.new()
		star.custom_minimum_size = Vector2(76, 76)
		star.texture = STAR_TEXTURE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		result_stars.add_child(star)
	next_button = Button.new()
	next_button.name = "Next"
	next_button.text = "NEXT LEVEL ▶"
	if GameState.game_mode == "daily":
		next_button.text = "BACK TO DAILY"
	next_button.custom_minimum_size = Vector2(250, 62)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.add_theme_font_size_override("font_size", 21)
	next_button.add_theme_stylebox_override("normal", _style(Color("#31aa50"), Color("#12642c"), 18))
	next_button.pressed.connect(_next)
	result_box.add_child(next_button)

	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_spawn_next_balloon)
	add_child(spawn_timer)

func _load_level() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	level_data = data["levels"][current_level - 1]
	seconds_left = int(level_data.get("time", 60))
	mode_title.text = "BALLOON " + str(level_data.get("relation", "MATCH"))
	prompt_label.text = str(level_data.get("prompt", ""))
	_start_balloon_stream.call_deferred()
	timer.start()

func _start_balloon_stream() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	pending_balloons = level_data.get("balloons", []).duplicate(true)
	pending_balloons.shuffle()
	_spawn_next_balloon()

func _spawn_next_balloon() -> void:
	if finished or pending_balloons.is_empty():
		return
	var entry: Dictionary = pending_balloons.pop_front()
	var index := balloons.size()
	var balloon := _create_balloon(index, str(entry["word"]), int(entry["pair"]))
	balloon.position = Vector2(_find_spawn_x(balloon.size), spawn_area.size.y + 24.0)
	spawn_area.add_child(balloon)
	balloons.append(balloon)
	balloon.scale = Vector2(0.72, 0.72)
	balloon.modulate.a = 0.0
	var appear := create_tween().set_parallel(true)
	appear.tween_property(balloon, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(balloon, "modulate:a", 1.0, 0.18)
	if not pending_balloons.is_empty():
		spawn_timer.start(randf_range(1.0, 1.6))

func _find_spawn_x(balloon_size: Vector2) -> float:
	var max_x := maxf(4.0, spawn_area.size.x - balloon_size.x - 4.0)
	for attempt in range(30):
		var candidate_x := randf_range(4.0, max_x)
		var spawn_rect := Rect2(Vector2(candidate_x, spawn_area.size.y - 8.0), balloon_size).grow(-2.0)
		var safe := true
		for active_balloon in balloons:
			if is_instance_valid(active_balloon) and spawn_rect.intersects(Rect2(active_balloon.position, active_balloon.size)):
				safe = false
				break
		if safe:
			return candidate_x
	return randf_range(4.0, max_x)
func _create_balloon(index: int, word: String, pair_id: int) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = BALLOON_TEXTURE
	button.ignore_texture_size = true
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.size = Vector2(BALLOON_SIZE, BALLOON_SIZE)
	var balloon_colors := [
		Color("#ff6148"), Color("#ffd23f"), Color("#42c978"), Color("#38a8ff"),
		Color("#a76bff"), Color("#ff68b2"), Color("#ff9638"), Color("#42d7d0")
	]
	button.self_modulate = balloon_colors[index % balloon_colors.size()]
	button.set_meta("word", word)
	button.set_meta("pair", pair_id)
	var speed_groups: Array[float] = [randf_range(42.0, 52.0), randf_range(66.0, 78.0), randf_range(94.0, 108.0)]
	button.set_meta("speed", speed_groups[index % speed_groups.size()])
	button.set_meta("float_phase", randf_range(0.0, TAU))
	button.set_meta("float_speed", randf_range(0.85, 1.25))
	button.set_meta("lateral_velocity", randf_range(-8.0, 8.0))
	button.set_meta("drift_velocity", (1.0 if randf() >= 0.5 else -1.0) * randf_range(22.0, 34.0))
	button.pivot_offset = button.size * 0.5
	button.pressed.connect(_balloon_tapped.bind(button))
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 20
	label.offset_top = 34
	label.offset_right = -20
	label.offset_bottom = -43
	label.text = _format_balloon_word(word.to_upper())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.add_theme_font_override("font", BALLOON_FONT)
	label.add_theme_font_size_override("font_size", _balloon_font_size(word))
	var dark_balloon: bool = index % balloon_colors.size() in [0, 3, 4]
	label.add_theme_color_override("font_color", Color("#fffaf0") if dark_balloon else Color("#191c37"))
	label.add_theme_color_override("font_outline_color", Color("#27102e") if dark_balloon else Color("#fffaf0"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _format_balloon_word(word: String) -> String:
	if word.contains(" ") or word.length() <= 9:
		return word
	var split_at := int(ceil(word.length() / 2.0))
	return word.substr(0, split_at) + "
" + word.substr(split_at)

func _balloon_font_size(word: String) -> int:
	if word.length() <= 6:
		return 29
	if word.length() <= 9:
		return 25
	if word.length() <= 12:
		return 22
	return 19
func _balloon_tapped(balloon: TextureButton) -> void:
	if finished:
		return
	if selected == null:
		selected = balloon
		balloon.modulate = Color("#fff06a")
		dock_label.text = str(balloon.get_meta("word")) + "  — find its match"
		return
	if balloon == selected:
		selected.modulate = Color.WHITE
		selected = null
		dock_label.text = "Tap a balloon to select it"
		return
	if int(balloon.get_meta("pair")) == int(selected.get_meta("pair")):
		var first := selected
		selected = null
		completed_pairs += 1
		dock_label.text = "Correct! Both balloons popped."
		progress_label.text = "%d / 4 PAIRS" % completed_pairs
		_burst(first)
		_burst(balloon)
		AudioManager.play_place(true)
		if completed_pairs >= 4:
			await get_tree().create_timer(0.45).timeout
			_complete()
	else:
		_wrong(balloon)

func _burst(balloon: TextureButton) -> void:
	balloons.erase(balloon)
	balloon.disabled = true
	var burst_center := balloon.global_position + balloon.size * 0.5
	_spawn_burst_particles(burst_center, balloon.modulate)
	balloon.pivot_offset = balloon.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(balloon, "scale", Vector2(1.65, 1.65), 0.13).set_trans(Tween.TRANS_BACK)
	tween.tween_property(balloon, "modulate:a", 0.0, 0.2)
	tween.tween_property(balloon, "rotation", randf_range(-0.45, 0.45), 0.2)
	tween.chain().tween_callback(balloon.queue_free)

func _spawn_burst_particles(center: Vector2, tint: Color) -> void:
	for index in range(14):
		var particle := TextureRect.new()
		particle.texture = STAR_TEXTURE
		particle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		particle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var particle_size := randf_range(12.0, 25.0)
		particle.size = Vector2(particle_size, particle_size)
		particle.global_position = center - particle.size * 0.5
		particle.modulate = Color(tint.r, tint.g, tint.b, 1.0)
		particle.z_index = 40
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(particle)
		var angle := TAU * float(index) / 14.0 + randf_range(-0.14, 0.14)
		var target := center + Vector2.from_angle(angle) * randf_range(55.0, 105.0)
		var particle_tween := create_tween().set_parallel(true)
		particle_tween.tween_property(particle, "global_position", target - particle.size * 0.5, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.46)
		particle_tween.tween_property(particle, "rotation", angle + PI, 0.46)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.46).set_delay(0.1)
		particle_tween.chain().tween_callback(particle.queue_free)

func _wrong(balloon: TextureButton) -> void:
	if selected != null and is_instance_valid(selected):
		selected.modulate = Color.WHITE
	selected = null
	hearts -= 1
	hearts_label.text = " ".join(["♥", "♥", "♥"].slice(0, hearts))
	dock_label.text = "Not a match — try another balloon"
	AudioManager.play_place(false)
	var tween := create_tween()
	var origin := balloon.position.x
	tween.tween_property(balloon, "position:x", origin - 12, 0.06)
	tween.tween_property(balloon, "position:x", origin + 12, 0.06)
	tween.tween_property(balloon, "position:x", origin, 0.06)
	if hearts <= 0:
		_fail()

func _hint() -> void:
	if selected == null or finished:
		return
	AdManager.request_rewarded_hint(Callable(self, "_grant_hint"), Callable(self, "_hint_unavailable"))

func _hint_unavailable(message: String) -> void:
	dock_label.text = message

func _grant_hint() -> void:
	if selected == null or finished:
		return
	AudioManager.play_hint()
	for balloon in balloons:
		if balloon != selected and int(balloon.get_meta("pair")) == int(selected.get_meta("pair")):
			var tween := create_tween().set_loops(3)
			tween.tween_property(balloon, "modulate", Color("#fff23d"), 0.16)
			tween.tween_property(balloon, "modulate", Color.WHITE, 0.16)
			break

func _tick() -> void:
	if finished:
		return
	seconds_left -= 1
	timer_label.text = "%02d:%02d" % [seconds_left / 60, seconds_left % 60]
	if seconds_left <= 0:
		_fail()

func _complete() -> void:
	finished = true
	timer.stop()
	var stars := 3
	var reward := stars * 5
	GameState.register_game_type_win(0, current_level, stars, reward)
	result_title.text = "ALL BALLOONS MATCHED!\n+%d COINS" % reward
	result_stars.visible = true
	for index in range(3):
		result_stars.get_child(index).modulate = Color.WHITE if index < stars else Color(0.2, 0.2, 0.2, 0.25)
	next_button.text = "NEXT LEVEL ▶"
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
		get_tree().reload_current_scene()
	elif GameState.game_mode == "daily":
		get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn")
	else:
		GameState.type_level = GameState.next_game_type_level(0)
		get_tree().reload_current_scene()

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused

func _back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn" if GameState.game_mode == "daily" else "res://scenes/game_type_select.tscn")

func _label_panel(value: String, background: Color, foreground: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", foreground)
	label.add_theme_stylebox_override("normal", _style(background, Color("#95501d"), 17))
	return label

func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style
