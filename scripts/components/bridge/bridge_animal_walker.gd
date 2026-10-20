class_name BridgeAnimalWalker
extends Control

## Reusable procedural 12-species cartoon animal walker component.
## 0=Fox, 1=Bunny, 2=Panda, 3=Bear, 4=Tiger, 5=Koala, 6=Frog, 7=Penguin, 8=Lion, 9=Deer, 10=Monkey, 11=Owl

const ANIMAL_COUNT := 12

var animal_kind: int = 0
var anim_time: float = 0.0
var is_hopping: bool = false
var jump_height: float = 0.0
var facing_dir: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(68, 76)
	size = Vector2(68, 76)

func _process(delta: float) -> void:
	anim_time += delta * (11.0 if is_hopping else 3.6)
	queue_redraw()

func _draw() -> void:
	var kind := posmod(animal_kind, ANIMAL_COUNT)
	var cx := size.x * 0.5
	var base_y := size.y - 10.0
	var bob := absf(sin(anim_time)) * (4.0 if is_hopping else 2.2)
	var body_y := base_y - 22.0 - jump_height - bob
	var leg_swing := sin(anim_time * 1.6) * (5.5 if is_hopping else 1.2)
	var head_center := Vector2(cx + 2.0 * facing_dir, body_y - 12.0)
	var wag := sin(anim_time * 1.3) * 4.0

	# Ground shadow on the plank/rock
	var shadow_scale := clampf(1.0 - jump_height / 48.0, 0.45, 1.0)
	draw_circle(Vector2(cx, base_y + 2.0), 14.0 * shadow_scale, Color(0, 0, 0, 0.28 * shadow_scale))

	match kind:
		0:
			# 0: Woodland Fox
			var fur_main := Color("#f26d21")
			var fur_dark := Color("#b84309")
			var cream := Color("#fff3d6")
			var tail_pos := Vector2(cx - 15.0 * facing_dir, body_y + 4.0 + wag * 0.4)
			draw_circle(tail_pos, 10.5, fur_dark)
			draw_circle(tail_pos + Vector2(-1.0 * facing_dir, -1.0), 9.0, fur_main)
			draw_circle(tail_pos + Vector2(-6.5 * facing_dir, -3.5 + wag * 0.3), 5.5, cream)
			_draw_paws(cx, base_y, leg_swing, Color("#3b1c0a"))
			_draw_torso(cx, body_y, fur_main, fur_dark, cream)
			_draw_pointy_ears(head_center, fur_dark, cream)
			draw_circle(head_center, 15.5, fur_dark)
			draw_circle(head_center, 14.0, fur_main)
			draw_circle(head_center + Vector2(-6.5, 4.5), 7.5, cream)
			draw_circle(head_center + Vector2(6.5, 4.5), 7.5, cream)
			_draw_eyes_and_nose(head_center, Color("#261005"))
		1:
			# 1: Explorer Bunny
			var fur_main := Color("#fff6e8")
			var fur_dark := Color("#9c7248")
			var pink := Color("#ff9eb5")
			draw_circle(Vector2(cx - 13.0 * facing_dir, body_y + 7.0), 7.5, fur_dark)
			draw_circle(Vector2(cx - 13.0 * facing_dir, body_y + 7.0), 6.2, Color.WHITE)
			_draw_paws(cx, base_y, leg_swing, fur_dark, fur_main)
			_draw_torso(cx, body_y, fur_main, fur_dark, pink.lightened(0.45))
			for side in [-1.0, 1.0]:
				var ear_base := head_center + Vector2(side * 6.5, -12.0)
				draw_line(ear_base, ear_base + Vector2(side * 3.0 + wag * 0.5, -16.0), fur_dark, 9.0, true)
				draw_line(ear_base, ear_base + Vector2(side * 3.0 + wag * 0.5, -15.5), fur_main, 6.5, true)
				draw_line(ear_base + Vector2(0, -2.0), ear_base + Vector2(side * 2.5 + wag * 0.5, -13.0), pink, 3.2, true)
			draw_circle(head_center, 15.0, fur_dark)
			draw_circle(head_center, 13.5, fur_main)
			draw_circle(head_center + Vector2(-7.0, 3.0), 3.2, pink)
			draw_circle(head_center + Vector2(8.0, 3.0), 3.2, pink)
			_draw_eyes_and_nose(head_center, Color("#ff6b8b"))
		2:
			# 2: Giant Panda
			var black := Color("#23272e")
			var white := Color("#fcfaf5")
			var outline := Color("#454a54")
			_draw_paws(cx, base_y, leg_swing, black)
			_draw_torso(cx, body_y, white, black, white)
			_draw_round_ears(head_center, black, black, 6.5)
			draw_circle(head_center, 15.5, outline)
			draw_circle(head_center, 14.0, white)
			draw_circle(head_center + Vector2(-5.8, -1.2), 5.2, black)
			draw_circle(head_center + Vector2(6.5, -1.2), 5.2, black)
			_draw_eyes_and_nose(head_center, black)
		3:
			# 3: Honey Bear
			var fur_main := Color("#b5632a")
			var fur_dark := Color("#6b3410")
			var muzzle := Color("#ffe3b8")
			draw_circle(Vector2(cx - 12.5 * facing_dir, body_y + 6.0), 6.0, fur_dark)
			_draw_paws(cx, base_y, leg_swing, fur_dark)
			_draw_torso(cx, body_y, fur_main, fur_dark, muzzle)
			_draw_round_ears(head_center, fur_dark, muzzle, 6.5)
			draw_circle(head_center, 15.5, fur_dark)
			draw_circle(head_center, 14.0, fur_main)
			draw_circle(head_center + Vector2(1.0 * facing_dir, 4.0), 6.8, muzzle)
			_draw_eyes_and_nose(head_center, Color("#331606"))
		4:
			# 4: Tiger Cub
			var fur_main := Color("#ff9419")
			var fur_dark := Color("#a84800")
			var cream := Color("#fff2d6")
			var stripe := Color("#2b1405")
			var tail_end := Vector2(cx - 18.0 * facing_dir, body_y - 2.0 + wag * 0.5)
			draw_line(Vector2(cx - 10.0 * facing_dir, body_y + 6.0), tail_end, fur_dark, 6.5, true)
			draw_line(Vector2(cx - 10.0 * facing_dir, body_y + 6.0), tail_end, fur_main, 4.5, true)
			_draw_paws(cx, base_y, leg_swing, fur_dark, cream)
			_draw_torso(cx, body_y, fur_main, fur_dark, cream)
			_draw_round_ears(head_center, fur_dark, cream, 6.2)
			draw_circle(head_center, 15.5, fur_dark)
			draw_circle(head_center, 14.0, fur_main)
			draw_circle(head_center + Vector2(-5.5, 4.5), 6.5, cream)
			draw_circle(head_center + Vector2(6.5, 4.5), 6.5, cream)
			draw_line(head_center + Vector2(0, -13), head_center + Vector2(0, -7), stripe, 2.4, true)
			draw_line(head_center + Vector2(-4, -11), head_center + Vector2(4, -11), stripe, 2.0, true)
			draw_line(head_center + Vector2(-13, 0), head_center + Vector2(-9, 1), stripe, 2.2, true)
			draw_line(head_center + Vector2(9, 1), head_center + Vector2(13, 0), stripe, 2.2, true)
			_draw_eyes_and_nose(head_center, Color("#d94e34"))
		5:
			# 5: Koala
			var fur_main := Color("#8d99a8")
			var fur_dark := Color("#4f5866")
			var cream := Color("#f2f5f8")
			_draw_paws(cx, base_y, leg_swing, fur_dark)
			_draw_torso(cx, body_y, fur_main, fur_dark, cream)
			draw_circle(head_center + Vector2(-14.0, -4.0), 9.5, fur_dark)
			draw_circle(head_center + Vector2(-14.0, -4.0), 8.0, fur_main)
			draw_circle(head_center + Vector2(-14.0, -4.0), 4.8, cream)
			draw_circle(head_center + Vector2(14.0, -4.0), 9.5, fur_dark)
			draw_circle(head_center + Vector2(14.0, -4.0), 8.0, fur_main)
			draw_circle(head_center + Vector2(14.0, -4.0), 4.8, cream)
			draw_circle(head_center, 15.0, fur_dark)
			draw_circle(head_center, 13.8, fur_main)
			_draw_eyes_and_nose(head_center, Color("#262b33"), 4.2)
		6:
			# 6: Tree Frog
			var frog_main := Color("#3bc95b")
			var frog_dark := Color("#177830")
			var belly := Color("#e8ff9e")
			_draw_paws(cx, base_y, leg_swing, frog_dark, frog_main)
			_draw_torso(cx, body_y, frog_main, frog_dark, belly)
			draw_circle(head_center, 15.0, frog_dark)
			draw_circle(head_center, 13.8, frog_main)
			for side in [-1.0, 1.0]:
				var eye_pos := head_center + Vector2(side * 7.0, -12.0)
				draw_circle(eye_pos, 6.8, frog_dark)
				draw_circle(eye_pos, 5.5, frog_main)
				draw_circle(eye_pos, 4.0, Color.WHITE)
				draw_circle(eye_pos + Vector2(0.5, 0), 2.3, Color("#142618"))
				draw_circle(eye_pos + Vector2(-0.5, -1.0), 1.0, Color.WHITE)
			draw_circle(head_center + Vector2(-8.0, 2.5), 3.2, Color("#ff8da1"))
			draw_circle(head_center + Vector2(8.5, 2.5), 3.2, Color("#ff8da1"))
			draw_arc(head_center + Vector2(0.5, 1.5), 6.5, 0.2, PI - 0.2, 12, frog_dark, 2.2, true)
		7:
			# 7: Emperor Penguin
			var navy := Color("#223047")
			var dark_rim := Color("#0f1724")
			var white := Color("#ffffff")
			var beak := Color("#ff9d1c")
			_draw_paws(cx, base_y, leg_swing, beak)
			draw_circle(Vector2(cx - 13.0, body_y + 4.0), 5.5, navy)
			draw_circle(Vector2(cx + 13.0, body_y + 4.0), 5.5, navy)
			_draw_torso(cx, body_y, navy, dark_rim, white)
			draw_circle(head_center, 15.0, dark_rim)
			draw_circle(head_center, 13.8, navy)
			draw_circle(head_center + Vector2(0.5 * facing_dir, 2.0), 10.2, white)
			draw_circle(head_center + Vector2(-7.0, 3.0), 3.0, Color("#ffd166"))
			draw_circle(head_center + Vector2(8.0, 3.0), 3.0, Color("#ffd166"))
			_draw_eyes_and_nose(head_center, beak, 3.4)
		8:
			# 8: Little Lion
			var fur_main := Color("#f7b731")
			var mane_col := Color("#a84312")
			var mane_dark := Color("#692506")
			var cream := Color("#fff3d1")
			var tail_tip := Vector2(cx - 17.0 * facing_dir, body_y + 2.0 + wag * 0.4)
			draw_line(Vector2(cx - 10.0 * facing_dir, body_y + 6.0), tail_tip, mane_dark, 4.0, true)
			draw_circle(tail_tip, 4.5, mane_col)
			_draw_paws(cx, base_y, leg_swing, mane_dark, fur_main)
			_draw_torso(cx, body_y, fur_main, mane_dark, cream)
			for a_i in range(10):
				var ang := float(a_i) * TAU / 10.0
				var m_pos := head_center + Vector2(cos(ang), sin(ang)) * 14.5
				draw_circle(m_pos, 6.5, mane_dark)
				draw_circle(m_pos, 5.2, mane_col)
			draw_circle(head_center, 13.5, fur_main)
			draw_circle(head_center + Vector2(0.5 * facing_dir, 4.0), 6.0, cream)
			_draw_eyes_and_nose(head_center, Color("#4a1d08"))
		9:
			# 9: Spotted Deer / Fawn
			var fur_main := Color("#d4823b")
			var fur_dark := Color("#7d4314")
			var cream := Color("#fff5df")
			var antler := Color("#8c5828")
			draw_circle(Vector2(cx - 13.0 * facing_dir, body_y + 4.0), 6.0, cream)
			_draw_paws(cx, base_y, leg_swing, Color("#3d200a"))
			_draw_torso(cx, body_y, fur_main, fur_dark, cream)
			draw_circle(Vector2(cx - 6.0, body_y + 2.0), 2.2, cream)
			draw_circle(Vector2(cx - 3.0, body_y + 7.0), 2.0, cream)
			for side in [-1.0, 1.0]:
				var ab := head_center + Vector2(side * 5.5, -12.0)
				draw_line(ab, ab + Vector2(side * 4.0, -11.0), antler, 3.2, true)
				draw_line(ab + Vector2(side * 2.0, -6.0), ab + Vector2(side * 7.0, -8.0), antler, 2.6, true)
				draw_circle(head_center + Vector2(side * 13.5, -5.0), 5.0, fur_dark)
				draw_circle(head_center + Vector2(side * 13.5, -5.0), 3.6, fur_main)
			draw_circle(head_center, 14.8, fur_dark)
			draw_circle(head_center, 13.4, fur_main)
			draw_circle(head_center + Vector2(0.5 * facing_dir, 4.0), 6.2, cream)
			_draw_eyes_and_nose(head_center, Color("#2b1406"))
		10:
			# 10: Cheeky Monkey
			var fur_main := Color("#7a441f")
			var fur_dark := Color("#47240c")
			var peach := Color("#ffd9b3")
			var tail_curl := Vector2(cx - 18.0 * facing_dir, body_y - 3.0 + wag * 0.5)
			draw_line(Vector2(cx - 10.0 * facing_dir, body_y + 6.0), tail_curl, fur_dark, 5.0, true)
			draw_circle(tail_curl, 4.0, fur_main)
			_draw_paws(cx, base_y, leg_swing, fur_dark, peach)
			_draw_torso(cx, body_y, fur_main, fur_dark, peach)
			for side in [-1.0, 1.0]:
				draw_circle(head_center + Vector2(side * 14.5, -1.0), 6.5, fur_dark)
				draw_circle(head_center + Vector2(side * 14.5, -1.0), 4.8, peach)
			draw_circle(head_center, 15.0, fur_dark)
			draw_circle(head_center, 13.6, fur_main)
			draw_circle(head_center + Vector2(-3.5, -1.0), 7.5, peach)
			draw_circle(head_center + Vector2(4.5, -1.0), 7.5, peach)
			draw_circle(head_center + Vector2(0.5, 4.2), 7.8, peach)
			_draw_eyes_and_nose(head_center, Color("#3b1c08"))
		_:
			# 11: Wise Owl
			var feather_main := Color("#b86b28")
			var feather_dark := Color("#66350c")
			var cream := Color("#ffefd1")
			var gold := Color("#ffb71b")
			_draw_paws(cx, base_y, leg_swing, gold)
			draw_circle(Vector2(cx - 12.5, body_y + 4.5), 6.5, feather_dark)
			draw_circle(Vector2(cx + 12.5, body_y + 4.5), 6.5, feather_dark)
			_draw_torso(cx, body_y, feather_main, feather_dark, cream)
			_draw_pointy_ears(head_center, feather_dark, feather_main)
			draw_circle(head_center, 15.2, feather_dark)
			draw_circle(head_center, 13.8, feather_main)
			draw_circle(head_center + Vector2(-5.5, -1.2), 6.8, cream)
			draw_circle(head_center + Vector2(6.5, -1.2), 6.8, cream)
			_draw_eyes_and_nose(head_center, gold, 3.0)

