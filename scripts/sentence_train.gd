extends Control

const BACK_ICON := preload("res://assets/ui/back-arrow.svg")

const DATA_PATH := "res://assets/data/game_types/sentence_train.json"
const BG_TEXTURE := preload("res://assets/level_backgrounds/sentence-valley.png")
const TRAIN_TEXTURE := preload("res://assets/gameplay_sprites/sentence-train.png")
const STAR_TEXTURE := preload("res://assets/generated/victory-star.png")
const RESULT_EFFECTS = preload("res://scripts/result_effects.gd")
const COIN_TEXTURE := preload("res://assets/generated/reward-coin.png")

# Exact pixel regions in sentence-train.png (2172 x 724)
const LOCO_REGION := Rect2(0, 0, 695, 724)
const CAR_REGIONS := [
	Rect2(690, 0, 368, 724),  # Blue car
	Rect2(1058, 0, 368, 724), # Green car
	Rect2(1426, 0, 368, 724), # Yellow car
	Rect2(1794, 0, 368, 724)  # Red car
]
# Normalized word box placement within each individual 368x724 car slice
const CAR_BOX_NORM := Rect2(0.08, 0.445, 0.84, 0.215)

const CAR_BORDER_COLORS := [
	Color("#1558a6"),
	Color("#1d7b2f"),
	Color("#c27b0e"),
	Color("#ad231c")
]

# Custom Control that draws realistic wooden railway sleepers + steel rails under the train wheels
class RailroadTrack extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Track gravel/ballast shadow bed
		draw_rect(Rect2(0, h * 0.28, w, h * 0.62), Color(0.22, 0.16, 0.11, 0.78))
		draw_rect(Rect2(0, h * 0.34, w, h * 0.48), Color(0.33, 0.24, 0.17, 0.85))

		# Wooden crossties / sleepers
		var tie_spacing := 24.0
		var tie_width := 13.0
		var x := 4.0
		while x < w:
			# Tie shadow
			draw_rect(Rect2(x + 1.0, h * 0.22 + 2.0, tie_width, h * 0.68), Color(0.12, 0.07, 0.03, 0.75))
			# Tie body
			draw_rect(Rect2(x, h * 0.22, tie_width, h * 0.66), Color("#633414"))
			# Tie top highlight
			draw_rect(Rect2(x + 1.5, h * 0.25, tie_width - 3.0, h * 0.22), Color("#8c4f23"))
			x += tie_spacing

		# Back/upper steel rail
		draw_rect(Rect2(0, h * 0.28, w, 5.0), Color("#3b444f"))
		draw_rect(Rect2(0, h * 0.26, w, 3.0), Color("#9aa9b8"))

		# Front/main steel rail directly under the wheels
		draw_rect(Rect2(0, h * 0.56, w, 8.0), Color("#2d353d"))
		draw_rect(Rect2(0, h * 0.50, w, 6.0), Color("#5c6875"))
		draw_rect(Rect2(0, h * 0.47, w, 3.5), Color("#cad6e3"))

		# Iron rail fastener plates on each tie
		x = 4.0
		while x < w:
			draw_rect(Rect2(x + 2.0, h * 0.52, tie_width - 4.0, 5.0), Color("#3a2415"))
			x += tie_spacing

var current_level := 5 # Global level 5 or 6 (local index 0 or 1)
var local_index := 0
var level_data: Dictionary = {}
var answers: Array = []
var choices: Array = []

# Dynamic per-car arrays sized to answers.size() (4 cars in Level 1, 5+ cars in later levels)
var slot_words: Array[String] = []
var slot_buttons: Array[Button] = []

var hearts := 3
var max_errors := 3
var errors_made := 0
var seconds_left := 90
var finished := false
var checking_sequence := false
var train_base_pos := Vector2.ZERO
var loco_width_px := 150.0

# Drag state for dragging word tiles onto train car boxes
var dragging_button: Button = null
var dragging_from_slot: int = -1
var dragging_word: String = ""
var drag_preview: Label = null
var drag_start_pos := Vector2.ZERO
var is_dragging := false
var hovered_slot_index: int = -1

var timer_label: Label
var level_label: Label
var hearts_label: Label
var coins_label: Label
var prompt_label: RichTextLabel
var status_label: Label
var stage_area: Control
var track_control: RailroadTrack
var train_holder: Control
var smoke_layer: Control
var car_slots: Array[Button] = []
var word_tray_box: HFlowContainer
var choice_buttons: Array[Button] = []
var result_panel: PanelContainer
var result_title: Label
var result_stars: HBoxContainer
var next_button: Button
var tick_timer: Timer
var smoke_timer: Timer
var pause_overlay: ColorRect

