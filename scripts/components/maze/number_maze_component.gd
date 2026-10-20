class_name NumberMazeComponent
extends GameModeComponent

const MAP_TEXTURE = preload("res://assets/level_backgrounds/number-maze.png")
const EXPLORER_TEXTURE = preload("res://assets/gameplay_sprites/maze-explorer.png")
const PAD_POINTS := [Vector2(0.265, 0.667), Vector2(0.16, 0.40), Vector2(0.435, 0.413), Vector2(0.66, 0.41), Vector2(0.84, 0.253)]

var step_index := 0
var current_number := 0
var pad_buttons: Array[Button] = []
var bank_buttons: Array[Button] = []
var selected_button: Button
var dragging_button: Button
var drag_start := Vector2.ZERO
var is_dragging := false
var drag_preview: PanelContainer
var explorer: TextureRect
var status_label: Label
var moving := false

func get_choices_height(_choice_count: int) -> float:
	return 138.0

func _on_setup_level() -> void:
	for child in get_children():
		child.queue_free()
	step_index = 0
	current_number = int(level_data.get("start", 0))
	pad_buttons.clear()
	bank_buttons.clear()
	selected_button = null
	dragging_button = null
	moving = false
	_build_map()

func _build_map() -> void:
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _style(Color("#fff0c5"), Color("#ffd46c"), 18))
	add_child(frame)
	var map := TextureRect.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.offset_left = 5
	map.offset_top = 5
	map.offset_right = -5
	map.offset_bottom = -5
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_SCALE
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = MAP_TEXTURE
	atlas.region = Rect2(0, 400, 942, 750)
	map.texture = atlas
	frame.add_child(map)

	var stops: Array = level_data.get("steps", [])
	for index in range(stops.size() + 1):
		var pad := Button.new()
		pad.custom_minimum_size = Vector2(62, 62)
		pad.size = Vector2(62, 62)
		pad.focus_mode = Control.FOCUS_NONE
		pad.add_theme_font_size_override("font_size", 22)
		_set_dark_text(pad)
		pad.add_theme_stylebox_override("normal", _style(Color("#fff0c4"), Color("#8b542a"), 30))
		pad.add_theme_stylebox_override("hover", _style(Color("#fffbd7"), Color("#ffd04b"), 30))
		pad.add_theme_stylebox_override("disabled", _style(Color("#e9ca83"), Color("#84512b"), 30))
		pad.pressed.connect(_on_pad_pressed.bind(index))
		frame.add_child(pad)
		pad_buttons.append(pad)

	explorer = TextureRect.new()
	explorer.texture = _explorer_crop()
	explorer.size = Vector2(44, 58)
	explorer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	explorer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	explorer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	explorer.z_index = 2
	frame.add_child(explorer)
	explorer.custom_minimum_size = Vector2(44, 58)
	explorer.size = Vector2(44, 58)

	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_panel.offset_left = 8
	status_panel.offset_top = 8
	status_panel.offset_right = -8
	status_panel.offset_bottom = 39
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", _style(Color(0.16, 0.10, 0.06, 0.88), Color("#ffd267"), 10))
	frame.add_child(status_panel)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#fff1c8"))
	status_panel.add_child(status_label)
	frame.resized.connect(_layout_pads)
	_layout_pads()
	_update_pads()

func _explorer_crop() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = EXPLORER_TEXTURE
	atlas.region = Rect2(185, 0, 565, 850)
	return atlas

func _layout_pads() -> void:
	if pad_buttons.is_empty():
		return
	var board_size := size - Vector2(10, 10)
	for index in range(pad_buttons.size()):
		pad_buttons[index].position = Vector2(5, 5) + PAD_POINTS[index] * board_size - pad_buttons[index].size * 0.5
	if not moving:
		_place_explorer(step_index)

func _place_explorer(index: int) -> void:
	if not is_instance_valid(explorer):
		return
	explorer.position = pad_buttons[index].position + Vector2(-26, -56)

func _update_pads() -> void:
	var stops: Array = level_data.get("steps", [])
	for index in range(pad_buttons.size()):
		var pad := pad_buttons[index]
		if index == 0:
			pad.text = str(int(level_data.get("start", 0)))
		elif index <= step_index:
			pad.text = str(int(stops[index - 1].get("target", 0)))
		else:
			pad.text = str(int(stops[index - 1].get("target", 0)))
		pad.disabled = index != step_index + 1
		if index == step_index + 1:
			pad.add_theme_stylebox_override("normal", _style(Color("#fff2af"), Color("#ffcc37"), 30))
	if step_index < stops.size():
		var stop: Dictionary = stops[step_index]
		status_label.text = "%d %s ? = %d   •   STEP %d/%d" % [current_number, str(stop.get("op", "+")), int(stop.get("target", 0)), step_index + 1, stops.size()]

