class_name NumberBalanceComponent
extends GameModeComponent

## Self-contained Balance the Scale component.
## Manages articulated golden scale rig, multi-ball pan layout (1..6+ balls per pan),
## flying ball intro animation, bottom choice balls, subset-sum validation for
## max_user_balls, wrong-ball feedback + mistake_made emission, and 3-second balance hold.

const BalanceScaleTexture = preload("res://assets/gameplay_sprites/balance-scale.png")
const BALANCE_TEX_SIZE := Vector2(1536.0, 1024.0)
const BALANCE_HOLD_REQUIRED := 3.0

class BalanceNeckConnector extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(w * 0.24, 0, w * 0.52, h), Color("#8c5210"))
		draw_rect(Rect2(w * 0.30, 0, w * 0.40, h), Color("#d99326"))
		draw_rect(Rect2(w * 0.38, 0, w * 0.22, h), Color("#ffda66"))

class BalancePanDropRing extends Control:
	var is_hovered: bool = false:
		set(value):
			if is_hovered != value:
				is_hovered = value
				queue_redraw()
	var is_balanced_glow: bool = false:
		set(value):
			if is_balanced_glow != value:
				is_balanced_glow = value
				queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		var rx := size.x * 0.42
		var ry := size.y * 0.28
		var col := Color("#5eff89") if is_balanced_glow else (Color("#ffe853") if is_hovered else Color(1.0, 0.92, 0.55, 0.45))
		var pts := PackedVector2Array()
		var segs := 28
		for i in range(segs + 1):
			var a := float(i) * TAU / float(segs)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, col, 3.5 if (is_hovered or is_balanced_glow) else 2.0, true)

var balance_holder: Control
var balance_beam_node: TextureRect
var balance_left_pan_node: TextureRect
var balance_right_pan_node: TextureRect
var balance_left_balls_box: Control
var balance_right_balls_box: Control
var balance_drop_ring: BalancePanDropRing
var balance_left_balls_data: Array[int] = []
var balance_right_fixed_balls_data: Array[int] = []
var balance_user_balls: Array[Dictionary] = []
var balance_max_user_balls: int = 1
var balance_left_weight: int = 0
var balance_right_weight: int = 0
var balance_beam_angle_deg: float = 0.0
var balance_tilt_tween: Tween = null
var balance_intro_tween: Tween = null
var balance_intro_playing: bool = false
var balance_holding_level: bool = false
var balance_hold_remaining: float = 0.0
var balance_osc_time: float = 0.0
var balance_wrong_ball_busy: bool = false

var dragging_button: Button = null
var dragging_value: String = ""
var dragging_color_index: int = 0
var drag_preview: Control = null
var drag_start_pos := Vector2.ZERO
var is_dragging := false

func _ready() -> void:
	custom_minimum_size.y = 325
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout_balance_holder)

	balance_holder = Control.new()
	balance_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(balance_holder)

func get_prompt_override() -> String:
	return str(level_data.get("prompt", ""))

func get_choices_height(choice_count: int) -> float:
	return 152.0 if choice_count <= 6 else 184.0

func is_timer_paused() -> bool:
	return balance_holding_level

func _process(delta: float) -> void:
	if is_finished or get_tree().paused:
		return
	if balance_holding_level:
		balance_osc_time += delta * 7.5
		balance_hold_remaining = maxf(0.0, balance_hold_remaining - delta)
		var damp := clampf(balance_hold_remaining / BALANCE_HOLD_REQUIRED, 0.0, 1.0)
		var settle_angle := sin(balance_osc_time) * 1.1 * damp * damp
		_set_balance_beam_angle(settle_angle)
		if balance_hold_remaining <= 0.0:
			balance_holding_level = false
			_set_balance_beam_angle(0.0)
			is_finished = true
			level_completed.emit()

