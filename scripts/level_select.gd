extends Control

const BACK_ICON := preload("res://assets/ui/back-arrow.svg")

const WORLD_NAMES := ["JUNGLE", "ICE LAND", "OCEAN", "MOUNTAIN", "VOLCANO"]
const WORLD_BACKGROUNDS := ["res://assets/generated/world-jungle.png", "res://assets/generated/world-ice.png", "res://assets/generated/world-ocean.png", "res://assets/generated/world-mountain.png", "res://assets/generated/world-volcano.png"]
const WORLD_COLORS := [Color("#20a65a"), Color("#42aee8"), Color("#087fba"), Color("#637c58"), Color("#e45128")]

@onready var worlds: HBoxContainer = $SafeArea/Layout/Scroll/Worlds

var selection_made: bool = false

func _ready() -> void:
	var back: Button = $SafeArea/Layout/Header/BackButton
	back.text = ""
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.pressed.connect(_go_back)
	worlds.add_child(_carousel_spacer())
	for world_index in range(WORLD_NAMES.size()):
		worlds.add_child(_create_world_card(world_index))
	worlds.add_child(_carousel_spacer())
	_scroll_to_progress.call_deferred()
	_enable_level_selection_after_open.call_deferred()
	_auto_start_remembered_level.call_deferred()

func _auto_start_remembered_level() -> void:
	await get_tree().create_timer(5.0).timeout
	if selection_made or not is_inside_tree():
		return
	selection_made = true
	GameState.start_selected_level(GameState.requested_level)
	get_tree().change_scene_to_file("res://scenes/game_type_level.tscn")

func _enable_level_selection_after_open() -> void:
	await get_tree().create_timer(0.45).timeout
	for child in worlds.get_children():
		if child is Button:
			child.disabled = not bool(child.get_meta("world_unlocked", false))

func _carousel_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(42, 1)
	return spacer

func _create_world_card(world_index: int) -> Button:
	var first_level := world_index * 200 + 1
	var completed := clampi(GameState.highest_level - first_level, 0, 200)
	var unlocked := GameState.highest_level >= first_level
	var card := Button.new()
	card.custom_minimum_size = Vector2(380, 620)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.clip_contents = true
	card.disabled = true
	card.set_meta("world_unlocked", unlocked)
	card.add_theme_stylebox_override("normal", _card_style(WORLD_COLORS[world_index]))
	card.add_theme_stylebox_override("hover", _card_style(WORLD_COLORS[world_index].lightened(0.12)))
	card.add_theme_stylebox_override("pressed", _card_style(WORLD_COLORS[world_index].darkened(0.12)))
	card.add_theme_stylebox_override("disabled", _card_style(Color("#555957")))
	card.pressed.connect(_open_world.bind(world_index))
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(WORLD_BACKGROUNDS[world_index])
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color.WHITE if unlocked else Color(0.42, 0.42, 0.42, 1)
	card.add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.2 if unlocked else 0.52)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	var locked_overlay := Label.new()
	locked_overlay.set_anchors_preset(Control.PRESET_CENTER)
	locked_overlay.offset_left = -125
	locked_overlay.offset_top = -52
	locked_overlay.offset_right = 125
	locked_overlay.offset_bottom = 52
	locked_overlay.text = "LOCKED"
	locked_overlay.visible = not unlocked
	locked_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	locked_overlay.add_theme_font_size_override("font_size", 42)
	locked_overlay.add_theme_color_override("font_color", Color.WHITE)
	locked_overlay.add_theme_color_override("font_shadow_color", Color.BLACK)
	locked_overlay.add_theme_constant_override("shadow_offset_x", 4)
	locked_overlay.add_theme_constant_override("shadow_offset_y", 5)
	locked_overlay.add_theme_stylebox_override("normal", _locked_overlay_style())
	locked_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(locked_overlay)
	var lock_icon := TextureRect.new()
	lock_icon.set_anchors_preset(Control.PRESET_CENTER)
	lock_icon.offset_left = -66
	lock_icon.offset_top = -172
	lock_icon.offset_right = 66
	lock_icon.offset_bottom = -16
	lock_icon.texture = load("res://assets/generated/lock-icon.svg")
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.visible = not unlocked
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lock_icon)
	_add_letter_pattern(card, world_index, unlocked, clampi(completed + 1, 1, 200))
	var name_label := Label.new()
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 18
	name_label.offset_top = 22
	name_label.offset_right = -18
	name_label.offset_bottom = 84
	name_label.text = WORLD_NAMES[world_index] if unlocked else "🔒  " + WORLD_NAMES[world_index]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 4)
	name_label.add_theme_constant_override("shadow_offset_y", 5)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	var status := Label.new()
	status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 18
	status.offset_top = -78
	status.offset_right = 178
	status.offset_bottom = -20
	status.text = "UNLOCKED" if unlocked else "🔒  LOCKED"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 3)
	status.add_theme_stylebox_override("normal", _status_style(WORLD_COLORS[world_index], unlocked))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(status)
	var progress := Label.new()
	progress.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	progress.offset_left = -138
	progress.offset_top = -78
	progress.offset_right = -18
	progress.offset_bottom = -20
	progress.text = "%d/200" % completed
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 30)
	progress.add_theme_color_override("font_color", Color.WHITE)
	progress.add_theme_color_override("font_shadow_color", Color.BLACK)
	progress.add_theme_constant_override("shadow_offset_x", 3)
	progress.add_theme_constant_override("shadow_offset_y", 4)
	progress.add_theme_stylebox_override("normal", _progress_style(WORLD_COLORS[world_index]))
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(progress)
	return card

