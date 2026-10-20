class_name GridTile
extends Control

signal tile_clicked(tile: GridTile)
signal number_dropped(tile: GridTile, bank_tile: Control)

@export var cell_row: int = 0
@export var cell_col: int = 0
@export var is_empty_slot: bool = false
@export var fixed_value: String = ""
@export var target_value: String = ""

var current_value: String = ""
var is_filled: bool = false
var is_target_selected: bool = false

@onready var panel: Panel = $Panel
@onready var label: Label = $Label
@onready var button: Button = $Button

func setup(data: Dictionary) -> void:
	cell_row = data.get("r", 0)
	cell_col = data.get("c", 0)
	var type_str = data.get("type", "fixed")
	
	if type_str == "empty":
		is_empty_slot = true
		target_value = data.get("target", "")
		current_value = ""
		is_filled = false
	else:
		is_empty_slot = false
		fixed_value = data.get("val", "")
		current_value = fixed_value
		is_filled = true

func _ready() -> void:
	# Visual children must not intercept clicks or drops intended for this tile.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_visuals()

func set_mobile_size(tile_size: float) -> void:
	custom_minimum_size = Vector2(tile_size, tile_size)
	label.add_theme_font_size_override("font_size", clampi(roundi(tile_size * 0.55), 26, 36))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tile_clicked.emit(self)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		is_empty_slot
		and not is_filled
		and data is Dictionary
		and data.get("type", "") == "number_tile"
		and is_instance_valid(data.get("tile"))
		and not data.get("tile").is_used
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		number_dropped.emit(self, data.get("tile"))

func update_visuals() -> void:
	if not is_inside_tree():
		return
		
	if not is_empty_slot:
		# Fixed number or operator tile
		label.text = fixed_value
		label.add_theme_color_override("font_color", Color("#2d2218"))
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#fcefd7") # Cream background
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color("#e5cb9e")
		panel.add_theme_stylebox_override("panel", style)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		if is_filled:
			# Placed number tile by player
			label.text = current_value
			label.add_theme_color_override("font_color", Color("#2d2218"))
			
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#fffaee") # Bright cream
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 3
			style.border_width_bottom = 3
			if current_value == target_value:
				style.bg_color = Color("#effbea")
				style.border_color = Color("#49a451") # Correct: green
			else:
				style.bg_color = Color("#fff0ed")
				style.border_color = Color("#dc5a4f") # Wrong: red
			panel.add_theme_stylebox_override("panel", style)
			mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			# Empty drop slot
			label.text = ""
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#fff1b8") if is_target_selected else Color("#fff8ea")
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			var border_width := 3 if is_target_selected else 1
			style.set_border_width_all(border_width)
			style.border_color = Color("#ffc83d") if is_target_selected else Color("#ebd2ad")
			if is_target_selected:
				style.shadow_color = Color(1.0, 0.78, 0.18, 0.5)
				style.shadow_size = 6
			panel.add_theme_stylebox_override("panel", style)
			mouse_filter = Control.MOUSE_FILTER_STOP

func set_target_selected(selected: bool) -> void:
	is_target_selected = selected
	update_visuals()

func place_value(val: String) -> void:
	if is_empty_slot:
		is_target_selected = false
		current_value = val
		is_filled = true
		update_visuals()

func remove_value() -> String:
	if is_empty_slot and is_filled:
		var removed = current_value
		current_value = ""
		is_filled = false
		update_visuals()
		return removed
	return ""
