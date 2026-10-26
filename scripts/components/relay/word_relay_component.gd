class_name WordRelayComponent
extends GameModeComponent

const RELAY_SPRITE := preload("res://assets/gameplay_sprites/word-relay.png")
const OWL_REGION := Rect2(12, 185, 483, 1175)
const TOP_BOARD_REGION := Rect2(495, 122, 517, 260)
const MID_BOARD_REGION := Rect2(495, 382, 517, 246)
const BOT_BOARD_REGION := Rect2(495, 1134, 517, 262)

var chain: Array[String] = []
var fixed_indices: Array[int] = []
var filled: Array[bool] = []
var word_slots: Array[Button] = []
var slot_letter_boxes: Array = []
var bank_buttons: Array[Button] = []
var status_label: Label
var owl_hint_button: Button
var hovered_slot: int = -1

var selected_button: Button
var selected_word := ""
var dragging_button: Button
var dragging_word := ""
var drag_start := Vector2.ZERO
var is_dragging := false
var _suppress_next_press := false
var drag_preview: PanelContainer

func get_prompt_override() -> String:
	return str(level_data.get("prompt", ""))

func get_choices_height(_choice_count: int) -> float:
	return 144.0

func _on_setup_level() -> void:
	_clear_drag()
	chain.clear()
	fixed_indices.clear()
	filled.clear()
	word_slots.clear()
	slot_letter_boxes.clear()
	bank_buttons.clear()
	selected_button = null
	selected_word = ""
	hovered_slot = -1
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

	var root_column := VBoxContainer.new()
	root_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_column.add_theme_constant_override("separation", 4)
	add_child(root_column)

	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	root_column.add_child(stage)

	# Owl Professor on the left
	var owl_holder := Control.new()
	owl_holder.anchor_left = 0.0
	owl_holder.anchor_right = 0.36
	owl_holder.anchor_top = 0.04
	owl_holder.anchor_bottom = 0.98
	owl_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(owl_holder)

	var owl_tex := TextureRect.new()
	owl_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owl_tex.offset_top = 34
	owl_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owl_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owl_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owl_atlas := AtlasTexture.new()
	owl_atlas.atlas = RELAY_SPRITE
	owl_atlas.region = OWL_REGION
	owl_tex.texture = owl_atlas
	owl_holder.add_child(owl_tex)

	# Lightbulb Hint Bubble above the Owl (matching level8_word_relay mock)
	owl_hint_button = Button.new()
	owl_hint_button.text = "💡"
	owl_hint_button.tooltip_text = "Use Hint"
	owl_hint_button.custom_minimum_size = Vector2(54, 54)
	owl_hint_button.size = Vector2(54, 54)
	owl_hint_button.anchor_left = 0.56
	owl_hint_button.anchor_right = 0.56
	owl_hint_button.anchor_top = 0.0
	owl_hint_button.anchor_bottom = 0.0
	owl_hint_button.offset_left = -27
	owl_hint_button.offset_right = 27
	owl_hint_button.offset_top = 2
	owl_hint_button.offset_bottom = 56
	owl_hint_button.focus_mode = Control.FOCUS_NONE
	owl_hint_button.add_theme_font_size_override("font_size", 26)
	var bubble_normal := _style(Color("#fffdf5"), Color("#c9964c"), 27)
	bubble_normal.shadow_color = Color(0, 0, 0, 0.28)
	bubble_normal.shadow_size = 5
	bubble_normal.shadow_offset = Vector2(0, 3)
	var bubble_hover := _style(Color("#fff5c0"), Color("#f2a922"), 27)
	owl_hint_button.add_theme_stylebox_override("normal", bubble_normal)
	owl_hint_button.add_theme_stylebox_override("hover", bubble_hover)
	owl_hint_button.add_theme_stylebox_override("pressed", bubble_hover)
	owl_hint_button.pressed.connect(_on_owl_hint_pressed)
	owl_holder.add_child(owl_hint_button)

	# Hanging wooden signboards column on the right
	var boards_column := VBoxContainer.new()
	boards_column.anchor_left = 0.31
	boards_column.anchor_right = 0.995
	boards_column.anchor_top = 0.0
	boards_column.anchor_bottom = 1.0
	boards_column.alignment = BoxContainer.ALIGNMENT_CENTER
	boards_column.add_theme_constant_override("separation", -5)
	boards_column.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(boards_column)

	for index in range(chain.size()):
		var is_first := (index == 0)
		var is_last := (index == chain.size() - 1)

		var slot := Button.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = 54 if chain.size() >= 6 else (66 if chain.size() == 5 else 78)
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = true
		slot.text = chain[index] if filled[index] else ""
		_set_transparent_button_font(slot)

		var empty_style := StyleBoxEmpty.new()
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			slot.add_theme_stylebox_override(state_name, empty_style)

		var board_tex := TextureRect.new()
		board_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		board_tex.stretch_mode = TextureRect.STRETCH_SCALE
		board_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var board_atlas := AtlasTexture.new()
		board_atlas.atlas = RELAY_SPRITE
		if is_first:
			board_atlas.region = TOP_BOARD_REGION
		elif is_last:
			board_atlas.region = BOT_BOARD_REGION
		else:
			board_atlas.region = MID_BOARD_REGION
		board_tex.texture = board_atlas
		slot.add_child(board_tex)

		var face := Control.new()
		face.anchor_left = 0.11
		face.anchor_right = 0.89
		face.anchor_top = 0.25 if is_first else 0.21
		face.anchor_bottom = 0.85
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_tex.add_child(face)

		var boxes_for_slot: Array[Label] = []
		if is_first or is_last:
			var endpoint_label := Label.new()
			endpoint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			endpoint_label.text = chain[index]
			endpoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			endpoint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			endpoint_label.add_theme_font_size_override("font_size", 26 if chain.size() <= 5 else 23)
			if is_first:
				endpoint_label.add_theme_color_override("font_color", Color("#0b2c56"))
				endpoint_label.add_theme_color_override("font_outline_color", Color("#e6f7ff"))
			else:
				endpoint_label.add_theme_color_override("font_color", Color("#8c2208"))
				endpoint_label.add_theme_color_override("font_outline_color", Color("#fff0a6"))
			endpoint_label.add_theme_constant_override("outline_size", 5)
			endpoint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.add_child(endpoint_label)
			slot.disabled = true
		else:
			var tiles_row := HBoxContainer.new()
			tiles_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tiles_row.alignment = BoxContainer.ALIGNMENT_CENTER
			tiles_row.add_theme_constant_override("separation", 6)
			tiles_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.add_child(tiles_row)

			var word_len := maxi(3, chain[index].length())
			var tile_w := 42.0 if word_len <= 4 else 35.0
			var tile_h := 38.0 if chain.size() <= 5 else 32.0
			for char_i in range(word_len):
				var letter_lbl := Label.new()
				letter_lbl.custom_minimum_size = Vector2(tile_w, tile_h)
				letter_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				letter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				letter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				letter_lbl.add_theme_font_size_override("font_size", 21 if chain.size() <= 5 else 18)
				letter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tiles_row.add_child(letter_lbl)
				boxes_for_slot.append(letter_lbl)

			if filled[index]:
				slot.disabled = true
			else:
				slot.pressed.connect(_on_slot_pressed.bind(index))

		slot_letter_boxes.append(boxes_for_slot)
		boards_column.add_child(slot)
		word_slots.append(slot)
		_refresh_slot_visuals(index)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size.y = 34
	var status_style := _style(Color(0.22, 0.12, 0.06, 0.86), Color("#e4ae54"), 14)
	status_style.content_margin_top = 3
	status_style.content_margin_bottom = 3
	status_panel.add_theme_stylebox_override("panel", status_style)
	root_column.add_child(status_panel)

	status_label = Label.new()
	status_label.text = "Drag a word to a wooden board, or tap a word then tap a board."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#fff0c7"))
	status_panel.add_child(status_label)

