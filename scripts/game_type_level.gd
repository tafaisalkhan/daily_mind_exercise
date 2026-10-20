extends Control

const TYPE_FILES := [
	"res://assets/data/game_types/synonyms.json",
	"res://assets/data/game_types/word_builder.json",
	"res://assets/data/game_types/sentence_train.json",
	"res://assets/data/game_types/number_bridge.json",
	"res://assets/data/game_types/number_balance.json",
	"res://assets/data/game_types/number_maze.json",
	"res://assets/data/game_types/number_hunt.json",
	"res://assets/data/game_types/word_relay.json"
]
const RewardCoinTexture = preload("res://assets/generated/reward-coin.png")
const VictoryStarTexture = preload("res://assets/generated/victory-star.png")
const BACK_ICON := preload("res://assets/ui/back-arrow.svg")
const RESULT_EFFECTS = preload("res://scripts/result_effects.gd")

## Registry mapping game type IDs to their modular GameModeComponent scripts.
## To add a new interactive game mode in the future, register its script here.
const MODE_COMPONENTS := {
	"word_builder": preload("res://scripts/components/word_builder_component.gd"),
	"number_bridge": preload("res://scripts/components/bridge/number_bridge_component.gd"),
	"number_balance": preload("res://scripts/components/balance/number_balance_component.gd"),
	"number_maze": preload("res://scripts/components/maze/number_maze_component.gd"),
	"number_hunt": preload("res://scripts/components/hunt/number_hunt_component.gd"),
	"word_relay": preload("res://scripts/components/relay/word_relay_component.gd")
}

## Next main-progression level to load after completing all stages of a component game type
const MODE_NEXT_LEVEL := {
	"word_builder": 5,
	"number_bridge": 9,
	"number_balance": 13,
	"number_maze": 13,
	"word_relay": 1
}

var current_level := 1
var type_data: Dictionary = {}
var level_data: Dictionary = {}
var current_type_id: String = ""
var mode_stage_indices: Dictionary = {
	"word_builder": -1,
	"number_bridge": 0,
	"number_balance": 0,
	"number_maze": -1,
	"number_hunt": -1,
	"word_relay": -1
}
var active_component: GameModeComponent = null
var component_host: Control = null

var answer_index := 0
var selected_answers: Array[String] = []
var seconds_left := 0
var finished := false

var timer_label: Label
var hearts_label: Label
var level_label: Label
var coins_label: Label
var title_label: Label
var prompt_label: Label
var progress_label: Label
var sprite_rect: TextureRect
var choices_scroll: ScrollContainer
var choices_grid: GridContainer
var result_panel: PanelContainer
var result_title: Label
var result_stars: HBoxContainer
var next_button: Button
var tick_timer: Timer

func _ready() -> void:
	current_level = clampi(GameState.requested_level, 1, 16)
	_build_ui()
	_load_level(current_level)