func rebuild_choices(grid: GridContainer) -> bool:
	grid.columns = 3
	bank_buttons.clear()
	var numbers: Array = level_data.get("choices", []).duplicate()
	numbers.shuffle()
	for value in numbers:
		var button := Button.new()
		button.text = str(int(value))
		button.custom_minimum_size = Vector2(100, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 23)
		_set_dark_text(button)
		button.add_theme_stylebox_override("normal", _style(Color("#ffedb8"), Color("#9b632e"), 14))
		button.add_theme_stylebox_override("hover", _style(Color("#fff8cf"), Color("#ffd056"), 14))
		button.add_theme_stylebox_override("pressed", _style(Color("#ffd975"), Color("#a56b2f"), 14))
		button.add_theme_stylebox_override("disabled", _style(Color("#bad1aa"), Color("#73936a"), 14))
		button.gui_input.connect(_on_bank_input.bind(button))
		button.pressed.connect(_select_bank.bind(button))
		grid.add_child(button)
		bank_buttons.append(button)
	return true

func _on_bank_input(event: InputEvent, button: Button) -> void:
	if is_finished or moving or button.disabled:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = button
		drag_start = button.get_global_transform_with_canvas() * event.position
		is_dragging = false

func _input(event: InputEvent) -> void:
	if dragging_button == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var pointer: Vector2 = event.position
		if not is_dragging and pointer.distance_to(drag_start) > 8.0:
			is_dragging = true
			_make_drag_preview(pointer)
		if is_dragging and is_instance_valid(drag_preview):
			drag_preview.global_position = pointer - drag_preview.size * 0.5
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag(event.position)

func _make_drag_preview(pointer: Vector2) -> void:
	drag_preview = PanelContainer.new()
	drag_preview.size = Vector2(66, 56)
	drag_preview.z_index = 70
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_theme_stylebox_override("panel", _style(Color("#fff2b3"), Color("#ffca44"), 17))
	var label := Label.new()
	label.text = dragging_button.text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("#3b210e"))
	drag_preview.add_child(label)
	add_child(drag_preview)
	drag_preview.global_position = pointer - drag_preview.size * 0.5

func _finish_drag(pointer: Vector2) -> void:
	var button := dragging_button
	var was_dragging := is_dragging
	_clear_drag()
	if is_finished or moving or not is_instance_valid(button) or button.disabled:
		return
	if was_dragging:
		var next_pad := pad_buttons[step_index + 1]
		if next_pad.get_global_rect().grow(18).has_point(pointer):
			_try_number(button)
	else:
		_select_bank(button)

func _select_bank(button: Button) -> void:
	if is_finished or moving or button.disabled:
		return
	selected_button = button
	for chip in bank_buttons:
		if not chip.disabled:
			chip.modulate = Color("#a0eea8") if chip == button else Color.WHITE
	status_label.text = "Drag %s to the glowing stone, or tap it." % button.text

func _on_pad_pressed(index: int) -> void:
	if is_finished or moving or index != step_index + 1:
		return
	if not is_instance_valid(selected_button) or selected_button.disabled:
		status_label.text = "Choose a number below, then tap this stone."
		return
	_try_number(selected_button)

func _try_number(button: Button) -> void:
	var stops: Array = level_data.get("steps", [])
	var stop: Dictionary = stops[step_index]
	var operand := int(button.text)
	var result := current_number + operand if str(stop.get("op", "+")) == "+" else current_number - operand
	if result != int(stop.get("target", 0)):
		status_label.text = "%d %s %d does not reach %d. Try another." % [current_number, str(stop.get("op", "+")), operand, int(stop.get("target", 0))]
		mistake_made.emit(pad_buttons[step_index + 1])
		return
	selected_button = null
	button.disabled = true
	button.modulate = Color(0.75, 0.90, 0.75, 0.65)
	current_number = result
	step_index += 1
	moving = true
	get_node("/root/AudioManager").play_place(true)
	_update_pads()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(explorer, "position", pad_buttons[step_index].position + Vector2(-26, -56), 0.42)
	tween.finished.connect(_after_move)

func _after_move() -> void:
	moving = false
	var stops: Array = level_data.get("steps", [])
	if step_index >= stops.size():
		status_label.text = "Treasure reached!"
		is_finished = true
		level_completed.emit()
	else:
		_update_pads()

func use_hint(_grid: GridContainer) -> bool:
	if is_finished or moving:
		return false
	var stops: Array = level_data.get("steps", [])
	var answer := str(int(stops[step_index].get("addend", 0)))
	for button in bank_buttons:
		if not button.disabled and button.text == answer:
			var tween := create_tween().set_loops(3)
			tween.tween_property(button, "modulate", Color("#ffe04a"), 0.15)
			tween.tween_property(button, "modulate", Color.WHITE, 0.15)
			return true
	return false

func _clear_drag() -> void:
	dragging_button = null
	is_dragging = false
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null

func cancel_interactions() -> void:
	_clear_drag()
	selected_button = null

func _set_dark_text(button: Button) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("#3b210e"))

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