func _ready() -> void:
	current_level = clampi(GameState.type_level, 1, 1000)
	local_index = current_level - 1
	_build_ui()
	_load_level(local_index)

func _input(event: InputEvent) -> void:
	if dragging_button == null and dragging_from_slot == -1:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var pointer_pos: Vector2 = event.position
		if not is_dragging and pointer_pos.distance_to(drag_start_pos) > 8.0:
			is_dragging = true
			_create_drag_preview(pointer_pos)
		if is_dragging and is_instance_valid(drag_preview):
			drag_preview.global_position = pointer_pos - drag_preview.size * 0.5
			hovered_slot_index = _find_slot_at_point(pointer_pos)
			_refresh_slot_styles()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_pointer_interaction(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_pointer_interaction(event.position)

func _build_ui() -> void:
	# Background (sentence-valley.png)
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BG_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Top Header Bar
	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 14
	header.offset_top = 14
	header.offset_right = -14
	header.offset_bottom = 76
	header.add_theme_constant_override("separation", 8)
	add_child(header)

	var back := Button.new()
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.tooltip_text = "Back"
	back.process_mode = Node.PROCESS_MODE_ALWAYS
	back.custom_minimum_size = Vector2(58, 58)
	back.add_theme_font_size_override("font_size", 36)
	back.add_theme_stylebox_override("normal", _style(Color("#e95545"), Color("#8c211b"), 18))
	back.add_theme_stylebox_override("hover", _style(Color("#ff6b5b"), Color("#8c211b"), 18))
	back.add_theme_stylebox_override("pressed", _style(Color("#c93d2f"), Color("#6b1712"), 18))
	back.pressed.connect(_back)
	header.add_child(back)

	timer_label = _label_panel("⏱ 01:30", Color("#fff0c8"), Color("#193d60"), 22)
	timer_label.custom_minimum_size = Vector2(130, 58)
	header.add_child(timer_label)

	level_label = _label_panel("LEVEL %d" % current_level, Color("#8c4c21"), Color.WHITE, 20)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(level_label)

	hearts_label = _label_panel("♥ ♥ ♥", Color("#fff0c8"), Color("#e62e36"), 25)
	hearts_label.custom_minimum_size = Vector2(118, 58)
	header.add_child(hearts_label)

	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.tooltip_text = "Pause"
	pause.custom_minimum_size = Vector2(58, 58)
	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.add_theme_font_size_override("font_size", 25)
	pause.add_theme_stylebox_override("normal", _style(Color("#f5a31d"), Color("#a34e0c"), 18))
	pause.add_theme_stylebox_override("hover", _style(Color("#ffb73d"), Color("#a34e0c"), 18))
	pause.add_theme_stylebox_override("pressed", _style(Color("#d9880b"), Color("#7d3a07"), 18))
	pause.pressed.connect(_toggle_pause)
	header.add_child(pause)

	# Wooden Instruction Signboard
	var sign_board := PanelContainer.new()
	sign_board.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sign_board.offset_left = 26
	sign_board.offset_top = 88
	sign_board.offset_right = -26
	sign_board.offset_bottom = 212
	sign_board.add_theme_stylebox_override("panel", _wood_sign_style())
	add_child(sign_board)

	var sign_vbox := VBoxContainer.new()
	sign_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sign_vbox.add_theme_constant_override("separation", 4)
	sign_board.add_child(sign_vbox)

	var sign_title := Label.new()
	sign_title.text = "🚂  SENTENCE TRAIN"
	sign_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_title.add_theme_font_size_override("font_size", 22)
	sign_title.add_theme_color_override("font_color", Color("#ffd954"))
	sign_title.add_theme_color_override("font_outline_color", Color("#3b1c08"))
	sign_title.add_theme_constant_override("outline_size", 5)
	sign_vbox.add_child(sign_title)

	prompt_label = RichTextLabel.new()
	prompt_label.bbcode_enabled = true
	prompt_label.fit_content = true
	prompt_label.scroll_active = false
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_theme_font_size_override("normal_font_size", 23)
	prompt_label.add_theme_color_override("default_color", Color.WHITE)
	prompt_label.add_theme_color_override("font_outline_color", Color("#3a1b07"))
	prompt_label.add_theme_constant_override("outline_size", 6)
	sign_vbox.add_child(prompt_label)

	# Interactive Stage Area (Bridge, Track & Dynamic Train)
	stage_area = Control.new()
	stage_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_area.offset_top = 216
	stage_area.offset_bottom = -280
	stage_area.clip_contents = false
	stage_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(stage_area)

	# Railroad Track drawn across the top of the stone bridge under the train wheels
	track_control = RailroadTrack.new()
	track_control.position = Vector2(0, 350)
	track_control.size = Vector2(540, 32)
	track_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_area.add_child(track_control)

	train_holder = Control.new()
	train_holder.size = Vector2(532, 178)
	train_base_pos = Vector2(4, 212)
	train_holder.position = train_base_pos
	stage_area.add_child(train_holder)

	smoke_layer = Control.new()
	smoke_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smoke_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	train_holder.add_child(smoke_layer)

	# Sentence Preview / Status Banner above the wooden word tray
	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_panel.offset_left = 28
	status_panel.offset_top = -258
	status_panel.offset_right = -28
	status_panel.offset_bottom = -204
	status_panel.add_theme_stylebox_override("panel", _style(Color(1.0, 0.96, 0.82, 0.96), Color("#c97c24"), 18))
	add_child(status_panel)

	status_label = Label.new()
	status_label.text = "Drag words onto the train boxes!"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#4a230d"))
	status_panel.add_child(status_label)

	# Wooden Word Tray at Bottom
	var tray_panel := PanelContainer.new()
	tray_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tray_panel.offset_left = 18
	tray_panel.offset_top = -194
	tray_panel.offset_right = -18
	tray_panel.offset_bottom = -84
	tray_panel.add_theme_stylebox_override("panel", _wood_tray_style())
	add_child(tray_panel)

	word_tray_box = HFlowContainer.new()
	word_tray_box.alignment = FlowContainer.ALIGNMENT_CENTER
	word_tray_box.add_theme_constant_override("h_separation", 8)
	word_tray_box.add_theme_constant_override("v_separation", 8)
	tray_panel.add_child(word_tray_box)

	# Bottom Action Bar (Clear, Hint, Coins)
	var bottom_bar := HBoxContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 20
	bottom_bar.offset_top = -72
	bottom_bar.offset_right = -20
	bottom_bar.offset_bottom = -14
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 12)
	add_child(bottom_bar)

	var clear_btn := Button.new()
	clear_btn.text = "↩ CLEAR"
	clear_btn.custom_minimum_size = Vector2(138, 54)
	clear_btn.add_theme_font_size_override("font_size", 18)
	clear_btn.add_theme_color_override("font_color", Color.WHITE)
	clear_btn.add_theme_stylebox_override("normal", _style(Color("#d97724"), Color("#87410b"), 16))
	clear_btn.add_theme_stylebox_override("hover", _style(Color("#ec8932"), Color("#87410b"), 16))
	clear_btn.add_theme_stylebox_override("pressed", _style(Color("#b85f16"), Color("#693106"), 16))
	clear_btn.pressed.connect(_clear_all_slots)
	bottom_bar.add_child(clear_btn)

	var hint_btn := Button.new()
	hint_btn.text = "WATCH AD HINT"
	hint_btn.custom_minimum_size = Vector2(156, 54)
	hint_btn.add_theme_font_size_override("font_size", 18)
	hint_btn.add_theme_color_override("font_color", Color.WHITE)
	hint_btn.add_theme_stylebox_override("normal", _style(Color("#258dcc"), Color("#11517c"), 16))
	hint_btn.add_theme_stylebox_override("hover", _style(Color("#36a2e3"), Color("#11517c"), 16))
	hint_btn.add_theme_stylebox_override("pressed", _style(Color("#1b72a8"), Color("#0c3c5c"), 16))
	hint_btn.pressed.connect(_use_hint)
	bottom_bar.add_child(hint_btn)

	coins_label = _label_panel("🪙 %d" % GameState.coins, Color("#fff2cf"), Color("#4d2512"), 19)
	coins_label.custom_minimum_size = Vector2(138, 54)
	bottom_bar.add_child(coins_label)

	# Pause Overlay
	pause_overlay = ColorRect.new()
	pause_overlay.visible = false
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0, 0, 0, 0.55)
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.z_index = 40
	add_child(pause_overlay)

	var pause_card := PanelContainer.new()
	pause_card.set_anchors_preset(Control.PRESET_CENTER)
	pause_card.offset_left = -160
	pause_card.offset_top = -110
	pause_card.offset_right = 160
	pause_card.offset_bottom = 110
	pause_card.add_theme_stylebox_override("panel", _style(Color("#fff1c8"), Color("#d4851f"), 24))
	pause_overlay.add_child(pause_card)

	var pause_vbox := VBoxContainer.new()
	pause_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_vbox.add_theme_constant_override("separation", 16)
	pause_card.add_child(pause_vbox)

	var pause_title := Label.new()
	pause_title.text = "GAME PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 28)
	pause_title.add_theme_color_override("font_color", Color("#592b11"))
	pause_vbox.add_child(pause_title)

	var resume_btn := Button.new()
	resume_btn.text = "▶ RESUME"
	resume_btn.custom_minimum_size = Vector2(210, 56)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_btn.add_theme_font_size_override("font_size", 20)
	resume_btn.add_theme_stylebox_override("normal", _style(Color("#31aa50"), Color("#12642c"), 18))
	resume_btn.pressed.connect(_toggle_pause)
	pause_vbox.add_child(resume_btn)

	# Victory / Result Popup
	result_panel = PanelContainer.new()
	result_panel.visible = false
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -205
	result_panel.offset_top = -220
	result_panel.offset_right = 205
	result_panel.offset_bottom = 220
	result_panel.z_index = 50
	result_panel.add_theme_stylebox_override("panel", _style(Color("#fff1c8"), Color("#efad28"), 28))
	add_child(result_panel)

	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 16)
	result_panel.add_child(result_box)

	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 28)
	result_title.add_theme_color_override("font_color", Color("#613115"))
	result_box.add_child(result_title)

	result_stars = HBoxContainer.new()
	result_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_child(result_stars)
	for _i in range(3):
		var star := TextureRect.new()
		star.custom_minimum_size = Vector2(76, 76)
		star.texture = STAR_TEXTURE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		result_stars.add_child(star)

	next_button = Button.new()
	next_button.text = "NEXT LEVEL ▶"
	if GameState.game_mode == "daily":
		next_button.text = "BACK TO DAILY"
	next_button.custom_minimum_size = Vector2(250, 62)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.add_theme_font_size_override("font_size", 21)
	next_button.add_theme_stylebox_override("normal", _style(Color("#31aa50"), Color("#12642c"), 18))
	next_button.pressed.connect(_next)
	result_box.add_child(next_button)

	var select_btn := Button.new()
	select_btn.text = "CHOOSE GAME"
	select_btn.custom_minimum_size = Vector2(220, 52)
	select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_btn.add_theme_font_size_override("font_size", 18)
	select_btn.add_theme_stylebox_override("normal", _style(Color("#d98526"), Color("#82490b"), 16))
	select_btn.pressed.connect(_back)
	result_box.add_child(select_btn)

	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.timeout.connect(_tick)
	add_child(tick_timer)

	smoke_timer = Timer.new()
	smoke_timer.wait_time = 0.55
	smoke_timer.timeout.connect(_spawn_smoke_puff)
	add_child(smoke_timer)

