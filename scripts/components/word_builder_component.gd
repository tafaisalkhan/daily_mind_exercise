class_name WordBuilderComponent
extends GameModeComponent

## Players inspect the displayed word, select a gap or wrong letter, then fix it.

var word_slots: Array[String] = []
var target_word: Array[String] = []
var mode: String = ""
var selected_slot: int = -1
var word_buttons: Array[Button] = []
var status_label: Label

func _on_setup_level() -> void:
	mode = str(level_data.get("mode", "missing"))
	word_slots.clear()
	target_word.clear()
	word_buttons.clear()
	selected_slot = -1
	for value in level_data.get("word_slots", []):
		word_slots.append(str(value))
	for value in level_data.get("target_word", []):
		target_word.append(str(value))
	_build_word_display()

func _build_word_display() -> void:
	for child in get_children():
		child.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#fff7df")
	panel_style.border_color = Color("#e7ac3c")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)
	var category := Label.new()
	category.text = str(level_data.get("category", "WORD CHECK"))
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category.add_theme_font_size_override("font_size", 25)
	category.add_theme_color_override("font_color", Color("#83501d"))
	layout.add_child(category)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	layout.add_child(row)
	for index in range(word_slots.size()):
		var tile := Button.new()
		tile.text = word_slots[index]
		tile.custom_minimum_size = Vector2(48, 66)
		tile.add_theme_font_size_override("font_size", 29)
		tile.add_theme_color_override("font_color", Color("#4d3019"))
		tile.add_theme_stylebox_override("normal", _tile_style(index, false))
		tile.add_theme_stylebox_override("hover", _tile_style(index, true))
		tile.pressed.connect(_on_word_tile_pressed.bind(index, tile))
		row.add_child(tile)
		word_buttons.append(tile)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.add_theme_color_override("font_color", Color("#70461c"))
	status_label.text = str(level_data.get("instruction", level_data.get("prompt", "")))
	layout.add_child(status_label)

func _tile_style(index: int, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var is_gap := word_slots[index] == "_"
	style.bg_color = Color("#ffe091") if is_gap else Color("#ffffff")
	if hovered:
		style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = Color("#e6a62b") if is_gap else Color("#b9c5a4")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style

func _on_word_tile_pressed(index: int, tile: Button) -> void:
	if is_finished:
		return
	if mode == "already_ok":
		_finish_word()
		return
	if mode == "remove_char":
		if index == int(level_data.get("remove_index", -1)):
			word_slots.remove_at(index)
			tile.hide()
			_finish_word()
		else:
			mistake_made.emit(tile)
		return
	var valid_slot := index < target_word.size() and word_slots[index] != target_word[index]
	if mode == "missing":
		valid_slot = valid_slot and word_slots[index] == "_"
	if not valid_slot:
		mistake_made.emit(tile)
		return
	selected_slot = index
	for word_button in word_buttons:
		word_button.modulate = Color.WHITE
	tile.modulate = Color("#7adfd0")
	status_label.text = "Choose the correct letter below."
	_update_choice_buttons()

func rebuild_choices(grid: GridContainer) -> bool:
	grid.columns = 3
	if mode == "remove_char":
		return true
	if mode == "already_ok":
		_add_choice(grid, "WORD IS OK")
		return true
	for value in level_data.get("choices", []):
		var letter := str(value)
		if letter.length() == 1:
			_add_choice(grid, letter)
	_update_choice_buttons()
	return true

func _add_choice(grid: GridContainer, value: String) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(112, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("#421d0c"))
	button.add_theme_color_override("font_hover_color", Color("#321709"))
	button.add_theme_color_override("font_pressed_color", Color("#321709"))
	button.add_theme_color_override("font_disabled_color", Color("#421d0c"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ffe4aa")
	style.border_color = Color("#d4902b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(13)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.pressed.connect(_on_choice_pressed.bind(value, button))
	grid.add_child(button)

func _update_choice_buttons() -> void:
	if not is_instance_valid(choices_grid):
		return
	for button in choices_grid.get_children():
		if button is Button:
			button.disabled = is_finished or (mode != "already_ok" and selected_slot < 0)

func _on_choice_pressed(value: String, button: Button) -> void:
	if is_finished:
		return
	if mode == "already_ok":
		_finish_word()
		return
	if selected_slot < 0:
		return
	if selected_slot >= target_word.size() or value != target_word[selected_slot]:
		mistake_made.emit(button)
		return
	word_slots[selected_slot] = value
	word_buttons[selected_slot].text = value
	word_buttons[selected_slot].modulate = Color("#77d995")
	selected_slot = -1
	_update_choice_buttons()
	if word_slots == target_word:
		_finish_word()
	else:
		status_label.text = "Good! Tap the next blank."

func _finish_word() -> void:
	if word_slots != target_word:
		return
	is_finished = true
	status_label.text = "Correct: %s" % "".join(PackedStringArray(word_slots))
	_update_choice_buttons()
	level_completed.emit()

func use_hint(_grid: GridContainer) -> bool:
	if is_finished:
		return false
	if mode == "already_ok":
		_finish_word()
		return true
	if mode == "remove_char":
		var remove_index := int(level_data.get("remove_index", -1))
		if remove_index < 0 or remove_index >= word_buttons.size():
			return false
		_on_word_tile_pressed(remove_index, word_buttons[remove_index])
		return true
	for index in range(mini(word_slots.size(), target_word.size())):
		if word_slots[index] != target_word[index]:
			word_slots[index] = target_word[index]
			word_buttons[index].text = target_word[index]
			word_buttons[index].modulate = Color("#77d995")
			selected_slot = -1
			_update_choice_buttons()
			status_label.text = "Hint placed: %s" % target_word[index]
			if word_slots == target_word:
				_finish_word()
			return true
	return false

func get_choices_height(_choice_count: int) -> float:
	return 140.0