func _draw_paws(cx: float, base_y: float, leg_swing: float, col_dark: Color, col_inner: Color = Color(0, 0, 0, 0)) -> void:
	var p1 := Vector2(cx - 7.0 + leg_swing, base_y - 4.0 - jump_height * 0.85)
	var p2 := Vector2(cx + 7.0 - leg_swing, base_y - 4.0 - jump_height * 0.85)
	draw_circle(p1, 5.2, col_dark)
	draw_circle(p2, 5.2, col_dark)
	if col_inner.a > 0.01:
		draw_circle(p1, 3.8, col_inner)
		draw_circle(p2, 3.8, col_inner)

func _draw_torso(cx: float, body_y: float, main: Color, dark: Color, belly: Color) -> void:
	draw_circle(Vector2(cx, body_y + 5.0), 14.0, dark)
	draw_circle(Vector2(cx, body_y + 5.0), 12.5, main)
	draw_circle(Vector2(cx + 1.8 * facing_dir, body_y + 6.2), 7.8, belly)

func _draw_round_ears(head_center: Vector2, outer: Color, inner: Color, radius: float) -> void:
	for side in [-1.0, 1.0]:
		var ep := head_center + Vector2(side * 10.5, -11.5)
		draw_circle(ep, radius, outer)
		draw_circle(ep, radius * 0.58, inner)

