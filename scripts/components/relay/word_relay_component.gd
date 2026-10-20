class_name WordRelayComponent
extends GameModeComponent

var chain: Array[String] = []
var fixed_indices: Array[int] = []
var filled: Array[bool] = []
var word_slots: Array[Button] = []
var bank_buttons: Array[Button] = []
var status_label: Label

var selected_button: Button
var selected_word := ""
var dragging_button: Button
var dragging_word := ""
var drag_start := Vector2.ZERO
var is_dragging := false
var drag_preview: PanelContainer

func get_prompt_override() -> String:
	return str(level_data.get("prompt", ""))

func get_choices_height(_choice_count: int) -> float:
	return 160.0

func _on_setup_level() -> void:
	chain.clear()
	fixed_indices.clear()
	filled.clear()
	word_slots.clear()
	bank_buttons.clear()
	selected_button = null
	selected_word = ""
	for word in level_data.get("chain", []):
		chain.append(str(word))
	for index in level_data.get("fixed_indices", []):
		fixed_indices.append(int(index))
	for index in range(chain.size()):
		filled.append(index in fixed_indices)
	_build_board()

func _build_board() -> void:
	for child in get_children():
		child.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _style(Color(0.20, 0.12, 0.07, 0.88), Color("#e4ae54"), 22))
	add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "%s  →  %s" % [chain.front(), chain.back()]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("#ffdf80"))
	column.add_child(heading)
	for index in range(chain.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		column.add_child(row)
		var step := Label.new()
		step.custom_minimum_size = Vector2(43, 46)
		step.text = "%d" % (index + 1)
		step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.add_theme_font_size_override("font_size", 20)
		step.add_theme_color_override("font_color", Color("#fff1cc"))
		row.add_child(step)
		var slot := Button.new()
		slot.custom_minimum_size.y = 46
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_theme_font_size_override("font_size", 22)
		_set_button_text_color(slot)
		if filled[index]:
			slot.text = chain[index]
			slot.disabled = true
			slot.add_theme_stylebox_override("disabled", _style(Color("#e9bd72") if index == 0 else Color("#f5d68d"), Color("#9e612c"), 14))
		else:
			slot.text = "DROP WORD"
			slot.add_theme_stylebox_override("normal", _style(Color("#fff4d8"), Color("#d3a04b"), 14))
			slot.add_theme_stylebox_override("hover", _style(Color("#fffce8"), Color("#ffd159"), 14))
			slot.pressed.connect(_on_slot_pressed.bind(index))
		row.add_child(slot)
		word_slots.append(slot)
	status_label = Label.new()
	status_label.text = "Drag a word into a blank, or tap a word and a blank."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#ffedc2"))
	column.add_child(status_label)

func rebuild_choices(grid: GridContainer) -> bool:
	grid.columns = 3
	bank_buttons.clear()
	var bank: Array = level_data.get("choices", []).duplicate()
	bank.shuffle()
	for word_value in bank:
		var word := str(word_value)
		var button := Button.new()
		button.text = word
		button.custom_minimum_size = Vector2(112, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 21)
		_set_button_text_color(button)
		button.add_theme_stylebox_override("normal", _style(Color("#fff0c3"), Color("#b87b32"), 14))
		button.add_theme_stylebox_override("hover", _style(Color("#ffe18d"), Color("#b87b32"), 14))
		button.add_theme_stylebox_override("pressed", _style(Color("#ffd06f"), Color("#b87b32"), 14))
		button.add_theme_stylebox_override("disabled", _style(Color("#a6b79e"), Color("#688063"), 14))
		button.set_meta("word", word)
		button.gui_input.connect(_on_bank_gui_input.bind(button, word))
		button.pressed.connect(_select_bank.bind(button, word))
		grid.add_child(button)
		bank_buttons.append(button)
	return true

func _on_bank_gui_input(event: InputEvent, button: Button, word: String) -> void:
	if is_finished or button.disabled:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = button
		dragging_word = word
		drag_start = button.get_global_transform_with_canvas() * event.position
		is_dragging = false

func _input(event: InputEvent) -> void:
	if dragging_button == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var pointer: Vector2 = event.position
		if not is_dragging and pointer.distance_to(drag_start) > 8.0:
			is_dragging = true
			_make_preview(pointer)
		if is_dragging and is_instance_valid(drag_preview):
			drag_preview.global_position = pointer - drag_preview.size * 0.5
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_pointer(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_pointer(event.position)

func _make_preview(pointer: Vector2) -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = PanelContainer.new()
	drag_preview.size = Vector2(120, 58)
	drag_preview.z_index = 70
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_theme_stylebox_override("panel", _style(Color("#fff1be"), Color("#ffd269"), 14))
	var label := Label.new()
	label.text = dragging_word
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#48250c"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(label)
	add_child(drag_preview)
	drag_preview.global_position = pointer - drag_preview.size * 0.5

func _finish_pointer(pointer: Vector2) -> void:
	var button := dragging_button
	var word := dragging_word
	var was_dragging := is_dragging
	_clear_drag()
	if is_finished or not is_instance_valid(button) or button.disabled:
		return
	if was_dragging:
		var index := _slot_at(pointer)
		if index >= 0:
			_try_place(index, button, word)
	else:
		_select_bank(button, word)

func _slot_at(pointer: Vector2) -> int:
	for index in range(word_slots.size()):
		if not filled[index] and word_slots[index].get_global_rect().grow(14).has_point(pointer):
			return index
	return -1

func _select_bank(button: Button, word: String) -> void:
	if is_finished or button.disabled:
		return
	selected_button = button
	selected_word = word
	for bank_button in bank_buttons:
		if is_instance_valid(bank_button) and not bank_button.disabled:
			bank_button.modulate = Color("#86e4b2") if bank_button == button else Color.WHITE
	status_label.text = "Now tap a blank for %s." % word

func _on_slot_pressed(index: int) -> void:
	if is_finished or filled[index]:
		return
	if not is_instance_valid(selected_button) or selected_button.disabled:
		status_label.text = "Choose a word below, then tap this blank."
		return
	_try_place(index, selected_button, selected_word)

func _try_place(index: int, button: Button, word: String) -> void:
	if is_finished or filled[index] or button.disabled:
		return
	if word != chain[index]:
		status_label.text = "Check both neighboring words. Only one letter may change."
		mistake_made.emit(word_slots[index])
		return
	filled[index] = true
	word_slots[index].text = word
	word_slots[index].disabled = true
	word_slots[index].add_theme_stylebox_override("disabled", _style(Color("#b6e7ac"), Color("#5a9b5a"), 14))
	button.disabled = true
	button.modulate = Color(1, 1, 1, 0.4)
	selected_button = null
	selected_word = ""
	for bank_button in bank_buttons:
		if is_instance_valid(bank_button) and not bank_button.disabled:
			bank_button.modulate = Color.WHITE
	AudioManager.play_place(true)
	status_label.text = "Good link! Keep the relay going."
	var tween := create_tween()
	word_slots[index].pivot_offset = word_slots[index].size * 0.5
	tween.tween_property(word_slots[index], "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(word_slots[index], "scale", Vector2.ONE, 0.14)
	if _all_filled():
		is_finished = true
		level_completed.emit()

func _all_filled() -> bool:
	for value in filled:
		if not value:
			return false
	return true

func use_hint(_grid: GridContainer) -> bool:
	if is_finished:
		return false
	for index in range(filled.size()):
		if filled[index]:
			continue
		for bank_button in bank_buttons:
			if is_instance_valid(bank_button) and not bank_button.disabled and str(bank_button.get_meta("word", "")) == chain[index]:
				var tween := create_tween().set_loops(3)
				tween.tween_property(word_slots[index], "modulate", Color("#ffdc50"), 0.16)
				tween.tween_property(word_slots[index], "modulate", Color.WHITE, 0.16)
				var bank_tween := create_tween().set_loops(3)
				bank_tween.tween_property(bank_button, "modulate", Color("#ffdc50"), 0.16)
				bank_tween.tween_property(bank_button, "modulate", Color.WHITE, 0.16)
				return true
	return false

func _clear_drag() -> void:
	dragging_button = null
	dragging_word = ""
	is_dragging = false
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null

func cancel_interactions() -> void:
	_clear_drag()
	selected_button = null
	selected_word = ""

func _set_button_text_color(button: Button) -> void:
	var ink := Color("#3b210e")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