# Dynamically builds the Locomotive + N following train car carriages so later levels can add more cars!
func _build_train_cars(car_count: int) -> void:
	for child in train_holder.get_children():
		if child != smoke_layer:
			child.queue_free()
	car_slots.clear()

	var total_width := 532.0
	var loco_ratio := LOCO_REGION.size.x / LOCO_REGION.size.y # ~0.96
	var car_ratio := CAR_REGIONS[0].size.x / CAR_REGIONS[0].size.y # ~0.508
	var total_aspect := loco_ratio + float(car_count) * car_ratio

	# Automatically scale train height so Locomotive + all following cars fit across the bridge track
	var train_h := clampf(total_width / total_aspect, 118.0, 178.0)
	var loco_w := train_h * loco_ratio
	var car_w := train_h * car_ratio
	loco_width_px = loco_w
	var actual_total_w := loco_w + float(car_count) * car_w

	# Keep wheels resting right on top of the railroad track (track top rail is around y = 365 in stage_area)
	var wheel_bottom_y := 366.0
	train_holder.size = Vector2(actual_total_w, train_h)
	train_base_pos = Vector2((540.0 - actual_total_w) * 0.5, wheel_bottom_y - train_h * 0.86)
	train_holder.position = train_base_pos

	# 1. Locomotive Sprite
	var loco_atlas := AtlasTexture.new()
	loco_atlas.atlas = TRAIN_TEXTURE
	loco_atlas.region = LOCO_REGION
	var loco_rect := TextureRect.new()
	loco_rect.position = Vector2.ZERO
	loco_rect.size = Vector2(loco_w, train_h)
	loco_rect.texture = loco_atlas
	loco_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loco_rect.stretch_mode = TextureRect.STRETCH_SCALE
	loco_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	train_holder.add_child(loco_rect)

	# 2. Following Train Cars (car_count cars)
	for i in range(car_count):
		var car_x := loco_w + float(i) * car_w
		var car_atlas := AtlasTexture.new()
		car_atlas.atlas = TRAIN_TEXTURE
		car_atlas.region = CAR_REGIONS[i % CAR_REGIONS.size()]

		var car_rect := TextureRect.new()
		car_rect.position = Vector2(car_x, 0.0)
		car_rect.size = Vector2(car_w, train_h)
		car_rect.texture = car_atlas
		car_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		car_rect.stretch_mode = TextureRect.STRETCH_SCALE
		car_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		train_holder.add_child(car_rect)

		# Word box plaque on this train car (steady — no up/down scaling!)
		var slot := Button.new()
		slot.position = Vector2(
			car_x + CAR_BOX_NORM.position.x * car_w,
			CAR_BOX_NORM.position.y * train_h
		)
		slot.size = Vector2(
			CAR_BOX_NORM.size.x * car_w,
			CAR_BOX_NORM.size.y * train_h
		)
		slot.pivot_offset = slot.size * 0.5
		slot.clip_contents = true
		slot.add_theme_font_size_override("font_size", 15 if car_count <= 4 else 13)
		slot.add_theme_color_override("font_color", Color("#3b1e0a"))
		slot.add_theme_color_override("font_hover_color", Color("#3b1e0a"))
		slot.add_theme_color_override("font_pressed_color", Color("#3b1e0a"))
		slot.add_theme_color_override("font_disabled_color", Color("#2a1405"))
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		train_holder.add_child(slot)
		car_slots.append(slot)

