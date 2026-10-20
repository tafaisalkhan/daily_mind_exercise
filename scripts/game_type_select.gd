extends Control

const BACK_ICON := preload("res://assets/ui/back-arrow.svg")

const DISPLAY_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

const TYPE_FILES := [
	"res://assets/data/game_types/synonyms.json",
	"res://assets/data/game_types/word_builder.json",
	"res://assets/data/game_types/sentence_train.json",
	"res://assets/data/game_types/number_bridge.json",
	"res://assets/data/game_types/number_balance.json",
	"res://assets/data/game_types/number_maze.json",
	"res://assets/data/game_types/number_hunt.json",
	"res://assets/data/game_types/word_relay.json"
]
const TYPE_SUBTITLES := [
	"Find matching words",
	"Check spelling and word forms",
	"Arrange the sentence",
	"Complete patterns",
	"Solve the equation",
	"Follow number rules",
	"Solve clues and catch numbers",
	"Change one letter"
]

func _ready() -> void:
	_build_screen()

func _build_screen() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/generated/daily-mind-owl-menu-background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.14, 0.34)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72
	layout.add_child(header)
	var back := Button.new()
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(62, 62)
	back.add_theme_font_size_override("font_size", 36)
	back.add_theme_color_override("font_color", Color("#142442"))
	back.add_theme_color_override("font_hover_color", Color("#142442"))
	back.add_theme_stylebox_override("normal", _button_style(Color("#79eadc"), Color("#27aeb4")))
	back.add_theme_stylebox_override("hover", _button_style(Color("#a2f5e9"), Color("#27aeb4")))
	back.add_theme_stylebox_override("pressed", _button_style(Color("#5bc9c4"), Color("#27aeb4")))
	back.pressed.connect(_back)
	header.add_child(back)
	var title := Label.new()
	title.text = "CHOOSE YOUR GAME"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#fff8ed"))
	title.add_theme_color_override("font_shadow_color", Color("#111344"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	header.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 62
	header.add_child(spacer)

	var subtitle := Label.new()
	subtitle.text = "PICK A CHALLENGE AND KEEP YOUR STREAK GOING"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#a9f5e3"))
	layout.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	for index in range(TYPE_FILES.size()):
		if index == 5:
			continue
		var data := _load_type(TYPE_FILES[index])
		if data.is_empty():
			continue
		grid.add_child(_create_card(index, data))

func _load_type(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _create_card(index: int, data: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(238, 248)
	card.add_theme_stylebox_override("normal", _card_style(Color("#17245e"), Color("#76e4df")))
	card.add_theme_stylebox_override("hover", _card_style(Color("#263779"), Color("#a1f4e7")))
	card.add_theme_stylebox_override("pressed", _card_style(Color("#303477"), Color("#ff9b82")))
	card.add_theme_stylebox_override("focus", _card_style(Color("#263779"), Color("#ffd477")))
	card.pressed.connect(_play_type.bind(index))

	var image_panel := ColorRect.new()
	image_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	image_panel.offset_left = 5
	image_panel.offset_top = 5
	image_panel.offset_right = -5
	image_panel.offset_bottom = 153
	image_panel.color = Color("#2a3980")
	image_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image_panel)

	var image := TextureRect.new()
	image.set_anchors_preset(Control.PRESET_TOP_WIDE)
	image.offset_left = 12
	image.offset_top = 9
	image.offset_right = -12
	image.offset_bottom = 149
	image.texture = load(str(data["sprite"]))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image)

	var name := Label.new()
	name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name.offset_left = 9
	name.offset_top = -91
	name.offset_right = -9
	name.offset_bottom = -62
	name.text = str(data["title"]).to_upper()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", DISPLAY_FONT)
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color("#fff3d8"))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name)

	var description := Label.new()
	description.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	description.offset_left = 10
	description.offset_top = -62
	description.offset_right = -10
	description.offset_bottom = -30
	description.text = TYPE_SUBTITLES[index]
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color("#e5eafa"))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(description)

	var level_count := Label.new()
	level_count.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	level_count.offset_left = 10
	level_count.offset_top = -28
	level_count.offset_right = -10
	level_count.offset_bottom = -8
	var next_level := GameState.game_type_progress[index]
	level_count.text = "1000/1000 COMPLETE" if next_level > 1000 else "LEVEL %d / 1000" % next_level
	level_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_count.add_theme_font_size_override("font_size", 12)
	level_count.add_theme_color_override("font_color", Color("#8ce9dc"))
	level_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(level_count)
	return card

func _play_type(index: int) -> void:
	if index == 5:
		return
	GameState.start_game_type(index)
	if index == 0:
		get_tree().change_scene_to_file("res://scenes/balloon_match.tscn")
	elif index == 2:
		get_tree().change_scene_to_file("res://scenes/sentence_train.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_type_level.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(19)
	style.shadow_color = Color(0.01, 0.01, 0.12, 0.5)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 5)
	return style

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _card_style(fill, border)
	style.set_corner_radius_all(18)
	return style