func _refresh_slot_visuals(index: int) -> void:
	if index < 0 or index >= slot_letter_boxes.size():
		return
	var boxes: Array = slot_letter_boxes[index]
	if boxes.is_empty():
		return
	var word := chain[index]
	var prev_word := chain[index - 1] if (index > 0 and filled[index - 1]) else ""
	var is_fixed_clue := index in fixed_indices
	var is_solved := filled[index]
	var is_ready_target := not is_solved and (hovered_slot == index or (is_instance_valid(selected_button) and not selected_button.disabled))

	for char_i in range(boxes.size()):
		var lbl: Label = boxes[char_i]
		if not is_instance_valid(lbl):
			continue
		var ch := word.substr(char_i, 1) if (is_solved and char_i < word.length()) else ""
		lbl.text = ch
		lbl.add_theme_color_override("font_color", Color("#331806"))
		var box_style := StyleBoxFlat.new()
		box_style.set_corner_radius_all(8)
		box_style.set_border_width_all(2)
		box_style.border_width_bottom = 4
		if is_solved:
			var changed_char := prev_word != "" and char_i < prev_word.length() and prev_word.substr(char_i, 1) != ch
			if is_fixed_clue:
				box_style.bg_color = Color("#ffe59e")
				box_style.border_color = Color("#a86420")
			elif changed_char:
				box_style.bg_color = Color("#ffe97d")
				box_style.border_color = Color("#b87914")
			else:
				box_style.bg_color = Color("#d5f5b0")
				box_style.border_color = Color("#4d9430")
		elif hovered_slot == index:
			box_style.bg_color = Color("#fff4a8")
			box_style.border_color = Color("#f5a600")
		elif is_ready_target:
			box_style.bg_color = Color("#fff2cc")
			box_style.border_color = Color("#e09b2d")
		else:
			box_style.bg_color = Color("#f6e5c0")
			box_style.border_color = Color("#b57d3d")
		lbl.add_theme_stylebox_override("normal", box_style)