func _load_level(idx: int) -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not load " + DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var levels: Array = parsed.get("levels", [])
	if levels.is_empty():
		return
	local_index = clampi(idx, 0, levels.size() - 1)
	current_level = local_index + 1
	level_data = levels[local_index]
	answers = level_data.get("answers", []).duplicate()
	choices = level_data.get("choices", []).duplicate()
	if choices == answers and choices.size() > 1:
		choices.shuffle()

	var car_count := answers.size()
	slot_words.clear()
	slot_buttons.clear()
	for _i in range(car_count):
		slot_words.append("")
		slot_buttons.append(null)

	hearts = 3
	errors_made = 0
	seconds_left = int(level_data.get("time", 90))
	finished = false
	checking_sequence = false
	_cancel_drag()
	result_panel.visible = false
	pause_overlay.visible = false

	level_label.text = "LEVEL %d" % current_level
	hearts_label.text = "♥ ♥ ♥"
	coins_label.text = "🪙 %d" % GameState.coins
	_update_timer_label()
	prompt_label.text = "[center]%s[/center]" % str(level_data.get("prompt", ""))

	_build_train_cars(car_count)
	train_holder.remove_meta("driving")
	_refresh_slot_styles()
	_rebuild_word_tray()
	_update_status_text()

	tick_timer.start()
	smoke_timer.start()