func _draw_pointy_ears(head_center: Vector2, outer: Color, inner: Color) -> void:
	var left_ear := PackedVector2Array([
		head_center + Vector2(-12.0, -6.0),
		head_center + Vector2(-16.0, -23.0),
		head_center + Vector2(-3.0, -14.0)
	])
	var right_ear := PackedVector2Array([
		head_center + Vector2(3.0, -14.0),
		head_center + Vector2(16.0, -23.0),
		head_center + Vector2(12.0, -6.0)
	])
	draw_colored_polygon(left_ear, outer)
	draw_colored_polygon(right_ear, outer)
	var left_inner := PackedVector2Array([
		head_center + Vector2(-10.5, -8.0),
		head_center + Vector2(-14.0, -19.0),
		head_center + Vector2(-5.0, -13.0)
	])
	var right_inner := PackedVector2Array([
		head_center + Vector2(5.0, -13.0),
		head_center + Vector2(14.0, -19.0),
		head_center + Vector2(10.5, -8.0)
	])
	draw_colored_polygon(left_inner, inner)
	draw_colored_polygon(right_inner, inner)

func _draw_eyes_and_nose(head_center: Vector2, nose_col: Color, nose_radius: float = 2.6) -> void:
	draw_circle(head_center + Vector2(-5.5, -1.5), 3.2, Color("#1f0e05"))
	draw_circle(head_center + Vector2(6.5, -1.5), 3.2, Color("#1f0e05"))
	draw_circle(head_center + Vector2(-6.3, -2.5), 1.1, Color.WHITE)
	draw_circle(head_center + Vector2(5.7, -2.5), 1.1, Color.WHITE)
	draw_circle(head_center + Vector2(1.0 * facing_dir, 3.5), nose_radius, nose_col)