func _add_letter_pattern(card: Control, world_index: int, unlocked: bool, _level_number: int) -> void:
	var patterns := [
		["11111", "00010", "00010", "10010", "01100"],
		["11111", "00100", "00100", "00100", "11111"],
		["01110", "10001", "10001", "10001", "01110"],
		["10001", "11011", "10101", "10001", "10001"],
		["10001", "10001", "10001", "01010", "00100"]
	]
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.offset_left = -95
	holder.offset_top = -142
	holder.offset_right = 95
	holder.offset_bottom = 142
	holder.visible = unlocked
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(holder)
	var tile_size := 30.0
	var gap := 6.0
	for row in range(5):
		for column in range(5):
			if patterns[world_index][row][column] != "1":
				continue
			var tile := Panel.new()
			tile.position = Vector2(8 + column * (tile_size + gap), row * (tile_size + gap))
			tile.size = Vector2(tile_size, tile_size)
			tile.add_theme_stylebox_override("panel", _pattern_tile_style(WORLD_COLORS[world_index]))
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(tile)

func _pattern_tile_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff4cf")
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 4
	return style
func _locked_overlay_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.08, 0.92)
	style.border_color = Color("#d9b34b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	return style
func _level_placeholder_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff4cf")
	style.border_color = color
	style.set_border_width_all(6)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	return style
func _preview_tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff4cf")
	style.border_color = Color("#d9b34b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 5
	return style
func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.34)
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	return style

func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.94)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style

func _status_style(color: Color, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.95) if unlocked else Color(0.2, 0.22, 0.21, 0.95)
	style.border_color = Color.WHITE if unlocked else Color("#8f9691")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style
func _open_world(world_index: int) -> void:
	if selection_made:
		return
	selection_made = true
	var first_level := world_index * 200 + 1
	var next_level := clampi(GameState.highest_level, first_level, first_level + 199)
	GameState.start_selected_level(next_level)
	get_tree().change_scene_to_file("res://scenes/game_type_level.tscn")

func _go_back() -> void:
	selection_made = true
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _scroll_to_progress() -> void:
	# Always open on the first world; swipe horizontally for the others.
	$SafeArea/Layout/Scroll.scroll_horizontal = 0