func _rebuild_word_tray() -> void:
	for child in word_tray_box.get_children():
		child.queue_free()
	choice_buttons.clear()

	var tile_w := 112.0 if choices.size() <= 4 else 90.0
	var tile_h := 70.0 if choices.size() <= 4 else 64.0
	for word_val in choices:
		var word := str(word_val)
		var btn := Button.new()
		btn.text = word
		btn.custom_minimum_size = Vector2(tile_w, tile_h)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pivot_offset = btn.custom_minimum_size * 0.5
		btn.add_theme_font_size_override("font_size", 20 if word.length() <= 6 else 16)
		btn.add_theme_color_override("font_color", Color("#2e1608"))
		btn.add_theme_color_override("font_hover_color", Color("#1b0c04"))
		btn.add_theme_color_override("font_pressed_color", Color("#2e1608"))
		btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.25, 0.15, 0.25))
		btn.add_theme_stylebox_override("normal", _word_tile_style(Color("#f8e2b0"), Color("#b56c25"), 6))
		btn.add_theme_stylebox_override("hover", _word_tile_style(Color("#fff0cc"), Color("#cc7e2e"), 7))
		btn.add_theme_stylebox_override("pressed", _word_tile_style(Color("#ebd094"), Color("#99581a"), 2))
		btn.add_theme_stylebox_override("disabled", _word_tile_style(Color(0.88, 0.80, 0.65, 0.35), Color(0.55, 0.38, 0.2, 0.25), 0))
		btn.gui_input.connect(_on_tray_button_gui_input.bind(btn, word))
		word_tray_box.add_child(btn)
		choice_buttons.append(btn)

