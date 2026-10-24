class_name NumberHuntComponent
extends GameModeComponent

const ORB_SHEET := preload("res://assets/gameplay_sprites/number-orbs.png")
const ORB_SIZE := 86.0

var rng := RandomNumberGenerator.new()
var target_number := 0
var catches := 0
var catch_goal := 5
var orb_count := 6
var drift := 12.0
var busy := false
var difficulty_tier := 0
var questions: Array = []
var question_order: Array[int] = []
var orbs: Array[Button] = []
var target_orb: Button

var target_label: Label
var progress_label: Label
var field: Control

func _ready() -> void:
	custom_minimum_size.y = 470
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	rng.randomize()
	_build_hunt_ui()
	field.resized.connect(_layout_orbs)

func get_prompt_override() -> String:
	return str(level_data.get("prompt", ""))

func rebuild_choices(_grid: GridContainer) -> bool:
	return true

func _on_setup_level() -> void:
	catch_goal = maxi(1, int(level_data.get("catches", 5)))
	orb_count = clampi(int(level_data.get("orb_count", 6)), 4, 9)
	drift = float(level_data.get("drift", 12))
	difficulty_tier = int(level_data.get("tier", 0 if stage_index == 0 else 1))
	questions = level_data.get("questions", [])
	question_order.clear()
	for index in range(questions.size()):
		question_order.append(index)
	question_order.shuffle()
	catch_goal = mini(catch_goal, questions.size())
	catches = 0
	busy = false
	_update_progress()
	call_deferred("_spawn_wave")

func _build_hunt_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)

	var dashboard := PanelContainer.new()
	dashboard.custom_minimum_size.y = 90
	dashboard.add_theme_stylebox_override("panel", _panel(Color(0.10, 0.28, 0.17, 0.88), Color("#eccc65"), 19))
	layout.add_child(dashboard)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	dashboard.add_child(bar)
	var hunt_label := Label.new()
	hunt_label.text = "HUNT"
	hunt_label.add_theme_font_size_override("font_size", 19)
	hunt_label.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(hunt_label)
	target_label = Label.new()
	target_label.custom_minimum_size = Vector2(220, 68)
	target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_label.add_theme_font_size_override("font_size", 22)
	target_label.add_theme_color_override("font_color", Color("#542604"))
	target_label.add_theme_stylebox_override("normal", _panel(Color("#ffdd62"), Color("#fff3bd"), 16))
	bar.add_child(target_label)
	progress_label = Label.new()
	progress_label.custom_minimum_size.x = 90
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override("font_color", Color("#fff3bc"))
	bar.add_child(progress_label)

	var field_panel := PanelContainer.new()
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_panel.add_theme_stylebox_override("panel", _panel(Color(0.02, 0.25, 0.13, 0.48), Color(1, 0.94, 0.59, 0.78), 25))
	layout.add_child(field_panel)
	field = Control.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.mouse_filter = Control.MOUSE_FILTER_PASS
	field.clip_contents = true
	field_panel.add_child(field)

func _panel(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _spawn_wave() -> void:
	if is_finished or not is_inside_tree():
		return
	if questions.is_empty() or catches >= question_order.size():
		push_error("Number Hunter level has no questions in JSON.")
		return
	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	orbs.clear()
	target_orb = null
	var question: Dictionary = questions[question_order[catches]]
	target_number = int(question.get("answer", 0))
	var values: Array = question.get("numbers", [])
	target_label.text = str(question.get("clue", ""))
	var slots: Array[int] = []
	for index in range(values.size()):
		slots.append(index)
	slots.shuffle()
	for index in range(values.size()):
		var orb := _make_orb(int(values[index]), rng.randi_range(0, 5))
		orb.set_meta("slot", slots[index])
		field.add_child(orb)
		orbs.append(orb)
		if values[index] == target_number:
			target_orb = orb
	_layout_orbs()
	busy = false

func _make_orb(value: int, fruit_index: int) -> Button:
	var orb := Button.new()
	orb.custom_minimum_size = Vector2(ORB_SIZE, ORB_SIZE)
	orb.size = Vector2(ORB_SIZE, ORB_SIZE)
	orb.pivot_offset = Vector2(ORB_SIZE, ORB_SIZE) * 0.5
	orb.focus_mode = Control.FOCUS_NONE
	orb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	orb.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	orb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	orb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	orb.pressed.connect(_on_orb_pressed.bind(orb, value))

	var texture := AtlasTexture.new()
	texture.atlas = ORB_SHEET
	texture.region = Rect2((fruit_index % 3) * 512, int(fruit_index / 3) * 512, 512, 512)
	var fruit := TextureRect.new()
	fruit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fruit.texture = texture
	fruit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fruit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fruit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(fruit)

	var number := Label.new()
	number.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	number.offset_left = -31
	number.offset_top = -15
	number.offset_right = 31
	number.offset_bottom = 20
	number.text = str(value)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 29)
	number.add_theme_color_override("font_color", Color("#3b1c0c"))
	number.add_theme_color_override("font_shadow_color", Color.WHITE)
	number.add_theme_constant_override("shadow_offset_x", 1)
	number.add_theme_constant_override("shadow_offset_y", 2)
	number.add_theme_stylebox_override("normal", _panel(Color(1, 0.97, 0.84, 0.92), Color(0.35, 0.20, 0.08, 0.5), 14))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(number)
	return orb