func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.08)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 18)
	safe.add_theme_constant_override("margin_right", 18)
	safe.add_theme_constant_override("margin_top", 18)
	safe.add_theme_constant_override("margin_bottom", 18)
	add_child(safe)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	safe.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 68
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var back := Button.new()
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.tooltip_text = "Back"
	back.process_mode = Node.PROCESS_MODE_ALWAYS
	back.custom_minimum_size = Vector2(60, 60)
	back.add_theme_font_size_override("font_size", 36)
	back.add_theme_stylebox_override("normal", _button_style(Color("#e95545")))
	back.pressed.connect(_back)
	header.add_child(back)
	timer_label = _pill_label("00:45", Color("#fff2cf"), Color("#8d4b18"), 25)
	timer_label.custom_minimum_size = Vector2(128, 60)
	header.add_child(timer_label)
	level_label = _pill_label("LEVEL 1", Color("#8b4b22"), Color.WHITE, 23)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(level_label)
	hearts_label = _pill_label("♥ ♥ ♥", Color("#fff2cf"), Color("#e4262e"), 28)
	hearts_label.custom_minimum_size = Vector2(120, 60)
	header.add_child(hearts_label)
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.custom_minimum_size = Vector2(60, 60)
	pause.add_theme_font_size_override("font_size", 28)
	pause.add_theme_stylebox_override("normal", _button_style(Color("#f59c18")))
	pause.pressed.connect(_toggle_pause)
	header.add_child(pause)

	var instruction := PanelContainer.new()
	instruction.custom_minimum_size.y = 135
	instruction.add_theme_stylebox_override("panel", _panel_style(Color("#8e4d22"), Color("#ffc65a"), 22))
	column.add_child(instruction)
	var instruction_box := VBoxContainer.new()
	instruction_box.alignment = BoxContainer.ALIGNMENT_CENTER
	instruction_box.add_theme_constant_override("separation", 4)
	instruction.add_child(instruction_box)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("#ffd43b"))
	instruction_box.add_child(title_label)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_box.add_child(prompt_label)

	sprite_rect = TextureRect.new()
	sprite_rect.custom_minimum_size.y = 290
	sprite_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sprite_rect)

	component_host = Control.new()
	component_host.visible = false
	component_host.custom_minimum_size.y = 320
	component_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	component_host.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(component_host)

	progress_label = _pill_label("", Color(1, 0.94, 0.78, 0.96), Color("#4d2512"), 20)
	progress_label.custom_minimum_size.y = 58
	column.add_child(progress_label)

	choices_scroll = ScrollContainer.new()
	choices_scroll.custom_minimum_size.y = 215
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(choices_scroll)
	choices_grid = GridContainer.new()
	choices_grid.columns = 3
	choices_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_grid.add_theme_constant_override("h_separation", 9)
	choices_grid.add_theme_constant_override("v_separation", 9)
	choices_scroll.add_child(choices_grid)

	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 16)
	column.add_child(tools)
	var hint := Button.new()
	hint.text = "WATCH AD FOR HINT"
	hint.custom_minimum_size = Vector2(170, 58)
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_stylebox_override("normal", _button_style(Color("#248bc7")))
	hint.pressed.connect(_use_hint)
	tools.add_child(hint)
	coins_label = _pill_label("0 COINS", Color("#fff2cf"), Color("#4d2512"), 19)
	coins_label.custom_minimum_size = Vector2(150, 58)
	tools.add_child(coins_label)

	result_panel = PanelContainer.new()
	result_panel.visible = false
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -205
	result_panel.offset_top = -220
	result_panel.offset_right = 205
	result_panel.offset_bottom = 220
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff2cf"), Color("#f2aa24"), 28))
	result_panel.z_index = 50
	add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_box)
	result_title = Label.new()
	result_title.text = "LEVEL COMPLETE!"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 32)
	result_title.add_theme_color_override("font_color", Color("#653317"))
	result_box.add_child(result_title)
	result_stars = HBoxContainer.new()
	result_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_child(result_stars)
	for index in range(3):
		var star := TextureRect.new()
		star.custom_minimum_size = Vector2(82, 82)
		star.texture = VictoryStarTexture
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		result_stars.add_child(star)
	next_button = Button.new()
	next_button.text = "NEXT LEVEL ▶"
	next_button.custom_minimum_size = Vector2(260, 64)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.add_theme_font_size_override("font_size", 22)
	next_button.add_theme_stylebox_override("normal", _button_style(Color("#35a84d")))
	next_button.pressed.connect(_next_level)
	result_box.add_child(next_button)
	var menu := Button.new()
	menu.text = "LEVEL SELECT"
	menu.custom_minimum_size = Vector2(220, 54)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(_go_menu)
	result_box.add_child(menu)

	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.timeout.connect(_tick)
	add_child(tick_timer)

func _mount_mode_component(type_id: String) -> GameModeComponent:
	if is_instance_valid(active_component):
		active_component.cancel_interactions()
		active_component.queue_free()
		active_component = null

	if not MODE_COMPONENTS.has(type_id):
		component_host.visible = false
		return null

	var comp_script: Script = MODE_COMPONENTS[type_id]
	var comp := comp_script.new() as GameModeComponent
	comp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	comp.level_completed.connect(_complete_level)
	comp.mistake_made.connect(_wrong_answer)
	component_host.add_child(comp)
	component_host.visible = true
	active_component = comp
	return comp