func _on_tray_button_gui_input(event: InputEvent, button: Button, word: String) -> void:
	if finished or checking_sequence or button.disabled:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = button
		dragging_from_slot = -1
		dragging_word = word
		drag_start_pos = get_viewport().get_mouse_position()
		is_dragging = false
		hovered_slot_index = -1

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if finished or checking_sequence:
		return
	if slot_idx < 0 or slot_idx >= slot_words.size() or slot_words[slot_idx] == "":
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		dragging_button = slot_buttons[slot_idx]
		dragging_from_slot = slot_idx
		dragging_word = slot_words[slot_idx]
		drag_start_pos = get_viewport().get_mouse_position()
		is_dragging = false
		hovered_slot_index = -1

func _create_drag_preview(pointer_pos: Vector2) -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	if dragging_from_slot >= 0 and dragging_from_slot < car_slots.size():
		car_slots[dragging_from_slot].text = ""
	elif is_instance_valid(dragging_button):
		dragging_button.modulate.a = 0.35

	drag_preview = Label.new()
	drag_preview.text = dragging_word
	drag_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drag_preview.size = Vector2(104, 52)
	drag_preview.global_position = pointer_pos - drag_preview.size * 0.5
	drag_preview.z_index = 60
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_theme_font_size_override("font_size", 19)
	drag_preview.add_theme_color_override("font_color", Color("#2e1608"))
	drag_preview.add_theme_stylebox_override("normal", _word_tile_style(Color("#fff4d2"), Color("#e08b26"), 6))
	add_child(drag_preview)

func _finish_pointer_interaction(release_pos: Vector2) -> void:
	var btn := dragging_button
	var from_slot := dragging_from_slot
	var word := dragging_word
	var was_dragging := is_dragging
	_cancel_drag()

	if finished or checking_sequence:
		return

	if was_dragging:
		var target_slot := _find_slot_at_point(release_pos)
		if target_slot >= 0:
			_place_word_in_slot(target_slot, word, btn, from_slot)
		elif from_slot >= 0:
			_remove_word_from_slot(from_slot)
			AudioManager.play_undo()
		else:
			if is_instance_valid(btn):
				btn.modulate = Color.WHITE
			_refresh_slot_styles()
	else:
		if from_slot >= 0:
			_remove_word_from_slot(from_slot)
			AudioManager.play_undo()
		elif is_instance_valid(btn):
			var empty_slot := _first_empty_slot()
			if empty_slot >= 0:
				_place_word_in_slot(empty_slot, word, btn, -1)

func _cancel_drag() -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	if is_instance_valid(dragging_button) and not dragging_button.disabled:
		dragging_button.modulate = Color.WHITE
	dragging_button = null
	dragging_from_slot = -1
	dragging_word = ""
	is_dragging = false
	hovered_slot_index = -1
	_refresh_slot_styles()

