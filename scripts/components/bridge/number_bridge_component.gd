class_name NumberBridgeComponent
extends GameModeComponent

## Self-contained Number Bridge component.
## Manages N-step rope bridge rendering, missing plank gaps, cartoon animal walkers,
## step drag-and-drop, hint fulfillment, and bridge-crossing completion animation.

const BridgeTexture = preload("res://assets/gameplay_sprites/number-bridge.png")
const BRIDGE_TEX_SIZE := Vector2(1774.0, 887.0)

const BRIDGE_LEFT_POST := Rect2(0, 0, 265, 887)
const BRIDGE_RIGHT_POST := Rect2(1510, 0, 264, 887)
const BRIDGE_UPPER_ROPES := [
	Rect2(265, 0, 203, 412),
	Rect2(484, 0, 191, 430),
	Rect2(697, 0, 176, 442),
	Rect2(897, 0, 180, 440),
	Rect2(1095, 0, 198, 426),
	Rect2(1307, 0, 203, 402)
]
const BRIDGE_KNOT_STRIPS := [
	Rect2(468, 0, 16, 640),
	Rect2(675, 0, 22, 640),
	Rect2(873, 0, 24, 640),
	Rect2(1077, 0, 18, 640),
	Rect2(1293, 0, 14, 640)
]
const BRIDGE_PLANK_REGIONS := [
	Rect2(265, 412, 203, 228),
	Rect2(484, 430, 191, 210),
	Rect2(697, 442, 176, 200),
	Rect2(897, 440, 180, 200),
	Rect2(1095, 426, 198, 200),
	Rect2(1307, 402, 203, 228)
]
const BRIDGE_STEP_FACE_RECTS := [
	Rect2(282, 430, 170, 152),
	Rect2(496, 446, 164, 155),
	Rect2(706, 456, 156, 156),
	Rect2(906, 454, 160, 156),
	Rect2(1108, 442, 168, 154),
	Rect2(1322, 420, 170, 148)
]

class BridgeMissingSlot extends Control:
	var is_hovered: bool = false:
		set(value):
			if is_hovered != value:
				is_hovered = value
				queue_redraw()
	var is_error: bool = false:
		set(value):
			if is_error != value:
				is_error = value
				queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-2.0)
		var fill_col := Color(0.99, 0.92, 0.74, 0.32)
		var dash_col := Color("#ffe28a")
		if is_error:
			fill_col = Color(0.95, 0.25, 0.2, 0.55)
			dash_col = Color("#ff6b64")
		elif is_hovered:
			fill_col = Color(1.0, 0.95, 0.68, 0.62)
			dash_col = Color("#ffd83b")

		draw_rect(r, fill_col, true)

		var corners := [
			r.position,
			Vector2(r.end.x, r.position.y),
			r.end,
			Vector2(r.position.x, r.end.y)
		]
		var dash_len := 8.0
		var gap_len := 5.0
		var thickness := 3.5 if is_hovered else 2.5
		for edge_i in range(4):
			var p1: Vector2 = corners[edge_i]
			var p2: Vector2 = corners[(edge_i + 1) % 4]
			var edge_vec: Vector2 = p2 - p1
			var edge_len: float = edge_vec.length()
			var dir: Vector2 = edge_vec / maxf(edge_len, 0.001)
			var dist := 0.0
			while dist < edge_len:
				var seg_end := minf(dist + dash_len, edge_len)
				draw_line(p1 + dir * dist, p1 + dir * seg_end, dash_col, thickness, true)
				dist += dash_len + gap_len