func _input(event: InputEvent) -> void:
	if dragging_button == null:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var pointer_pos: Vector2 = event.position
		if not is_dragging and pointer_pos.distance_to(drag_start_pos) > 7.0:
			is_dragging = true
			_create_ball_drag_preview(pointer_pos)
		if is_dragging and is_instance_valid(drag_preview):
			drag_preview.global_position = pointer_pos - drag_preview.size * 0.5
			if is_instance_valid(balance_drop_ring):
				balance_drop_ring.is_hovered = _is_point_over_right_pan(pointer_pos)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_ball_pointer_interaction(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_ball_pointer_interaction(event.position)

func _on_setup_level() -> void:
	if is_instance_valid(balance_tilt_tween):
		balance_tilt_tween.kill()
	if is_instance_valid(balance_intro_tween):
		balance_intro_tween.kill()
	balance_left_balls_data.clear()
	balance_right_fixed_balls_data.clear()
	balance_user_balls.clear()
	balance_left_weight = 0
	balance_right_weight = 0
	balance_beam_angle_deg = 0.0
	balance_holding_level = false
	balance_hold_remaining = 0.0
	balance_wrong_ball_busy = false
	balance_intro_playing = true

	if level_data.has("left_balls") and level_data["left_balls"] is Array:
		for v in level_data["left_balls"]:
			balance_left_balls_data.append(int(v))
	if level_data.has("right_balls") and level_data["right_balls"] is Array:
		for v in level_data["right_balls"]:
			balance_right_fixed_balls_data.append(int(v))

	if balance_left_balls_data.is_empty():
		var eq := str(level_data.get("prompt", ""))
		var sides := eq.split("=")
		if sides.size() >= 1:
			for part in sides[0].split("+"):
				var t := part.strip_edges()
				if t.is_valid_int():
					balance_left_balls_data.append(int(t))
		if sides.size() >= 2:
			for part in sides[1].split("+"):
				var t := part.strip_edges()
				if t.is_valid_int():
					balance_right_fixed_balls_data.append(int(t))

	var answers_count: int = level_data.get("answers", []).size()
	balance_max_user_balls = int(level_data.get("max_user_balls", maxi(1, answers_count)))
	_build_balance_visuals()

func rebuild_choices(grid: GridContainer) -> bool:
	var choices: Array = level_data.get("choices", [])
	grid.columns = mini(6, maxi(3, choices.size()))
	var pan_ball_offset := balance_left_balls_data.size() + balance_right_fixed_balls_data.size()
	for idx in range(choices.size()):
		var val_str := str(choices[idx])
		var button := Button.new()
		button.text = ""
		button.set_meta("ball_value", val_str)
		button.custom_minimum_size = Vector2(74, 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var empty_sb := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty_sb)
		button.add_theme_stylebox_override("hover", empty_sb)
		button.add_theme_stylebox_override("pressed", empty_sb)
		button.add_theme_stylebox_override("disabled", empty_sb)
		button.add_theme_stylebox_override("focus", empty_sb)
		var col_idx := (stage_index * 3 + pan_ball_offset + idx + 2) % BalanceWeightBall.PALETTES.size()
		button.set_meta("color_index", col_idx)
		var ball_vis := BalanceWeightBall.new()
		ball_vis.number_text = val_str
		ball_vis.color_index = col_idx
		ball_vis.is_user_ball = true
		ball_vis.set_anchors_preset(Control.PRESET_CENTER)
		ball_vis.offset_left = -34.0
		ball_vis.offset_top = -34.0
		ball_vis.offset_right = 34.0
		ball_vis.offset_bottom = 34.0
		ball_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(ball_vis)
		button.gui_input.connect(_on_ball_button_gui_input.bind(button, val_str))
		grid.add_child(button)
	return true

func can_use_hint() -> bool:
	if is_finished or balance_intro_playing or balance_holding_level or balance_wrong_ball_busy:
		return false
	for ball in balance_user_balls:
		if not bool(ball.get("landed", false)):
			return false
	return true

func use_hint(grid: GridContainer) -> bool:
	if balance_intro_playing or balance_holding_level or balance_wrong_ball_busy:
		return false
	var answers_b: Array = level_data.get("answers", [])
	var expected_strs: Array[String] = []
	for a in answers_b:
		expected_strs.append(str(a))
	for k in range(balance_user_balls.size() - 1, -1, -1):
		var placed_txt := str(balance_user_balls[k].get("text", ""))
		if placed_txt not in expected_strs:
			_remove_user_ball_at(k, false)
	for ans_str in expected_strs:
		for button in grid.get_children():
			if button is Button and not button.disabled and str(button.get_meta("ball_value", button.text)) == ans_str:
				_place_user_ball_on_scale(button, ans_str)
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
	if is_instance_valid(balance_drop_ring):
		balance_drop_ring.is_hovered = false

func _on_ball_button_gui_input(event: InputEvent, button: Button, value: String) -> void:
	if is_finished or button.disabled or balance_intro_playing or balance_holding_level or balance_wrong_ball_busy:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = button
		dragging_value = value
		dragging_color_index = int(button.get_meta("color_index", 0))
		drag_start_pos = get_viewport().get_mouse_position()
		is_dragging = false

func _build_balance_visuals() -> void:
	for child in balance_holder.get_children():
		child.queue_free()

	var w := BALANCE_TEX_SIZE.x
	var h := BALANCE_TEX_SIZE.y

	var neck := BalanceNeckConnector.new()
	neck.set_meta("norm_rect", Rect2(0.455, 0.20, 0.09, 0.22))
	neck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_holder.add_child(neck)

	var base_col := _add_balance_atlas_piece(
		balance_holder,
		Rect2(0.32 * w, 0.37 * h, 0.36 * w, 0.63 * h),
		Rect2(0.32, 0.37, 0.36, 0.63)
	)
	base_col.z_index = 2

	var top_finial := _add_balance_atlas_piece(
		balance_holder,
		Rect2(0.41 * w, 0.00 * h, 0.18 * w, 0.24 * h),
		Rect2(0.41, 0.00, 0.18, 0.24)
	)
	top_finial.z_index = 2

	balance_left_pan_node = _add_balance_atlas_piece(
		balance_holder,
		Rect2(0.01 * w, 0.335 * h, 0.40 * w, 0.45 * h),
		Rect2(0.01, 0.335, 0.40, 0.45)
	)
	balance_left_pan_node.z_index = 4

	balance_left_balls_box = Control.new()
	balance_left_balls_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_left_pan_node.add_child(balance_left_balls_box)

	balance_right_pan_node = _add_balance_atlas_piece(
		balance_holder,
		Rect2(0.59 * w, 0.335 * h, 0.40 * w, 0.45 * h),
		Rect2(0.59, 0.335, 0.40, 0.45)
	)
	balance_right_pan_node.z_index = 4
	balance_right_pan_node.mouse_filter = Control.MOUSE_FILTER_PASS

	balance_drop_ring = BalancePanDropRing.new()
	balance_drop_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_right_pan_node.add_child(balance_drop_ring)

	balance_right_balls_box = Control.new()
	balance_right_balls_box.mouse_filter = Control.MOUSE_FILTER_PASS
	balance_right_pan_node.add_child(balance_right_balls_box)

	balance_beam_node = _add_balance_atlas_piece(
		balance_holder,
		Rect2(0.155 * w, 0.215 * h, 0.69 * w, 0.165 * h),
		Rect2(0.155, 0.215, 0.69, 0.165)
	)
	balance_beam_node.z_index = 6

	_layout_balance_holder.call_deferred()
	_play_balance_intro_animation.call_deferred()

func _add_balance_atlas_piece(parent: Control, atlas_region: Rect2, norm_rect: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = BalanceScaleTexture
	atlas.region = atlas_region
	var rect := TextureRect.new()
	rect.set_meta("norm_rect", norm_rect)
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _layout_balance_holder() -> void:
	if not is_instance_valid(balance_holder):
		return
	var avail := size
	if avail.x <= 10.0 or avail.y <= 10.0:
		avail = Vector2(504.0, 325.0)
	var aspect := BALANCE_TEX_SIZE.x / BALANCE_TEX_SIZE.y
	var bw := avail.x
	var bh := bw / aspect
	if bh > avail.y:
		bh = avail.y
		bw = bh * aspect
	balance_holder.size = Vector2(bw, bh)
	balance_holder.position = Vector2((avail.x - bw) * 0.5, (avail.y - bh) * 0.5)

	for child in balance_holder.get_children():
		if child is Control and child.has_meta("norm_rect"):
			var nr: Rect2 = child.get_meta("norm_rect")
			child.position = Vector2(nr.position.x * bw, nr.position.y * bh)
			child.size = Vector2(nr.size.x * bw, nr.size.y * bh)
			child.pivot_offset = child.size * 0.5
			child.queue_redraw()

	_update_balance_rig_transforms()
	_layout_pan_balls(balance_left_pan_node, balance_left_balls_box)
	_layout_pan_balls(balance_right_pan_node, balance_right_balls_box)

func _set_balance_beam_angle(deg: float) -> void:
	balance_beam_angle_deg = deg
	_update_balance_rig_transforms()

func _update_balance_rig_transforms() -> void:
	if not is_instance_valid(balance_holder) or not is_instance_valid(balance_beam_node):
		return
	var bw := balance_holder.size.x
	var bh := balance_holder.size.y
	if bw <= 1.0 or bh <= 1.0:
		return

	var pivot := Vector2(0.50 * bw, 0.300 * bh)
	var beam_nr: Rect2 = balance_beam_node.get_meta("norm_rect", Rect2(0.155, 0.215, 0.69, 0.165))
	balance_beam_node.size = Vector2(beam_nr.size.x * bw, beam_nr.size.y * bh)
	balance_beam_node.position = Vector2(beam_nr.position.x * bw, beam_nr.position.y * bh)
	balance_beam_node.pivot_offset = pivot - balance_beam_node.position
	var rad := deg_to_rad(balance_beam_angle_deg)
	balance_beam_node.rotation = rad

	var left_hook := pivot + Vector2(-0.288 * bw, 0.025 * bh).rotated(rad)
	var right_hook := pivot + Vector2(0.288 * bw, 0.025 * bh).rotated(rad)

	if is_instance_valid(balance_left_pan_node):
		var l_size := Vector2(0.40 * bw, 0.45 * bh)
		balance_left_pan_node.size = l_size
		balance_left_pan_node.position = Vector2(left_hook.x - l_size.x * 0.505, left_hook.y - bh * 0.012)
	if is_instance_valid(balance_right_pan_node):
		var r_size := Vector2(0.40 * bw, 0.45 * bh)
		balance_right_pan_node.size = r_size
		balance_right_pan_node.position = Vector2(right_hook.x - r_size.x * 0.495, right_hook.y - bh * 0.012)
		if is_instance_valid(balance_drop_ring):
			balance_drop_ring.position = Vector2(r_size.x * 0.08, r_size.y * 0.40)
			balance_drop_ring.size = Vector2(r_size.x * 0.84, r_size.y * 0.42)
			balance_drop_ring.queue_redraw()

func _compute_pan_ball_layout(balls_box: Control, total_count: int) -> Dictionary:
	var bw := maxf(balls_box.size.x, 120.0)
	var bh := maxf(balls_box.size.y, 64.0)
	var positions: Array[Vector2] = []
	if total_count <= 0:
		return {"diam": 52.0, "positions": positions}

	if total_count == 1:
		var diam1 := clampf(minf(bw * 0.44, bh * 0.80), 38.0, 60.0)
		positions.append(Vector2((bw - diam1) * 0.5, bh * 0.56 - diam1 * 0.5))
		return {"diam": diam1, "positions": positions}

	if total_count == 2:
		var diam2 := clampf(minf(bw * 0.38, bh * 0.76), 34.0, 54.0)
		var spacing2 := diam2 * 1.02
		var start_x2 := (bw - (spacing2 + diam2)) * 0.5
		var y2 := bh * 0.56 - diam2 * 0.5
		positions.append(Vector2(start_x2, y2))
		positions.append(Vector2(start_x2 + spacing2, y2))
		return {"diam": diam2, "positions": positions}

	if total_count == 3:
		var diam3 := clampf(minf(bw * 0.31, bh * 0.68), 30.0, 46.0)
		var spacing3 := diam3 * 0.96
		var start_x3 := (bw - (2.0 * spacing3 + diam3)) * 0.5
		for i in range(3):
			var y_curve := (bh * 0.60 if i == 1 else bh * 0.50) - diam3 * 0.5
			positions.append(Vector2(start_x3 + float(i) * spacing3, y_curve))
		return {"diam": diam3, "positions": positions}

	# 4 or more balls in one pan: 2-row pyramid cluster inside the pan bowl
	var bottom_count := ceili(float(total_count) * 0.5)
	var top_count := total_count - bottom_count
	var diam_m := clampf(minf(bw / (float(bottom_count) + 0.25), bh * 0.54), 26.0, 42.0)
	var spacing_m := diam_m * 0.98
	var b_start_x := (bw - (float(bottom_count - 1) * spacing_m + diam_m)) * 0.5
	var b_y := bh * 0.68 - diam_m * 0.5
	for i in range(bottom_count):
		positions.append(Vector2(b_start_x + float(i) * spacing_m, b_y))
	var t_start_x := (bw - (float(top_count - 1) * spacing_m + diam_m)) * 0.5
	var t_y := b_y - diam_m * 0.84
	for j in range(top_count):
		positions.append(Vector2(t_start_x + float(j) * spacing_m, t_y))
	return {"diam": diam_m, "positions": positions}

func _layout_pan_balls(pan_node: Control, balls_box: Control) -> void:
	if not is_instance_valid(pan_node) or not is_instance_valid(balls_box):
		return
	var pw := pan_node.size.x
	var ph := pan_node.size.y
	balls_box.position = Vector2(pw * 0.09, ph * 0.28)
	balls_box.size = Vector2(pw * 0.82, ph * 0.48)

	var count := balls_box.get_child_count()
	var layout := _compute_pan_ball_layout(balls_box, count)
	var ball_diam: float = layout["diam"]
	var positions: Array[Vector2] = layout["positions"]
	for i in range(count):
		var ball := balls_box.get_child(i)
		if ball is Control:
			ball.size = Vector2(ball_diam, ball_diam)
			ball.pivot_offset = ball.size * 0.5
			if not ball.has_meta("flying") and i < positions.size():
				ball.position = positions[i]
			ball.queue_redraw()

func _get_pan_ball_slot_pos(balls_box: Control, index: int, total_count: int) -> Vector2:
	var layout := _compute_pan_ball_layout(balls_box, total_count)
	var positions: Array[Vector2] = layout["positions"]
	if index >= 0 and index < positions.size():
		return positions[index]
	return Vector2.ZERO

func _recalculate_right_pan_weight() -> void:
	var w := 0
	for fixed_v in balance_right_fixed_balls_data:
		w += int(fixed_v)
	for entry in balance_user_balls:
		if bool(entry.get("landed", false)):
			w += int(entry.get("value", 0))
	balance_right_weight = w

func _compute_target_scale_angle_deg(left_w: int, right_w: int) -> float:
	if left_w == right_w:
		return 0.0
	var diff := float(right_w - left_w)
	var max_w := maxf(float(maxi(left_w, right_w)), 1.0)
	var norm := clampf(diff / max_w, -1.0, 1.0)
	var sign_dir := signf(diff)
	return sign_dir * clampf(4.8 + absf(norm) * 12.2, 4.8, 16.8)

func _animate_scale_to_weights(check_balance_hold: bool = true) -> void:
	var target_deg := _compute_target_scale_angle_deg(balance_left_weight, balance_right_weight)
	if is_instance_valid(balance_tilt_tween):
		balance_tilt_tween.kill()

	if check_balance_hold and not balance_intro_playing and balance_left_weight > 0 and balance_right_weight == balance_left_weight and balance_user_balls.size() == balance_max_user_balls:
		balance_holding_level = true
		balance_hold_remaining = BALANCE_HOLD_REQUIRED
		balance_osc_time = 0.0
		if is_instance_valid(balance_drop_ring):
			balance_drop_ring.is_balanced_glow = true
		balance_tilt_tween = create_tween()
		balance_tilt_tween.tween_method(_set_balance_beam_angle, balance_beam_angle_deg, 0.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return

	balance_holding_level = false
	balance_hold_remaining = 0.0
	if is_instance_valid(balance_drop_ring):
		balance_drop_ring.is_balanced_glow = false

	var overshoot := target_deg + (2.4 if target_deg >= balance_beam_angle_deg else -2.4)
	balance_tilt_tween = create_tween()
	balance_tilt_tween.tween_method(_set_balance_beam_angle, balance_beam_angle_deg, overshoot, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	balance_tilt_tween.tween_method(_set_balance_beam_angle, overshoot, target_deg, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _has_subset_sum(avail_vals: Array[int], start_idx: int, count_needed: int, target_sum: int) -> bool:
	if count_needed == 0:
		return target_sum == 0
	if target_sum <= 0 or start_idx >= avail_vals.size() or (avail_vals.size() - start_idx) < count_needed:
		return false
	for i in range(start_idx, avail_vals.size()):
		if _has_subset_sum(avail_vals, i + 1, count_needed - 1, target_sum - avail_vals[i]):
			return true
	return false

func _is_current_balance_placement_valid() -> bool:
	var placed_count := balance_user_balls.size()
	var slots_left := balance_max_user_balls - placed_count
	var remaining_needed := balance_left_weight - balance_right_weight
	if slots_left <= 0:
		return remaining_needed == 0
	if remaining_needed <= 0:
		return false
	var avail_vals: Array[int] = []
	if is_instance_valid(choices_grid):
		for child in choices_grid.get_children():
			if child is Button and not child.disabled:
				var v_str := str(child.get_meta("ball_value", child.text))
				if v_str.is_valid_int():
					avail_vals.append(int(v_str))
	return _has_subset_sum(avail_vals, 0, slots_left, remaining_needed)

func _handle_wrong_balance_ball(entry: Dictionary) -> void:
	balance_wrong_ball_busy = true
	var btn: Button = entry.get("button")
	var ball_node: Control = entry.get("node")

	if is_instance_valid(ball_node):
		var flash := create_tween()
		flash.tween_property(ball_node, "modulate", Color("#ff4d4d"), 0.09)
		flash.tween_property(ball_node, "modulate", Color.WHITE, 0.12)
		flash.tween_property(ball_node, "modulate", Color("#ff4d4d"), 0.09)

	if is_instance_valid(balance_holder):
		var base_x := balance_holder.position.x
		var shake := create_tween()
		shake.tween_property(balance_holder, "position:x", base_x - 12.0, 0.05)
		shake.tween_property(balance_holder, "position:x", base_x + 12.0, 0.05)
		shake.tween_property(balance_holder, "position:x", base_x - 8.0, 0.05)
		shake.tween_property(balance_holder, "position:x", base_x + 8.0, 0.05)
		shake.tween_property(balance_holder, "position:x", base_x, 0.05)

	# Notify the host level controller so it deducts a heart and fails the level if hearts reach 0
	mistake_made.emit(btn)

	get_tree().create_timer(0.45).timeout.connect(func():
		if not is_inside_tree():
			return
		balance_wrong_ball_busy = false
		if is_finished:
			return
		var idx := balance_user_balls.find(entry)
		if idx >= 0:
			_remove_user_ball_at(idx, true)
	)

func _play_balance_intro_animation() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(balance_left_balls_box):
		return
	_layout_balance_holder()
	if is_instance_valid(balance_intro_tween):
		balance_intro_tween.kill()

	_set_balance_beam_angle(0.0)
	balance_left_weight = 0
	balance_right_weight = 0

	balance_intro_tween = create_tween()
	balance_intro_tween.tween_interval(0.12)

	var left_total_balls := balance_left_balls_data.size()
	for i in range(left_total_balls):
		var val := balance_left_balls_data[i]
		var col_idx := (stage_index * 3 + i) % BalanceWeightBall.PALETTES.size()
		var ball := BalanceWeightBall.new()
		ball.number_text = str(val)
		ball.color_index = col_idx
		ball.is_user_ball = false
		ball.modulate.a = 0.0
		ball.set_meta("flying", true)
		balance_left_balls_box.add_child(ball)
		_layout_pan_balls(balance_left_pan_node, balance_left_balls_box)

		var target_pos := _get_pan_ball_slot_pos(balance_left_balls_box, i, left_total_balls)
		var start_pos := target_pos + Vector2(65.0, -165.0)
		ball.position = start_pos

		balance_intro_tween.tween_callback(func():
			if is_instance_valid(ball):
				ball.modulate.a = 1.0
				ball.scale = Vector2(0.55, 0.55)
		)
		balance_intro_tween.tween_property(ball, "position", target_pos, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		balance_intro_tween.parallel().tween_property(ball, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		balance_intro_tween.tween_callback(func():
			if is_instance_valid(ball):
				ball.remove_meta("flying")
			AudioManager.play_place(true)
			balance_left_weight += val
			_layout_pan_balls(balance_left_pan_node, balance_left_balls_box)
			_animate_scale_to_weights(false)
		)
		balance_intro_tween.tween_interval(0.16)

	var right_fixed_count := balance_right_fixed_balls_data.size()
	for j in range(right_fixed_count):
		var r_val := balance_right_fixed_balls_data[j]
		var r_col_idx := (stage_index * 3 + left_total_balls + j + 1) % BalanceWeightBall.PALETTES.size()
		var r_ball := BalanceWeightBall.new()
		r_ball.number_text = str(r_val)
		r_ball.color_index = r_col_idx
		r_ball.is_user_ball = false
		r_ball.modulate.a = 0.0
		r_ball.set_meta("flying", true)
		balance_right_balls_box.add_child(r_ball)
		_layout_pan_balls(balance_right_pan_node, balance_right_balls_box)

		var r_target := _get_pan_ball_slot_pos(balance_right_balls_box, j, right_fixed_count)
		var r_start := r_target + Vector2(-65.0, -165.0)
		r_ball.position = r_start

		balance_intro_tween.tween_callback(func():
			if is_instance_valid(r_ball):
				r_ball.modulate.a = 1.0
				r_ball.scale = Vector2(0.55, 0.55)
		)
		balance_intro_tween.tween_property(r_ball, "position", r_target, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		balance_intro_tween.parallel().tween_property(r_ball, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		balance_intro_tween.tween_callback(func():
			if is_instance_valid(r_ball):
				r_ball.remove_meta("flying")
			AudioManager.play_place(true)
			balance_right_weight += r_val
			_layout_pan_balls(balance_right_pan_node, balance_right_balls_box)
			_animate_scale_to_weights(false)
		)
		balance_intro_tween.tween_interval(0.15)

	balance_intro_tween.tween_callback(func():
		balance_intro_playing = false
	)

func _place_user_ball_on_scale(button: Button, value_str: String) -> void:
	if is_finished or balance_intro_playing or balance_wrong_ball_busy or not is_instance_valid(button) or button.disabled:
		return
	if balance_holding_level:
		return

	if balance_user_balls.size() >= balance_max_user_balls:
		_remove_user_ball_at(balance_user_balls.size() - 1, false)

	var val_int := int(value_str)
	var col_idx := int(button.get_meta("color_index", 2))
	button.disabled = true
	button.modulate = Color(1, 1, 1, 0.30)

	var ball_node := BalanceWeightBall.new()
	ball_node.number_text = value_str
	ball_node.color_index = col_idx
	ball_node.is_user_ball = true
	ball_node.mouse_filter = Control.MOUSE_FILTER_STOP
	ball_node.tooltip_text = "Tap to remove ball"
	ball_node.set_meta("flying", true)
	balance_right_balls_box.add_child(ball_node)

	var entry := {
		"value": val_int,
		"text": value_str,
		"button": button,
		"node": ball_node,
		"landed": false,
		"tween": null
	}
	balance_user_balls.append(entry)
	ball_node.gui_input.connect(_on_placed_user_ball_gui_input.bind(ball_node))

	_layout_pan_balls(balance_right_pan_node, balance_right_balls_box)
	var slot_idx := balance_right_balls_box.get_child_count() - 1
	var total_in_pan := balance_right_balls_box.get_child_count()
	var dest_local := _get_pan_ball_slot_pos(balance_right_balls_box, slot_idx, total_in_pan)
	var start_global := button.get_global_rect().get_center() - ball_node.size * 0.5
	ball_node.global_position = start_global

	var fly_tween := create_tween()
	entry["tween"] = fly_tween
	fly_tween.tween_property(ball_node, "position", dest_local, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly_tween.tween_callback(func():
		if is_instance_valid(ball_node):
			ball_node.remove_meta("flying")
		entry["landed"] = true
		_recalculate_right_pan_weight()
		_layout_pan_balls(balance_right_pan_node, balance_right_balls_box)
		if _is_current_balance_placement_valid():
			AudioManager.play_place(true)
			_animate_scale_to_weights(true)
		else:
			_animate_scale_to_weights(false)
			_handle_wrong_balance_ball(entry)
	)

func _on_placed_user_ball_gui_input(event: InputEvent, ball_node: Control) -> void:
	if is_finished or balance_intro_playing or balance_holding_level or balance_wrong_ball_busy:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		for i in range(balance_user_balls.size()):
			if balance_user_balls[i].get("node") == ball_node:
				_remove_user_ball_at(i, true)
				break

func _remove_user_ball_at(index: int, reanimate: bool = true) -> void:
	if index < 0 or index >= balance_user_balls.size():
		return
	var entry: Dictionary = balance_user_balls[index]
	balance_user_balls.remove_at(index)
	var tw = entry.get("tween")
	if tw is Tween and is_instance_valid(tw):
		tw.kill()
	var btn: Button = entry.get("button")
	var node: Control = entry.get("node")
	if is_instance_valid(node):
		balance_right_balls_box.remove_child(node)
		node.queue_free()
	if is_instance_valid(btn):
		btn.disabled = false
		btn.modulate = Color.WHITE
	_recalculate_right_pan_weight()
	_layout_pan_balls(balance_right_pan_node, balance_right_balls_box)
	if reanimate:
		_animate_scale_to_weights(true)

func _create_ball_drag_preview(pointer_pos: Vector2) -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	if is_instance_valid(dragging_button):
		dragging_button.modulate.a = 0.30

	var ball_preview := BalanceWeightBall.new()
	ball_preview.number_text = dragging_value
	ball_preview.color_index = dragging_color_index
	ball_preview.is_user_ball = true
	ball_preview.size = Vector2(74, 74)
	ball_preview.global_position = pointer_pos - ball_preview.size * 0.5
	ball_preview.z_index = 65
	ball_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ball_preview)
	drag_preview = ball_preview

func _is_point_over_right_pan(screen_pos: Vector2) -> bool:
	if not is_instance_valid(balance_right_pan_node):
		return false
	var pan_rect := balance_right_pan_node.get_global_rect().grow(32.0)
	return pan_rect.has_point(screen_pos)

func _finish_ball_pointer_interaction(release_pos: Vector2) -> void:
	var btn := dragging_button
	var val := dragging_value
	var was_dragging := is_dragging
	cancel_interactions()

	if is_finished or balance_intro_playing or balance_wrong_ball_busy or not is_instance_valid(btn) or btn.disabled:
		return

	if was_dragging:
		if _is_point_over_right_pan(release_pos) or (is_instance_valid(balance_holder) and balance_holder.get_global_rect().has_point(release_pos)):
			_place_user_ball_on_scale(btn, val)
	else:
		_place_user_ball_on_scale(btn, val)