func _find_slot_at_point(screen_pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := 90.0
	for i in range(car_slots.size()):
		var slot := car_slots[i]
		if not is_instance_valid(slot) or not slot.visible:
			continue
		var rect := slot.get_global_rect().grow(12.0)
		if rect.has_point(screen_pos):
			return i
		var dist := rect.get_center().distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

func _first_empty_slot() -> int:
	for i in range(slot_words.size()):
		if slot_words[i] == "":
			return i
	return -1

func _place_word_in_slot(target_slot: int, word: String, source_btn: Button, from_slot: int) -> void:
	if target_slot < 0 or target_slot >= slot_words.size():
		return
	if from_slot == target_slot:
		_refresh_slot_styles()
		return

	var existing_word := slot_words[target_slot]
	var existing_btn := slot_buttons[target_slot]

	if from_slot >= 0:
		slot_words[from_slot] = existing_word
		slot_buttons[from_slot] = existing_btn
	else:
		if existing_word != "" and is_instance_valid(existing_btn):
			existing_btn.disabled = false
			existing_btn.modulate = Color.WHITE

	slot_words[target_slot] = word
	slot_buttons[target_slot] = source_btn
	if is_instance_valid(source_btn):
		source_btn.disabled = true
		source_btn.modulate = Color(1, 1, 1, 0.35)

	AudioManager.play_place(true)
	_refresh_slot_styles()
	_update_status_text()

	# Check full sentence once all train boxes are filled
	if _first_empty_slot() == -1:
		_evaluate_full_train_sequence()

func _remove_word_from_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= slot_words.size():
		return
	var btn := slot_buttons[slot_idx]
	if is_instance_valid(btn):
		btn.disabled = false
		btn.modulate = Color.WHITE
	slot_words[slot_idx] = ""
	slot_buttons[slot_idx] = null
	_refresh_slot_styles()
	_update_status_text()

func _clear_all_slots() -> void:
	if finished or checking_sequence:
		return
	var had_any := false
	for i in range(slot_words.size()):
		if slot_words[i] != "":
			had_any = true
			_remove_word_from_slot(i)
	if had_any:
		AudioManager.play_undo()

func _evaluate_full_train_sequence() -> void:
	checking_sequence = true
	var is_correct := true
	for i in range(answers.size()):
		if slot_words[i] != str(answers[i]):
			is_correct = false
			break

	if is_correct:
		finished = true
		tick_timer.stop()
		for i in range(car_slots.size()):
			car_slots[i].add_theme_stylebox_override("normal", _car_slot_result_style(Color("#2ea843")))
		status_label.text = "✓ Correct! \"" + " ".join(slot_words) + "\" — Train is running!"
		AudioManager.play_place(true)
		await get_tree().create_timer(0.35).timeout
		await _animate_train_running()
		_complete_level()
	else:
		errors_made += 1
		hearts = maxi(0, max_errors - errors_made)
		hearts_label.text = " ".join(["♥", "♥", "♥"].slice(0, hearts))
		AudioManager.play_place(false)

		for i in range(car_slots.size()):
			var slot_ok := (slot_words[i] == str(answers[i]))
			car_slots[i].add_theme_stylebox_override(
				"normal",
				_car_slot_result_style(Color("#2ea843") if slot_ok else Color("#d93829"))
			)

		status_label.text = "Wrong sequence! (%d / %d errors)" % [errors_made, max_errors]

		var origin_x := train_base_pos.x
		var shake := create_tween()
		shake.tween_property(train_holder, "position:x", origin_x - 14.0, 0.06)
		shake.tween_property(train_holder, "position:x", origin_x + 14.0, 0.06)
		shake.tween_property(train_holder, "position:x", origin_x - 10.0, 0.06)
		shake.tween_property(train_holder, "position:x", origin_x + 10.0, 0.06)
		shake.tween_property(train_holder, "position:x", origin_x, 0.06)
		await shake.finished
		await get_tree().create_timer(0.45).timeout

		if errors_made >= max_errors or hearts <= 0:
			checking_sequence = false
			_fail_level("3 ERRORS — LEVEL FAILED!")
			return

		for i in range(answers.size()):
			if slot_words[i] != str(answers[i]):
				_remove_word_from_slot(i)
		checking_sequence = false
		_refresh_slot_styles()
		status_label.text = "Fix the remaining train boxes! (%d ♥ left)" % hearts

func _refresh_slot_styles() -> void:
	for i in range(car_slots.size()):
		var slot := car_slots[i]
		if not is_instance_valid(slot):
			continue
		slot.scale = Vector2.ONE
		var filled := i < slot_words.size() and slot_words[i] != ""
		slot.text = slot_words[i] if filled else ""
		var is_hovered := (i == hovered_slot_index)
		var border_col: Color = CAR_BORDER_COLORS[i % CAR_BORDER_COLORS.size()]
		var style := _car_slot_style(border_col, is_hovered, filled)
		slot.add_theme_stylebox_override("normal", style)
		slot.add_theme_stylebox_override("hover", style)
		slot.add_theme_stylebox_override("pressed", style)

func _use_hint() -> void:
	if finished or checking_sequence or _first_empty_slot() == -1:
		return
	AdManager.request_rewarded_hint(Callable(self, "_grant_hint"), Callable(self, "_hint_unavailable"))

func _hint_unavailable(message: String) -> void:
	status_label.text = message

func _grant_hint() -> void:
	if finished or checking_sequence:
		return
	var target_slot := _first_empty_slot()
	if target_slot == -1:
		return
	AudioManager.play_hint()

	var target_word := str(answers[target_slot])
	for i in range(slot_words.size()):
		if slot_words[i] == target_word and i != target_slot:
			_remove_word_from_slot(i)
			break

	for btn in choice_buttons:
		if is_instance_valid(btn) and not btn.disabled and btn.text == target_word:
			_place_word_in_slot(target_slot, target_word, btn, -1)
			break

func _update_status_text() -> void:
	var parts: Array[String] = []
	var any_filled := false
	for i in range(slot_words.size()):
		if slot_words[i] != "":
			parts.append(slot_words[i])
			any_filled = true
		else:
			parts.append("[Box %d]" % (i + 1))
	if not any_filled:
		status_label.text = "Drag words into the %d train boxes!" % slot_words.size()
	else:
		status_label.text = "  ".join(parts)

func _spawn_smoke_puff() -> void:
	if not is_instance_valid(smoke_layer) or get_tree().paused:
		return
	var puff := Panel.new()
	var puff_size := randf_range(16.0, 26.0)
	puff.size = Vector2(puff_size, puff_size)
	puff.position = Vector2(
		loco_width_px * 0.28 + randf_range(-5.0, 5.0),
		train_holder.size.y * 0.08
	)
	var puff_style := StyleBoxFlat.new()
	puff_style.bg_color = Color(1.0, 1.0, 1.0, 0.82)
	puff_style.set_corner_radius_all(int(puff_size))
	puff.add_theme_stylebox_override("panel", puff_style)
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smoke_layer.add_child(puff)

	var drift := Vector2(randf_range(14.0, 36.0), randf_range(-52.0, -32.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(puff, "position", puff.position + drift, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector2(1.6, 1.6), 0.85)
	tween.tween_property(puff, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(puff.queue_free)

func _animate_train_running() -> void:
	if not is_instance_valid(train_holder):
		return
	train_holder.set_meta("driving", true)
	smoke_timer.wait_time = 0.14
	for _i in range(5):
		_spawn_smoke_puff()
	var tween := create_tween()
	tween.tween_property(train_holder, "position:x", train_base_pos.x + 22.0, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(train_holder, "position:x", -train_holder.size.x - 80.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

func _tick() -> void:
	if finished:
		return
	seconds_left -= 1
	_update_timer_label()
	if seconds_left <= 0:
		_fail_level("TIME'S UP — LEVEL FAILED!")

func _update_timer_label() -> void:
	timer_label.text = "⏱ %02d:%02d" % [maxi(0, seconds_left) / 60, maxi(0, seconds_left) % 60]

func _complete_level() -> void:
	finished = true
	checking_sequence = false
	tick_timer.stop()
	smoke_timer.stop()
	var stars := 3
	var reward := stars * 5
	GameState.register_game_type_win(2, current_level, stars, reward)
	coins_label.text = "🪙 %d" % GameState.coins
	result_title.text = "SENTENCE COMPLETE!\n+%d COINS" % reward
	result_stars.visible = true
	for idx in range(result_stars.get_child_count()):
		result_stars.get_child(idx).modulate = Color.WHITE if idx < stars else Color(0.2, 0.2, 0.2, 0.25)
	next_button.text = "NEXT LEVEL ▶"
	result_panel.visible = true
	result_panel.scale = Vector2(0.6, 0.6)
	result_panel.pivot_offset = result_panel.size * 0.5
	var tween := create_tween()
	tween.tween_property(result_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_victory()
	RESULT_EFFECTS.celebrate(self, result_stars, stars, coins_label.global_position + coins_label.size * 0.5)
	tween.tween_interval(1.25)
	tween.tween_callback(AdManager.show_interstitial)

func _fail_level(reason: String = "LEVEL FAILED!") -> void:
	finished = true
	checking_sequence = false
	_cancel_drag()
	tick_timer.stop()
	smoke_timer.stop()
	result_title.text = reason
	result_stars.visible = false
	AudioManager.play_level_fail()
	for star in result_stars.get_children():
		star.modulate = Color(0.2, 0.2, 0.2, 0.25)
	next_button.text = "RETRY"
	result_panel.visible = true

func _next() -> void:
	if next_button.text == "RETRY":
		_load_level(local_index)
		return
	if GameState.game_mode == "daily":
		get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn")
		return
	GameState.type_level = GameState.next_game_type_level(2)
	_load_level(GameState.type_level - 1)

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = get_tree().paused

func _back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/daily_challenge.tscn" if GameState.game_mode == "daily" else "res://scenes/game_type_select.tscn")

func _label_panel(value: String, background: Color, foreground: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", foreground)
	label.add_theme_stylebox_override("normal", _style(background, Color("#95501d"), 17))
	return label

func _wood_sign_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#8f4c1e")
	style.border_color = Color("#4d2409")
	style.set_border_width_all(5)
	style.set_corner_radius_all(22)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 5)
	return style

func _wood_tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#8d491c")
	style.border_color = Color("#4e2408")
	style.set_border_width_all(5)
	style.set_corner_radius_all(22)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	return style

func _word_tile_style(fill: Color, border: Color, shadow_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = maxi(2, shadow_y + 1)
	style.shadow_offset = Vector2(0, shadow_y)
	return style

func _car_slot_style(border_color: Color, hovered: bool, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if filled:
		style.bg_color = Color("#fff5d6")
		style.border_color = border_color.darkened(0.15)
		style.set_border_width_all(3)
	elif hovered:
		style.bg_color = Color(1.0, 0.96, 0.78, 0.98)
		style.border_color = Color("#ffd83b")
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.98, 0.91, 0.72, 0.92)
		style.border_color = border_color
		style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style

func _car_slot_result_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = border_color.lightened(0.75)
	style.border_color = border_color
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style