class BridgeRopeRigging extends Control:
	var plank_rects_tex: Array[Rect2] = []
	var span_x0_tex: float = 265.0
	var span_x1_tex: float = 1510.0

	func _draw() -> void:
		if plank_rects_tex.is_empty() or size.x <= 1.0 or size.y <= 1.0:
			return
		var sx := size.x / BRIDGE_TEX_SIZE.x
		var sy := size.y / BRIDGE_TEX_SIZE.y
		var s_avg := (sx + sy) * 0.5

		var rope_dark := Color("#592c0c")
		var rope_main := Color("#bf7b30")
		var rope_light := Color("#f5c676")

		var prev_top := Vector2((span_x0_tex - 10.0) * sx, 455.0 * sy)
		var prev_bot := Vector2((span_x0_tex - 10.0) * sx, 560.0 * sy)
		for i in range(plank_rects_tex.size()):
			var pr: Rect2 = plank_rects_tex[i]
			var cur_top := Vector2((pr.position.x + pr.size.x * 0.5) * sx, (pr.position.y + pr.size.y * 0.24) * sy)
			var cur_bot := Vector2((pr.position.x + pr.size.x * 0.5) * sx, (pr.position.y + pr.size.y * 0.78) * sy)
			_draw_rope_segment(prev_top, cur_top, 9.0 * s_avg, rope_dark, rope_main, rope_light)
			_draw_rope_segment(prev_bot, cur_bot, 9.0 * s_avg, rope_dark, rope_main, rope_light)
			prev_top = cur_top
			prev_bot = cur_bot
		var end_top := Vector2((span_x1_tex + 10.0) * sx, 442.0 * sy)
		var end_bot := Vector2((span_x1_tex + 10.0) * sx, 548.0 * sy)
		_draw_rope_segment(prev_top, end_top, 9.0 * s_avg, rope_dark, rope_main, rope_light)
		_draw_rope_segment(prev_bot, end_bot, 9.0 * s_avg, rope_dark, rope_main, rope_light)

		for i in range(plank_rects_tex.size() - 1):
			var r1: Rect2 = plank_rects_tex[i]
			var r2: Rect2 = plank_rects_tex[i + 1]
			var kx := (r1.end.x + r2.position.x) * 0.5 * sx
			var ky_top := ((r1.position.y + r1.size.y * 0.24) + (r2.position.y + r2.size.y * 0.24)) * 0.5 * sy
			var ky_bot := ((r1.position.y + r1.size.y * 0.78) + (r2.position.y + r2.size.y * 0.78)) * 0.5 * sy
			_draw_rope_knot(Vector2(kx, ky_top), 7.5 * s_avg, rope_dark, rope_main, rope_light)
			_draw_rope_knot(Vector2(kx, ky_bot), 7.5 * s_avg, rope_dark, rope_main, rope_light)

		var span_len := maxf(1.0, span_x1_tex - span_x0_tex)
		for i in range(plank_rects_tex.size()):
			var pr: Rect2 = plank_rects_tex[i]
			var cx_tex := pr.position.x + pr.size.x * 0.5
			var u := clampf((cx_tex - span_x0_tex) / span_len, 0.0, 1.0)
			var cable_y_tex := lerpf(256.0, 242.0, u) + 118.0 * (4.0 * u * (1.0 - u))
			var p_top := Vector2(cx_tex * sx, cable_y_tex * sy)
			var p_plank := Vector2(cx_tex * sx, (pr.position.y + 8.0) * sy)
			_draw_rope_segment(p_top, p_plank, 8.5 * s_avg, rope_dark, rope_main, rope_light)
			_draw_rope_knot(p_plank, 7.0 * s_avg, rope_dark, rope_main, rope_light)

		var segs := 28
		var prev_pt := Vector2((span_x0_tex - 16.0) * sx, 252.0 * sy)
		for s in range(1, segs + 1):
			var u := float(s) / float(segs)
			var x_tex := lerpf(span_x0_tex - 16.0, span_x1_tex + 16.0, u)
			var y_tex := lerpf(252.0, 238.0, u) + 118.0 * (4.0 * u * (1.0 - u))
			var cur_pt := Vector2(x_tex * sx, y_tex * sy)
			_draw_rope_segment(prev_pt, cur_pt, 12.0 * s_avg, rope_dark, rope_main, rope_light)
			prev_pt = cur_pt

		for i in range(plank_rects_tex.size()):
			var pr: Rect2 = plank_rects_tex[i]
			var cx_tex := pr.position.x + pr.size.x * 0.5
			var u := clampf((cx_tex - span_x0_tex) / span_len, 0.0, 1.0)
			var cable_y_tex := lerpf(256.0, 242.0, u) + 118.0 * (4.0 * u * (1.0 - u))
			_draw_rope_knot(Vector2(cx_tex * sx, cable_y_tex * sy), 8.5 * s_avg, rope_dark, rope_main, rope_light)

	func _draw_rope_segment(p1: Vector2, p2: Vector2, width: float, dark: Color, main: Color, light: Color) -> void:
		draw_line(p1, p2, dark, width + 3.0, true)
		draw_line(p1, p2, main, width, true)
		draw_line(p1 + Vector2(0, -width * 0.18), p2 + Vector2(0, -width * 0.18), light, maxf(1.5, width * 0.35), true)

	func _draw_rope_knot(center: Vector2, radius: float, dark: Color, main: Color, light: Color) -> void:
		draw_circle(center, radius + 1.5, dark)
		draw_circle(center, radius, main)
		draw_circle(center + Vector2(-radius * 0.22, -radius * 0.22), radius * 0.45, light)