func _refresh_all_slots() -> void:
	for index in range(chain.size()):
		_refresh_slot_visuals(index)

func _on_owl_hint_pressed() -> void:
	if is_finished:
		return
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene.has_method("_use_hint"):
		scene.call("_use_hint")
	else:
		use_hint(choices_grid)

func rebuild_choices(grid: GridContainer) -> bool:
	grid.columns = 3
	bank_buttons.clear()
	var bank: Array = level_data.get("choices", []).duplicate()
	bank.shuffle()
	for word_value in bank:
		var word := str(word_value)
		var button := Button.new()
		button.text = word
		button.custom_minimum_size = Vector2(112, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 22)
		_set_button_text_color(button)
		button.add_theme_stylebox_override("normal", _wood_tile_style(Color("#f7dca0"), Color("#874d1b")))
		button.add_theme_stylebox_override("hover", _wood_tile_style(Color("#ffe9b5"), Color("#9e5c22")))
		button.add_theme_stylebox_override("pressed", _wood_tile_style(Color("#ffd278"), Color("#784114")))
		button.add_theme_stylebox_override("disabled", _wood_tile_style(Color("#b6c2ad"), Color("#6d7d66")))
		button.set_meta("word", word)
		button.gui_input.connect(_on_bank_gui_input.bind(button, word))
		button.pressed.connect(_on_bank_pressed.bind(button, word))
		grid.add_child(button)
		bank_buttons.append(button)
	return true

func _on_bank_pressed(button: Button, word: String) -> void:
	if _suppress_next_press:
		_suppress_next_press = false
		return
	_select_bank(button, word)

func _on_bank_gui_input(event: InputEvent, button: Button, word: String) -> void:
	if is_finished or button.disabled:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = button
		dragging_word = word
		drag_start = button.get_global_transform_with_canvas() * event.position
		is_dragging = false
		_suppress_next_press = false