func _load_level(level_number: int) -> void:
	current_level = clampi(level_number, 1, 16)
	if current_level == 11 or current_level == 12:
		current_level = 13
	if current_level <= 2:
		if GameState.game_mode != "daily":
			GameState.remember_level(current_level)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/balloon_match.tscn")
		return
	if current_level == 5 or current_level == 6:
		if GameState.game_mode != "daily":
			GameState.remember_level(current_level)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/sentence_train.tscn")
		return

	var type_index := int((current_level - 1) / 2)
	var local_index := (current_level - 1) % 2
	var file := FileAccess.open(TYPE_FILES[type_index], FileAccess.READ)
	if file == null:
		push_error("Missing game type JSON: " + TYPE_FILES[type_index])
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid game type JSON: " + TYPE_FILES[type_index])
		return

	type_data = parsed
	current_type_id = str(type_data.get("type", ""))
	var levels_arr: Array = type_data.get("levels", [])
	var has_component := MODE_COMPONENTS.has(current_type_id)

	var stage_idx := clampi(GameState.type_level - 1, 0, maxi(0, levels_arr.size() - 1))
	if has_component:
		mode_stage_indices[current_type_id] = stage_idx
	level_data = levels_arr[stage_idx]

	answer_index = 0
	selected_answers.clear()
	finished = false
	result_panel.visible = false

	level_label.text = "LEVEL %d" % ((stage_idx + 1) if has_component else current_level)
	title_label.text = str(type_data["title"]).to_upper()
	prompt_label.text = str(level_data.get("prompt", ""))
	sprite_rect.texture = load(str(type_data["sprite"]))
	get_node("Background").texture = load(str(type_data["background"]))
	seconds_left = int(level_data.get("time", 60))
	timer_label.text = "%02d:%02d" % [seconds_left / 60, seconds_left % 60]
	hearts_label.text = "♥ ♥ ♥"
	coins_label.text = "%d COINS" % GameState.coins

	var comp := _mount_mode_component(current_type_id)
	component_host.custom_minimum_size.y = 320
	choices_scroll.visible = true
	if current_type_id == "number_hunt":
		component_host.custom_minimum_size.y = 470
		choices_scroll.visible = false
	elif current_type_id == "word_relay":
		component_host.custom_minimum_size.y = 400
	elif current_type_id == "number_maze":
		component_host.custom_minimum_size.y = 400
	sprite_rect.visible = (comp == null)
	progress_label.visible = (comp == null)

	var choice_count: int = level_data.get("choices", []).size()
	if comp != null:
		choices_scroll.custom_minimum_size.y = comp.get_choices_height(choice_count)
		comp.setup_level(level_data, stage_idx, choices_grid)
		var override_prompt := comp.get_prompt_override()
		if override_prompt != "":
			prompt_label.text = override_prompt
	else:
		choices_scroll.custom_minimum_size.y = 215

	_rebuild_choices()
	_update_progress()
	tick_timer.start()