var bridge_holder: Control
var bridge_sequence: Array[String] = []
var bridge_missing_plank_indices: Array[int] = []
var bridge_expected_answers: Array[String] = []
var bridge_slot_filled: Array[bool] = []
var bridge_slot_values: Array[String] = []
var bridge_plank_nodes: Array[Control] = []
var bridge_step_labels: Array[Label] = []
var bridge_missing_slots: Array[BridgeMissingSlot] = []
var bridge_animal: BridgeAnimalWalker = null
var bridge_animals: Array[BridgeAnimalWalker] = []
var animal_current_plank: int = -1
var animal_move_tween: Tween = null

var dragging_button: Button = null
var dragging_value: String = ""
var drag_preview: Control = null
var drag_start_pos := Vector2.ZERO
var is_dragging := false
var hovered_missing_slot: int = -1

func _ready() -> void:
	custom_minimum_size.y = 320
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout_bridge_holder)

	bridge_holder = Control.new()
	bridge_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bridge_holder)

func get_prompt_override() -> String:
	return str(level_data.get("prompt", ""))

func get_choices_height(choice_count: int) -> float:
	return 118.0 if choice_count <= 5 else 164.0

func _on_setup_level() -> void:
	bridge_sequence.clear()
	bridge_missing_plank_indices.clear()
	bridge_expected_answers.clear()
	bridge_slot_filled.clear()
	bridge_slot_values.clear()

	if level_data.has("sequence") and level_data["sequence"] is Array:
		for item in level_data["sequence"]:
			bridge_sequence.append(str(item).strip_edges())
	else:
		var raw_prompt := str(level_data.get("prompt", ""))
		var seq_part := raw_prompt.get_slice(":", 1) if ":" in raw_prompt else raw_prompt
		for token in seq_part.split(","):
			var cleaned := token.strip_edges()
			if cleaned != "":
				bridge_sequence.append(cleaned)

	var answers: Array = level_data.get("answers", [])
	var min_steps := maxi(6, answers.size())
	while bridge_sequence.size() < min_steps:
		bridge_sequence.append("?")

	var step_count := bridge_sequence.size()
	var ans_cursor := 0
	for i in range(step_count):
		if bridge_sequence[i] == "?":
			bridge_missing_plank_indices.append(i)
			var expected := str(answers[ans_cursor]) if ans_cursor < answers.size() else ""
			bridge_expected_answers.append(expected)
			bridge_slot_filled.append(false)
			bridge_slot_values.append("")
			ans_cursor += 1

	_build_bridge_visuals()