func _input(event: InputEvent) -> void:
	if dragging_button == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var pointer: Vector2 = event.position
		if not is_dragging and pointer.distance_to(drag_start) > 8.0:
			is_dragging = true
			_suppress_next_press = true
			_make_preview(pointer)
		if is_dragging:
			if is_instance_valid(drag_preview):
				drag_preview.global_position = pointer - drag_preview.size * 0.5
			var new_hover := _slot_at(pointer)
			if new_hover != hovered_slot:
				hovered_slot = new_hover
				_refresh_all_slots()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_pointer(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_pointer(event.position)

func _make_preview(pointer: Vector2) -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = PanelContainer.new()
	drag_preview.size = Vector2(124, 58)
	drag_preview.z_index = 70
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_theme_stylebox_override("panel", _wood_tile_style(Color("#fff1be"), Color("#d4882a")))
	var label := Label.new()
	label.text = dragging_word
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#3b1d09"))
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
		_suppress_next_press = true
		_select_bank(button, word)

func _slot_at(pointer: Vector2) -> int:
	for index in range(word_slots.size()):
		if not filled[index] and word_slots[index].get_global_rect().grow(12).has_point(pointer):
			return index
	return -1

func _select_bank(button: Button, word: String) -> void:
	if is_finished or button.disabled:
		return
	selected_button = button
	selected_word = word
	for bank_button in bank_buttons:
		if is_instance_valid(bank_button) and not bank_button.disabled:
			bank_button.modulate = Color("#8ef0a8") if bank_button == button else Color.WHITE
	_refresh_all_slots()
	status_label.text = "Now tap a blank wooden board for %s." % word

func _on_slot_pressed(index: int) -> void:
	if is_finished or filled[index]:
		return
	if not is_instance_valid(selected_button) or selected_button.disabled:
		status_label.text = "Choose a word below, then tap this wooden board."
		return
	_try_place(index, selected_button, selected_word)

func _try_place(index: int, button: Button, word: String, play_sound: bool = true) -> void:
	if is_finished or index < 0 or index >= filled.size() or filled[index]:
		return
	if is_instance_valid(button) and button.disabled:
		return
	if word != chain[index]:
		status_label.text = "Check both neighboring words. Only one letter may change."
		mistake_made.emit(word_slots[index])
		return
	filled[index] = true
	word_slots[index].text = word
	word_slots[index].disabled = true
	if is_instance_valid(button):
		button.disabled = true
		button.modulate = Color(1, 1, 1, 0.42)
	selected_button = null
	selected_word = ""
	hovered_slot = -1
	for bank_button in bank_buttons:
		if is_instance_valid(bank_button) and not bank_button.disabled:
			bank_button.modulate = Color.WHITE
	_refresh_all_slots()
	if play_sound:
		AudioManager.play_place(true)
	status_label.text = "Hint placed: %s." % word if not play_sound else "Good link! Keep the relay going."
	var tween := create_tween()
	word_slots[index].pivot_offset = word_slots[index].size * 0.5
	tween.tween_property(word_slots[index], "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(word_slots[index], "scale", Vector2.ONE, 0.14)
	if _all_filled():
		is_finished = true
		level_completed.emit()

func _all_filled() -> bool:
	for value in filled:
		if not value:
			return false
	return true

func can_use_hint() -> bool:
	return not is_finished and not _all_filled()

func use_hint(_grid: GridContainer) -> bool:
	if is_finished:
		return false
	_clear_drag()
	selected_button = null
	selected_word = ""
	for index in range(filled.size()):
		if filled[index]:
			continue
		var target_word := chain[index]
		var matched_button: Button = null
		for bank_button in bank_buttons:
			if is_instance_valid(bank_button) and not bank_button.disabled and (str(bank_button.get_meta("word", "")) == target_word or bank_button.text == target_word):
				matched_button = bank_button
				break
		if matched_button == null and is_instance_valid(_grid):
			for child in _grid.get_children():
				if child is Button and not child.disabled and (str(child.get_meta("word", "")) == target_word or child.text == target_word):
					matched_button = child
					break
		_try_place(index, matched_button, target_word, false)
		return true
	return false

func show_hint_message(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message

func _clear_drag() -> void:
	dragging_button = null
	dragging_word = ""
	is_dragging = false
	hovered_slot = -1
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null

func cancel_interactions() -> void:
	_clear_drag()
	selected_button = null
	selected_word = ""

func _set_transparent_button_font(button: Button) -> void:
	var clear := Color(0, 0, 0, 0)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state_name, clear)

func _set_button_text_color(button: Button) -> void:
	var ink := Color("#351a07")
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state_name, ink)

func _wood_tile_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.border_width_bottom = 6
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

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