func _rebuild_choices() -> void:
	for child in choices_grid.get_children():
		child.queue_free()

	if is_instance_valid(active_component) and active_component.rebuild_choices(choices_grid):
		return

	var choices: Array = level_data.get("choices", [])
	choices_grid.columns = 4 if choices.size() >= 12 else 3
	for value in choices:
		var val_str := str(value)
		var button := Button.new()
		button.text = val_str
		button.custom_minimum_size = Vector2(112, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color("#421d0c"))
		button.add_theme_color_override("font_disabled_color", Color("#421d0c"))
		button.add_theme_stylebox_override("normal", _button_style(Color("#ffe4aa")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#fff3ce")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#ffc95d")))
		button.add_theme_stylebox_override("disabled", _button_style(Color("#ffe4aa")))
		button.pressed.connect(_choose.bind(button, val_str))
		choices_grid.add_child(button)

func _choose(button: Button, value: String) -> void:
	if finished or button.disabled:
		return
	var answers: Array = level_data.get("answers", [])
	var interaction := str(type_data.get("interaction", "ordered"))
	var correct := false
	if interaction == "select_many":
		correct = value in answers and value not in selected_answers
	else:
		correct = answer_index < answers.size() and value == str(answers[answer_index])
	if correct:
		selected_answers.append(value)
		answer_index += 1
		button.disabled = true
		button.modulate = Color("#76ed83")
		AudioManager.play_place(true)
		_bounce(button)
		_update_progress()
		if selected_answers.size() >= answers.size():
			_complete_level()
	else:
		_wrong_answer(button)

func _wrong_answer(button: Button) -> void:
	AudioManager.play_place(false)
	var hearts := hearts_label.text.count("♥")
	hearts = maxi(0, hearts - 1)
	hearts_label.text = " ".join(PackedStringArray(Array(["♥", "♥", "♥"]).slice(0, hearts)))
	GameState.coins = maxi(0, GameState.coins - 1)
	GameState.save_progress()
	coins_label.text = "%d COINS" % GameState.coins
	if is_instance_valid(button):
		var tween := create_tween()
		tween.tween_property(button, "modulate", Color("#ff6b64"), 0.08)
		tween.tween_property(button, "modulate", Color.WHITE, 0.18)
	if hearts == 0:
		_finish_failed()

func _update_progress() -> void:
	if is_instance_valid(active_component):
		return
	var answers: Array = level_data.get("answers", [])
	var slots: Array[String] = []
	for index in range(answers.size()):
		slots.append(str(selected_answers[index]) if index < selected_answers.size() else "___")
	if level_data.has("goal"):
		slots.append(str(level_data["goal"]))
	progress_label.text = "  →  ".join(slots)

func _use_hint() -> void:
	if finished:
		return
	AdManager.request_rewarded_hint(Callable(self, "_grant_hint"), Callable(self, "_hint_unavailable"))

func _hint_unavailable(message: String) -> void:
	progress_label.text = message

func _grant_hint() -> void:
	if finished:
		return
	if is_instance_valid(active_component):
		if active_component.use_hint(choices_grid):
			AudioManager.play_hint()
		return

	var answers: Array = level_data.get("answers", [])
	if answer_index >= answers.size():
		return
	AudioManager.play_hint()
	var target := str(answers[answer_index])
	for button in choices_grid.get_children():
		if button is Button and button.text == target and not button.disabled:
			var tween := create_tween()
			tween.set_loops(3)
			tween.tween_property(button, "modulate", Color("#ffe242"), 0.16)
			tween.tween_property(button, "modulate", Color.WHITE, 0.16)
			break

func _tick() -> void:
	if finished:
		return
	if is_instance_valid(active_component) and active_component.is_timer_paused():
		return
	seconds_left -= 1
	timer_label.text = "%02d:%02d" % [seconds_left / 60, seconds_left % 60]
	if seconds_left <= 0:
		_finish_failed()

func _complete_level() -> void:
	finished = true
	if is_instance_valid(active_component):
		active_component.set_finished(true)
	tick_timer.stop()
	for button in choices_grid.get_children():
		button.disabled = true
	var stars := 3
	var reward := stars * 5
	var type_index := int((current_level - 1) / 2)
	GameState.register_game_type_win(type_index, int(mode_stage_indices[current_type_id]) + 1, stars, reward)
	coins_label.text = "%d COINS" % GameState.coins
	result_stars.visible = true
	for index in range(result_stars.get_child_count()):
		result_stars.get_child(index).modulate = Color.WHITE if index < stars else Color(0.2, 0.2, 0.2, 0.25)
	result_title.text = "LEVEL COMPLETE!\n+%d COINS" % reward
	next_button.text = "PLAY AGAIN ▶" if GameState.game_type_progress[type_index] > 1000 else "NEXT LEVEL ▶"
	if GameState.game_mode == "daily":
		next_button.text = "BACK TO DAILY"
	result_panel.visible = true
	result_panel.scale = Vector2(0.55, 0.55)
	result_panel.pivot_offset = result_panel.size * 0.5
	var tween := create_tween()
	tween.tween_property(result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_victory()
	RESULT_EFFECTS.celebrate(self, result_stars, stars, coins_label.global_position + coins_label.size * 0.5)
	tween.tween_interval(1.15)
	tween.tween_callback(AdManager.show_interstitial)

func _finish_failed() -> void:
	finished = true
	if is_instance_valid(active_component):
		active_component.set_finished(true)
	tick_timer.stop()
	result_title.text = "TRY AGAIN"
	result_stars.visible = false
	for star in result_stars.get_children():
		star.modulate = Color(0.2, 0.2, 0.2, 0.25)
	next_button.text = "RETRY"
	result_panel.visible = true
	AudioManager.play_level_fail()

func _next_level() -> void:
	if result_title.text.begins_with("TRY"):
		_load_level(current_level)
		return
	if GameState.game_mode == "daily":
		get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn")
		return
	GameState.type_level = GameState.next_game_type_level(int((current_level - 1) / 2))
	_load_level(current_level)

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused

func _back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn" if GameState.game_mode == "daily" else "res://scenes/game_type_select.tscn")

func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn" if GameState.game_mode == "daily" else "res://scenes/game_type_select.tscn")

func _bounce(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.14, 1.14), 0.1)
	tween.tween_property(control, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE)

func _pill_label(text_value: String, background: Color, foreground: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", foreground)
	label.add_theme_stylebox_override("normal", _panel_style(background, Color("#9b531d"), 18))
	return label

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	return style

func _button_style(background: Color) -> StyleBoxFlat:
	return _panel_style(background, Color("#9b531d"), 15)