func rebuild_choices(grid: GridContainer) -> bool:
	var choices: Array = level_data.get("choices", [])
	if choices.size() <= 5:
		grid.columns = maxi(1, choices.size())
	elif choices.size() <= 8:
		grid.columns = 4
	else:
		grid.columns = 5
	var compact_bridge_tiles := choices.size() > 5
	for idx in range(choices.size()):
		var val_str := str(choices[idx])
		var button := Button.new()
		button.text = val_str
		button.custom_minimum_size = Vector2(76, 68) if compact_bridge_tiles else Vector2(88, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn_font_size := 22 if compact_bridge_tiles else 26
		if val_str.length() == 3:
			btn_font_size -= 3
		elif val_str.length() >= 4:
			btn_font_size -= 6
		button.add_theme_font_size_override("font_size", btn_font_size)
		button.add_theme_color_override("font_color", Color("#3b1a08"))
		button.add_theme_stylebox_override("normal", _step_tile_style(Color("#f7dfa8"), Color("#9e571d")))
		button.add_theme_stylebox_override("hover", _step_tile_style(Color("#ffefc6"), Color("#b86825")))
		button.add_theme_stylebox_override("pressed", _step_tile_style(Color("#e8ca88"), Color("#7d4212")))
		button.add_theme_stylebox_override("disabled", _step_tile_style(Color(0.85, 0.78, 0.64, 0.35), Color(0.5, 0.35, 0.2, 0.25)))
		button.gui_input.connect(_on_step_button_gui_input.bind(button, val_str))
		grid.add_child(button)
	return true

func use_hint(grid: GridContainer) -> bool:
	var open_slot := _first_unfilled_bridge_slot()
	if open_slot < 0:
		return false
	var needed := bridge_expected_answers[open_slot]
	for button in grid.get_children():
		if button is Button and button.text == needed and not button.disabled:
			_try_drop_step_on_bridge(open_slot, button, needed)
			return true
	return false

func cancel_interactions() -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	if is_instance_valid(dragging_button) and not dragging_button.disabled:
		dragging_button.modulate = Color.WHITE
	dragging_button = null
	dragging_value = ""
	is_dragging = false
	hovered_missing_slot = -1
	_refresh_bridge_missing_highlights()

func _input(event: InputEvent) -> void:
	if dragging_button == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var pointer_pos: Vector2 = event.position
		if not is_dragging and pointer_pos.distance_to(drag_start_pos) > 7.0:
			is_dragging = true
			_create_step_drag_preview(pointer_pos)
		if is_dragging and is_instance_valid(drag_preview):
			drag_preview.global_position = pointer_pos - drag_preview.size * 0.5
			hovered_missing_slot = _find_missing_slot_at_point(pointer_pos)
			_refresh_bridge_missing_highlights()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_step_pointer_interaction(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_step_pointer_interaction(event.position)

func _on_step_button_gui_input(event: InputEvent, button: Button, value: String) -> void:
	if is_finished or button.disabled:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = button
		dragging_value = value
		drag_start_pos = get_viewport().get_mouse_position()
		is_dragging = false
		hovered_missing_slot = -1

func _create_step_drag_preview(pointer_pos: Vector2) -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	if is_instance_valid(dragging_button):
		dragging_button.modulate.a = 0.35

	var preview_panel := PanelContainer.new()
	preview_panel.size = Vector2(88, 96)
	preview_panel.global_position = pointer_pos - preview_panel.size * 0.5
	preview_panel.z_index = 60
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_theme_stylebox_override("panel", _step_tile_style(Color("#f2b66d"), Color("#783b10")))

	var plank_tex := AtlasTexture.new()
	plank_tex.atlas = BridgeTexture
	plank_tex.region = BRIDGE_PLANK_REGIONS[2]
	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.texture = plank_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(tex_rect)

	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.text = dragging_value
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _compute_step_font_size(dragging_value, 6))
	lbl.add_theme_color_override("font_color", Color("#2b1204"))
	lbl.add_theme_color_override("font_outline_color", Color("#ffefc2"))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(lbl)

	add_child(preview_panel)
	drag_preview = preview_panel

func _find_missing_slot_at_point(screen_pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := 95.0
	for slot_i in range(bridge_missing_slots.size()):
		if slot_i < bridge_slot_filled.size() and bridge_slot_filled[slot_i]:
			continue
		var slot_ctrl := bridge_missing_slots[slot_i]
		if not is_instance_valid(slot_ctrl) or not slot_ctrl.visible:
			continue
		var rect := slot_ctrl.get_global_rect().grow(18.0)
		if rect.has_point(screen_pos):
			return slot_i
		var dist := rect.get_center().distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = slot_i
	return best_idx

func _refresh_bridge_missing_highlights() -> void:
	for slot_i in range(bridge_missing_slots.size()):
		var slot_ctrl := bridge_missing_slots[slot_i]
		if is_instance_valid(slot_ctrl):
			slot_ctrl.is_hovered = (slot_i == hovered_missing_slot)

func _finish_step_pointer_interaction(release_pos: Vector2) -> void:
	var btn := dragging_button
	var val := dragging_value
	var was_dragging := is_dragging
	cancel_interactions()

	if is_finished or not is_instance_valid(btn) or btn.disabled:
		return

	if was_dragging:
		var target_slot := _find_missing_slot_at_point(release_pos)
		if target_slot >= 0:
			_try_drop_step_on_bridge(target_slot, btn, val)
	else:
		var first_open := _first_unfilled_bridge_slot()
		if first_open >= 0:
			_try_drop_step_on_bridge(first_open, btn, val)

func _first_unfilled_bridge_slot() -> int:
	for i in range(bridge_slot_filled.size()):
		if not bridge_slot_filled[i]:
			return i
	return -1

func _try_drop_step_on_bridge(slot_i: int, button: Button, value: String) -> void:
	if slot_i < 0 or slot_i >= bridge_expected_answers.size() or bridge_slot_filled[slot_i]:
		return
	var plank_idx := bridge_missing_plank_indices[slot_i]
	var expected := bridge_expected_answers[slot_i]

	if value == expected:
		bridge_slot_filled[slot_i] = true
		bridge_slot_values[slot_i] = value

		button.disabled = true
		button.modulate = Color(1, 1, 1, 0.35)

		if slot_i < bridge_missing_slots.size() and is_instance_valid(bridge_missing_slots[slot_i]):
			bridge_missing_slots[slot_i].visible = false

		if plank_idx < bridge_plank_nodes.size() and is_instance_valid(bridge_plank_nodes[plank_idx]):
			var plank_node := bridge_plank_nodes[plank_idx]
			var step_lbl := bridge_step_labels[plank_idx]
			step_lbl.text = value
			step_lbl.add_theme_font_size_override("font_size", _compute_step_font_size(value, bridge_sequence.size()))
			plank_node.visible = true
			plank_node.scale = Vector2(0.65, 0.65)
			var tween := create_tween()
			tween.tween_property(plank_node, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(plank_node, "scale", Vector2.ONE, 0.12)

		AudioManager.play_place(true)

		if _first_unfilled_bridge_slot() == -1:
			is_finished = true
			_advance_animal_to_furthest_safe_plank(true, func(): level_completed.emit())
	else:
		if slot_i < bridge_missing_slots.size() and is_instance_valid(bridge_missing_slots[slot_i]):
			var slot_ctrl := bridge_missing_slots[slot_i]
			slot_ctrl.is_error = true
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(slot_ctrl):
					slot_ctrl.is_error = false
			)
		if is_instance_valid(bridge_holder):
			var base_x := bridge_holder.position.x
			var shake := create_tween()
			shake.tween_property(bridge_holder, "position:x", base_x - 12.0, 0.05)
			shake.tween_property(bridge_holder, "position:x", base_x + 12.0, 0.05)
			shake.tween_property(bridge_holder, "position:x", base_x - 8.0, 0.05)
			shake.tween_property(bridge_holder, "position:x", base_x + 8.0, 0.05)
			shake.tween_property(bridge_holder, "position:x", base_x, 0.05)
		mistake_made.emit(button)

func _compute_step_font_size(text_val: String, step_count: int) -> int:
	var base := 28
	if step_count == 7:
		base = 24
	elif step_count == 8:
		base = 21
	elif step_count <= 10:
		base = 18
	elif step_count > 10:
		base = 15
	var char_len := text_val.length()
	if char_len == 3:
		base = int(round(float(base) * 0.82))
	elif char_len >= 4:
		base = int(round(float(base) * 0.66))
	return maxi(12, base)

func _build_bridge_visuals() -> void:
	for child in bridge_holder.get_children():
		child.queue_free()
	bridge_plank_nodes.clear()
	bridge_step_labels.clear()
	bridge_missing_slots.clear()

	var step_count := maxi(1, bridge_sequence.size())
	var dynamic_plank_rects: Array[Rect2] = []
	var dynamic_face_rects: Array[Rect2] = []

	if step_count == 6:
		_add_bridge_atlas_piece(bridge_holder, BRIDGE_LEFT_POST)
		_add_bridge_atlas_piece(bridge_holder, BRIDGE_RIGHT_POST)
		for rope_region in BRIDGE_UPPER_ROPES:
			_add_bridge_atlas_piece(bridge_holder, rope_region)
		for knot_region in BRIDGE_KNOT_STRIPS:
			_add_bridge_atlas_piece(bridge_holder, knot_region)
		for i in range(6):
			dynamic_plank_rects.append(BRIDGE_PLANK_REGIONS[i])
			dynamic_face_rects.append(BRIDGE_STEP_FACE_RECTS[i])
		bridge_holder.set_meta("left_cliff_x", 138.0)
		bridge_holder.set_meta("right_cliff_x", 1638.0)
	else:
		var post_scale_x := clampf(6.0 / float(maxi(6, step_count)), 0.58, 1.0)
		var left_post_w := 265.0 * post_scale_x
		var right_post_w := 264.0 * post_scale_x
		var span_x0 := left_post_w
		var span_x1 := BRIDGE_TEX_SIZE.x - right_post_w
		var span_w := span_x1 - span_x0

		var knot_w := clampf(90.0 / float(step_count), 6.0, 16.0)
		var plank_w := (span_w - float(step_count - 1) * knot_w) / float(step_count)
		for i in range(step_count):
			var u := (float(i) + 0.5) / float(step_count)
			var sag := 4.0 * u * (1.0 - u)
			var px := span_x0 + float(i) * (plank_w + knot_w)
			var py := lerpf(408.0, 442.0, sag)
			var ph := lerpf(222.0, 200.0, sag)
			dynamic_plank_rects.append(Rect2(px, py, plank_w, ph))
			dynamic_face_rects.append(Rect2(px + plank_w * 0.06, py + 14.0, plank_w * 0.88, ph - 50.0))

		var rigging := BridgeRopeRigging.new()
		rigging.set_meta("tex_rect", Rect2(Vector2.ZERO, BRIDGE_TEX_SIZE))
		rigging.span_x0_tex = span_x0
		rigging.span_x1_tex = span_x1
		rigging.plank_rects_tex = dynamic_plank_rects
		rigging.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bridge_holder.add_child(rigging)

		_add_bridge_atlas_piece(bridge_holder, BRIDGE_LEFT_POST, Rect2(0.0, 0.0, left_post_w, BRIDGE_TEX_SIZE.y))
		_add_bridge_atlas_piece(bridge_holder, BRIDGE_RIGHT_POST, Rect2(span_x1, 0.0, right_post_w, BRIDGE_TEX_SIZE.y))
		bridge_holder.set_meta("left_cliff_x", left_post_w * 0.52)
		bridge_holder.set_meta("right_cliff_x", span_x1 + right_post_w * 0.48)

	bridge_holder.set_meta("step_face_rects", dynamic_face_rects)

	var missing_slot_idx := 0
	for i in range(step_count):
		var src_idx := i if step_count == 6 else (0 if i == 0 else (5 if i == step_count - 1 else (2 + (i % 2))))
		var atlas_region: Rect2 = BRIDGE_PLANK_REGIONS[src_idx]
		var target_plank_rect: Rect2 = dynamic_plank_rects[i]
		var face_rect: Rect2 = dynamic_face_rects[i]
		var is_missing := (bridge_sequence[i] == "?")

		var plank_container := Control.new()
		plank_container.set_meta("tex_rect", target_plank_rect)
		plank_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bridge_holder.add_child(plank_container)

		var plank_tex := AtlasTexture.new()
		plank_tex.atlas = BridgeTexture
		plank_tex.region = atlas_region
		var plank_sprite := TextureRect.new()
		plank_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plank_sprite.texture = plank_tex
		plank_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plank_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		plank_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plank_container.add_child(plank_sprite)

		var step_text := "" if is_missing else bridge_sequence[i]
		var num_label := Label.new()
		num_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		num_label.offset_bottom = -8
		num_label.text = step_text
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", _compute_step_font_size(step_text, step_count))
		num_label.add_theme_color_override("font_color", Color("#2b1204"))
		num_label.add_theme_color_override("font_outline_color", Color("#ffefc2"))
		num_label.add_theme_constant_override("outline_size", 4)
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plank_container.add_child(num_label)

		plank_container.visible = not is_missing
		bridge_plank_nodes.append(plank_container)
		bridge_step_labels.append(num_label)

		if is_missing:
			var slot_box := BridgeMissingSlot.new()
			slot_box.set_meta("tex_rect", face_rect)
			slot_box.set_meta("slot_index", missing_slot_idx)
			slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bridge_holder.add_child(slot_box)
			bridge_missing_slots.append(slot_box)
			missing_slot_idx += 1

	if is_instance_valid(animal_move_tween):
		animal_move_tween.kill()
	bridge_animals.clear()
	bridge_animal = null

	var is_most_advanced := stage_index >= 9 or bridge_missing_plank_indices.size() >= 3 or step_count >= 9
	var animal_count := 1
	if is_most_advanced:
		animal_count = 3 if (stage_index >= 11 or step_count >= 10) else 2

	var base_animal_scale := clampf(6.0 / float(maxi(6, step_count)), 0.65, 1.0)
	if animal_count == 2:
		base_animal_scale *= 0.88
	elif animal_count >= 3:
		base_animal_scale *= 0.80

	for slot_idx in range(animal_count - 1, -1, -1):
		var walker := BridgeAnimalWalker.new()
		var kind_idx := (stage_index + slot_idx) % BridgeAnimalWalker.ANIMAL_COUNT
		walker.animal_kind = kind_idx
		walker.anim_time = float(slot_idx) * 1.4
		var slot_scale := base_animal_scale * (1.0 - float(slot_idx) * 0.08)
		walker.scale = Vector2(slot_scale, slot_scale)
		walker.z_index = 15 - slot_idx
		bridge_holder.add_child(walker)
		bridge_animals.insert(0, walker)

	if not bridge_animals.is_empty():
		bridge_animal = bridge_animals[0]
	animal_current_plank = -1

	_layout_bridge_holder.call_deferred()

func _get_bridge_step_stand_pos(step_index: int, animal_slot: int = 0) -> Vector2:
	if not is_instance_valid(bridge_holder):
		return Vector2.ZERO
	var bw := bridge_holder.size.x
	var bh := bridge_holder.size.y
	var sx := bw / BRIDGE_TEX_SIZE.x
	var sy := bh / BRIDGE_TEX_SIZE.y
	var face_rects: Array = bridge_holder.get_meta("step_face_rects", BRIDGE_STEP_FACE_RECTS)
	var left_cliff_x: float = float(bridge_holder.get_meta("left_cliff_x", 138.0))
	var right_cliff_x: float = float(bridge_holder.get_meta("right_cliff_x", 1638.0))
	var total_animals := maxi(1, bridge_animals.size())
	var tex_pt := Vector2(left_cliff_x, 548.0)
	if step_index < 0:
		if total_animals == 2:
			tex_pt = Vector2(left_cliff_x + (26.0 if animal_slot == 0 else -42.0), 552.0 if animal_slot == 0 else 534.0)
		elif total_animals >= 3:
			var cliff_offsets_x := [32.0, -18.0, -64.0]
			var cliff_offsets_y := [554.0, 538.0, 522.0]
			var idx := clampi(animal_slot, 0, 2)
			tex_pt = Vector2(left_cliff_x + cliff_offsets_x[idx], cliff_offsets_y[idx])
	elif step_index < face_rects.size():
		var r: Rect2 = face_rects[step_index]
		var x_shift := 0.0
		var y_shift := 0.0
		if total_animals >= 2:
			x_shift = 16.0 - float(animal_slot) * 24.0
			y_shift = 6.0 - float(animal_slot) * 10.0
		tex_pt = Vector2(r.position.x + r.size.x * 0.5 + x_shift, r.position.y + r.size.y * 0.42 + y_shift)
	else:
		if total_animals == 2:
			tex_pt = Vector2(right_cliff_x + (34.0 if animal_slot == 0 else -34.0), 540.0 if animal_slot == 0 else 524.0)
		elif total_animals >= 3:
			var r_offsets_x := [42.0, -6.0, -52.0]
			var r_offsets_y := [544.0, 530.0, 516.0]
			var idx := clampi(animal_slot, 0, 2)
			tex_pt = Vector2(right_cliff_x + r_offsets_x[idx], r_offsets_y[idx])
		else:
			tex_pt = Vector2(right_cliff_x, 535.0)
	var ref_animal: BridgeAnimalWalker = bridge_animals[animal_slot] if animal_slot < bridge_animals.size() and is_instance_valid(bridge_animals[animal_slot]) else bridge_animal
	var a_size := ref_animal.size if is_instance_valid(ref_animal) else Vector2(68, 76)
	return Vector2(tex_pt.x * sx - a_size.x * 0.5, tex_pt.y * sy - a_size.y + 12.0)

func _is_plank_walkable(plank_idx: int) -> bool:
	var step_count := bridge_sequence.size()
	if plank_idx < 0 or plank_idx >= step_count:
		return false
	var missing_pos := bridge_missing_plank_indices.find(plank_idx)
	if missing_pos == -1:
		return true
	return missing_pos < bridge_slot_filled.size() and bridge_slot_filled[missing_pos]

func _get_furthest_walkable_plank() -> int:
	var furthest := -1
	for i in range(bridge_sequence.size()):
		if _is_plank_walkable(i):
			furthest = i
		else:
			break
	return furthest

func _advance_animal_to_furthest_safe_plank(cross_to_right_bank: bool = false, on_done: Callable = Callable()) -> void:
	if bridge_animals.is_empty() or not is_instance_valid(bridge_animal):
		if on_done.is_valid():
			on_done.call()
		return
	var step_count := bridge_sequence.size()
	var target_step := step_count if cross_to_right_bank else _get_furthest_walkable_plank()
	if target_step <= animal_current_plank:
		if on_done.is_valid():
			on_done.call()
		return

	if is_instance_valid(animal_move_tween):
		animal_move_tween.kill()
	animal_move_tween = create_tween()
	for walker in bridge_animals:
		if is_instance_valid(walker):
			walker.is_hopping = true

	var hop_duration := clampf(0.24 * (6.0 / float(maxi(6, step_count))), 0.14, 0.24)
	while animal_current_plank < target_step:
		var next_step := animal_current_plank + 1
		var lead_dest := _get_bridge_step_stand_pos(next_step, 0)
		animal_move_tween.tween_property(bridge_animal, "position", lead_dest, hop_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		animal_move_tween.parallel().tween_property(bridge_animal, "jump_height", 24.0, hop_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		for slot_i in range(1, bridge_animals.size()):
			var companion := bridge_animals[slot_i]
			if is_instance_valid(companion):
				var comp_dest := _get_bridge_step_stand_pos(next_step, slot_i)
				animal_move_tween.parallel().tween_property(companion, "position", comp_dest, hop_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				animal_move_tween.parallel().tween_property(companion, "jump_height", 22.0, hop_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animal_move_tween.tween_property(bridge_animal, "jump_height", 0.0, hop_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for slot_i in range(1, bridge_animals.size()):
			var companion := bridge_animals[slot_i]
			if is_instance_valid(companion):
				animal_move_tween.parallel().tween_property(companion, "jump_height", 0.0, hop_duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var landed_step := next_step
		animal_move_tween.tween_callback(func():
			if landed_step >= 0 and landed_step < bridge_plank_nodes.size():
				var p_node := bridge_plank_nodes[landed_step]
				if is_instance_valid(p_node):
					var p_tween := create_tween()
					p_tween.tween_property(p_node, "scale", Vector2(1.06, 0.93), 0.06)
					p_tween.tween_property(p_node, "scale", Vector2.ONE, 0.1)
		)
		animal_current_plank = next_step

	if cross_to_right_bank:
		for _j in range(2):
			animal_move_tween.tween_property(bridge_animal, "jump_height", 28.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			for slot_i in range(1, bridge_animals.size()):
				if is_instance_valid(bridge_animals[slot_i]):
					animal_move_tween.parallel().tween_property(bridge_animals[slot_i], "jump_height", 26.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			animal_move_tween.tween_property(bridge_animal, "jump_height", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			for slot_i in range(1, bridge_animals.size()):
				if is_instance_valid(bridge_animals[slot_i]):
					animal_move_tween.parallel().tween_property(bridge_animals[slot_i], "jump_height", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	animal_move_tween.tween_callback(func():
		for walker in bridge_animals:
			if is_instance_valid(walker):
				walker.is_hopping = false
				walker.jump_height = 0.0
		if on_done.is_valid():
			on_done.call()
	)

func _add_bridge_atlas_piece(parent: Control, atlas_region: Rect2, target_rect: Rect2 = Rect2()) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = BridgeTexture
	atlas.region = atlas_region
	var rect := TextureRect.new()
	rect.set_meta("tex_rect", target_rect if target_rect.size != Vector2.ZERO else atlas_region)
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _layout_bridge_holder() -> void:
	if not is_instance_valid(bridge_holder):
		return
	var avail := size
	if avail.x <= 10.0 or avail.y <= 10.0:
		avail = Vector2(504.0, 320.0)
	var aspect := BRIDGE_TEX_SIZE.x / BRIDGE_TEX_SIZE.y
	var bw := avail.x
	var bh := bw / aspect
	if bh > avail.y:
		bh = avail.y
		bw = bh * aspect
	bridge_holder.size = Vector2(bw, bh)
	bridge_holder.position = Vector2((avail.x - bw) * 0.5, (avail.y - bh) * 0.5)

	var sx := bw / BRIDGE_TEX_SIZE.x
	var sy := bh / BRIDGE_TEX_SIZE.y
	for child in bridge_holder.get_children():
		if child is Control and child.has_meta("tex_rect"):
			var r: Rect2 = child.get_meta("tex_rect")
			child.position = Vector2(r.position.x * sx, r.position.y * sy)
			child.size = Vector2(r.size.x * sx, r.size.y * sy)
			child.pivot_offset = child.size * 0.5
			child.queue_redraw()
	if not is_instance_valid(animal_move_tween) or not animal_move_tween.is_running():
		for slot_i in range(bridge_animals.size()):
			var walker := bridge_animals[slot_i]
			if is_instance_valid(walker):
				walker.position = _get_bridge_step_stand_pos(animal_current_plank, slot_i)

func _step_tile_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	return style