func _layout_orbs() -> void:
	if field == null or field.size.x < ORB_SIZE or field.size.y < ORB_SIZE:
		return
	var rows := 2 if orb_count <= 6 else 3
	var columns := 3
	var free_width := maxf(0.0, field.size.x - ORB_SIZE - 16)
	var free_height := maxf(0.0, field.size.y - ORB_SIZE - 16)
	for orb in orbs:
		if not is_instance_valid(orb):
			continue
		var slot := int(orb.get_meta("slot"))
		var column := slot % columns
		var row := int(slot / columns)
		var x := 8.0 + free_width * float(column) / float(columns - 1)
		var y := 8.0 + free_height * float(row) / float(rows - 1)
		var base := Vector2(x, y)
		orb.position = base
		orb.set_meta("home", base)
		_start_roam(orb, base)

func _start_roam(orb: Button, base: Vector2) -> void:
	if orb.has_meta("roam_tween"):
		var old_tween: Tween = orb.get_meta("roam_tween")
		if old_tween.is_valid():
			old_tween.kill()
	var slot := int(orb.get_meta("slot"))
	var side := -1.0 if slot % 2 == 0 else 1.0
	var center_waypoint := Vector2(
		(field.size.x - ORB_SIZE) * 0.5,
		(field.size.y - ORB_SIZE) * 0.5
	)
	var outside := Vector2(-ORB_SIZE - 12.0 if side < 0.0 else field.size.x + 12.0, center_waypoint.y)
	var speed := 105.0 + drift * 6.0
	var center_time := maxf(0.6, base.distance_to(center_waypoint) / speed)
	var edge_time := maxf(0.8, center_waypoint.distance_to(outside) / speed)
	orb.set_meta("center_waypoint", center_waypoint)
	var tween := orb.create_tween().set_loops()
	tween.tween_interval(0.15 + float(slot) * 0.28 + rng.randf_range(0.0, 0.3))
	tween.tween_property(orb, "position", center_waypoint, center_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.22)
	tween.tween_property(orb, "position", outside, edge_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(0.35 if difficulty_tier == 0 else 0.25)
	tween.tween_property(orb, "position", center_waypoint, edge_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(0.18)
	tween.tween_property(orb, "position", base, center_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	orb.set_meta("roam_tween", tween)

func _on_orb_pressed(orb: Button, value: int) -> void:
	if is_finished or busy:
		return
	if value != target_number:
		mistake_made.emit(orb)
		return
	busy = true
	AudioManager.play_place(true)
	catches += 1
	target_label.text = "Found %d!" % value
	_update_progress()
	for other in orbs:
		other.disabled = true
	var tween := target_orb.create_tween()
	tween.set_parallel(true)
	tween.tween_property(orb, "scale", Vector2(1.35, 1.35), 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(orb, "modulate:a", 0.0, 0.35)
	await tween.finished
	if not is_inside_tree() or is_finished:
		return
	if catches >= catch_goal:
		is_finished = true
		level_completed.emit()
	else:
		_spawn_wave()

func _update_progress() -> void:
	if progress_label != null:
		progress_label.text = "%d / %d caught" % [catches, catch_goal]

func can_use_hint() -> bool:
	return not is_finished and not busy and is_instance_valid(target_orb)

func use_hint(_grid: GridContainer) -> bool:
	if is_finished or busy or not is_instance_valid(target_orb):
		return false
	_on_orb_pressed(target_orb, target_number)
	return true

func cancel_interactions() -> void:
	busy = true
	for orb in orbs:
		if is_instance_valid(orb):
			orb.disabled = true
			if orb.has_meta("roam_tween"):
				var tween: Tween = orb.get_meta("roam_tween")
				if tween.is_valid():
					tween.kill()
