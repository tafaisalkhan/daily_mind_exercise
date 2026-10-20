class_name BalanceWeightBall
extends Control

## Reusable 3D colored sphere component with a centered, dynamically scaled number inside.

const PALETTES := [
	[Color("#7a1019"), Color("#e63946"), Color("#ff7582")], # 0: Ruby Red
	[Color("#122a6b"), Color("#2563eb"), Color("#6bb0ff")], # 1: Royal Blue
	[Color("#0b4f35"), Color("#10b981"), Color("#5eead4")], # 2: Emerald Green
	[Color("#3f1678"), Color("#8b5cf6"), Color("#c49bff")], # 3: Amethyst Purple
	[Color("#78280d"), Color("#f97316"), Color("#fdba74")], # 4: Sunset Orange
	[Color("#75123b"), Color("#ec4899"), Color("#f988c5")], # 5: Hot Magenta
	[Color("#6b4009"), Color("#eab308"), Color("#fde047")], # 6: Golden Amber
	[Color("#104457"), Color("#06b6d4"), Color("#67e8f9")], # 7: Turquoise Cyan
	[Color("#7a112f"), Color("#f43f5e"), Color("#fda4af")], # 8: Crimson Coral
	[Color("#26236e"), Color("#6366f1"), Color("#a5b4fc")], # 9: Indigo Violet
	[Color("#1f5114"), Color("#65a30d"), Color("#bef264")], # 10: Lime Peridot
	[Color("#591c4d"), Color("#d946ef"), Color("#f5d0fe")]  # 11: Orchid Fuchsia
]

var number_text: String = "5":
	set(value):
		number_text = value
		if is_instance_valid(num_label):
			num_label.text = value
		queue_redraw()
var color_index: int = 0:
	set(value):
		color_index = value
		queue_redraw()
var is_user_ball: bool = false:
	set(value):
		is_user_ball = value
		queue_redraw()
var num_label: Label

func _ready() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		size = Vector2(62, 62)
	pivot_offset = size * 0.5
	num_label = Label.new()
	num_label.text = number_text
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.add_theme_color_override("font_color", Color("#ffffff"))
	num_label.add_theme_color_override("font_outline_color", Color("#140b04"))
	num_label.add_theme_constant_override("outline_size", 5)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(num_label)
	_sync_num_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		_sync_num_label()
		queue_redraw()

func _sync_num_label() -> void:
	if not is_instance_valid(num_label):
		return
	num_label.position = Vector2.ZERO
	num_label.size = size
	var r := minf(size.x, size.y) * 0.45
	var f_size := clampi(int(round(r * (0.82 if number_text.length() <= 2 else 0.64))), 13, 26)
	num_label.add_theme_font_size_override("font_size", f_size)
	num_label.add_theme_constant_override("outline_size", 4 if f_size < 18 else 5)

func _draw() -> void:
	_sync_num_label()
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	var pal: Array = PALETTES[posmod(color_index, PALETTES.size())]
	var rim_col: Color = pal[0]
	var main_col: Color = pal[1]
	var mid_col: Color = pal[2]
	# Soft contact shadow under the ball
	draw_circle(c + Vector2(0, r * 0.20), r * 0.94, Color(0, 0, 0, 0.34))
	# 3D sphere layers + specular highlight
	draw_circle(c, r, rim_col)
	draw_circle(c + Vector2(0, -r * 0.04), r * 0.89, main_col)
	draw_circle(c + Vector2(-r * 0.14, -r * 0.16), r * 0.62, mid_col)
	draw_circle(c + Vector2(-r * 0.28, -r * 0.30), r * 0.23, Color(1.0, 1.0, 1.0, 0.72))
	draw_arc(c, r * 0.92, 0.0, TAU, 32, Color(1.0, 0.95, 0.75, 0.55), 2.0, true)
