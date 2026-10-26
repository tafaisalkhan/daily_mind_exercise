extends Control

const DISPLAY_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BACK_ICON := preload("res://assets/ui/back-arrow.svg")
const BACKGROUND := preload("res://assets/generated/daily-mind-owl-menu-background.png")
const TYPE_NAMES := ["BALLOON MATCH", "BUILD WORDS", "SENTENCE TRAIN", "NUMBER BRIDGE", "BALANCE THE SCALE", "NUMBER MAZE", "NUMBER HUNTER", "WORD RELAY", "BIRD PARADE", "BIRD CATCH BUGS"]
const MONTH_NAMES := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

var _month: int
var _year: int
var _month_label: Label
var _calendar_grid: GridContainer
var _steps_row: HBoxContainer
var _tasks_panel: VBoxContainer
var _instruction: Label
var _today_label: Label

func _ready() -> void:
	var prev_mode := GameState.game_mode
	var prev_task_index := GameState.daily_task_index
	var prev_date := GameState.daily_date

	GameState.open_daily()
	var today_str := GameState.today_key()
	var date := Time.get_date_dict_from_system()
	_month = date.month
	_year = date.year
	_build_screen()
	_show_today_tasks()

	# Auto-advance from Exercise 1 -> 2 -> 3 when returning right after completing the previous exercise
	if prev_mode == "daily" and prev_date == today_str and prev_task_index >= 0 and prev_task_index < 2:
		var flags: Array = GameState.daily_history.get(today_str, [false, false, false])
		if bool(flags[prev_task_index]) and not bool(flags[prev_task_index + 1]):
			_instruction.text = "EXERCISE %d COMPLETE! STARTING EXERCISE %d..." % [prev_task_index + 1, prev_task_index + 2]
			call_deferred("_start_task", prev_task_index + 1)

func _build_screen() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.13, 0.60)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var back := Button.new()
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(58, 58)
	back.add_theme_font_size_override("font_size", 34)
	back.add_theme_stylebox_override("normal", _style(Color("#79eadc"), Color("#27aeb4")))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	header.add_child(back)
	var title := Label.new()
	title.text = "DAILY EXERCISE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#fff5df"))
	header.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 58
	header.add_child(spacer)

	var done_count := GameState.daily_completed_count(GameState.today_key())
	_today_label = Label.new()
	_today_label.text = "%s  •  %s" % [GameState.today_key(), "✓ COMPLETE (3 / 3)" if done_count == 3 else "%d / 3 COMPLETED" % done_count]
	_today_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_today_label.add_theme_font_override("font", DISPLAY_FONT)
	_today_label.add_theme_font_size_override("font_size", 20)
	_today_label.add_theme_color_override("font_color", Color("#79eadc") if done_count == 3 else Color("#ffd77a"))
	column.add_child(_today_label)

	# 1 -> 2 -> 3 Step Progress Row & Today's 3 Exercises (shown immediately without tapping calendar)
	var exercise_panel := PanelContainer.new()
	exercise_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.31, 0.96), Color("#ffd77a")))
	column.add_child(exercise_panel)
	var exercise_column := VBoxContainer.new()
	exercise_column.add_theme_constant_override("separation", 10)
	exercise_panel.add_child(exercise_column)

	_instruction = Label.new()
	_instruction.text = "TODAY'S 3 EXERCISES"
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.add_theme_font_override("font", DISPLAY_FONT)
	_instruction.add_theme_font_size_override("font_size", 20)
	_instruction.add_theme_color_override("font_color", Color("#fff5df"))
	exercise_column.add_child(_instruction)

	_steps_row = HBoxContainer.new()
	_steps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_steps_row.add_theme_constant_override("separation", 8)
	exercise_column.add_child(_steps_row)

	_tasks_panel = VBoxContainer.new()
	_tasks_panel.visible = true
	_tasks_panel.add_theme_constant_override("separation", 10)
	exercise_column.add_child(_tasks_panel)

	var calendar_panel := PanelContainer.new()
	calendar_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.31, 0.96), Color("#79eadc")))
	column.add_child(calendar_panel)
	var calendar_column := VBoxContainer.new()
	calendar_column.add_theme_constant_override("separation", 12)
	calendar_panel.add_child(calendar_column)
	var calendar_header := HBoxContainer.new()
	calendar_column.add_child(calendar_header)
	var previous := Button.new()
	previous.text = "‹"
	previous.custom_minimum_size.x = 44
	previous.pressed.connect(_change_month.bind(-1))
	calendar_header.add_child(previous)
	_month_label = Label.new()
	_month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_label.add_theme_font_override("font", DISPLAY_FONT)
	_month_label.add_theme_font_size_override("font_size", 23)
	_month_label.add_theme_color_override("font_color", Color("#fff4da"))
	calendar_header.add_child(_month_label)
	var next := Button.new()
	next.text = "›"
	next.custom_minimum_size.x = 44
	next.pressed.connect(_change_month.bind(1))
	calendar_header.add_child(next)
	_calendar_grid = GridContainer.new()
	_calendar_grid.columns = 7
	_calendar_grid.add_theme_constant_override("h_separation", 3)
	_calendar_grid.add_theme_constant_override("v_separation", 4)
	calendar_column.add_child(_calendar_grid)
	var legend := Label.new()
	legend.text = "✓  ALL 3 DONE       ×  INCOMPLETE DAY"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 16)
	legend.add_theme_color_override("font_color", Color("#fff5df"))
	calendar_column.add_child(legend)
	_refresh_calendar()

func _first_incomplete_index(flags: Array) -> int:
	for index in range(3):
		if index >= flags.size() or not bool(flags[index]):
			return index
	return -1

func _show_today_tasks() -> void:
	for child in _steps_row.get_children():
		child.queue_free()
	for child in _tasks_panel.get_children():
		child.queue_free()

	var today_str := GameState.today_key()
	var tasks := GameState.daily_tasks_for_date(today_str)
	var flags: Array = GameState.daily_history.get(today_str, [false, false, false])
	var active_index := _first_incomplete_index(flags)
	var all_done := (active_index == -1)

	# Build the 1 ── 2 ── 3 step indicator bar
	for index in range(3):
		var done := bool(flags[index])
		var is_current := (index == active_index)
		var step_btn := Button.new()
		step_btn.custom_minimum_size = Vector2(92, 52)
		step_btn.text = "%d ✓" % (index + 1) if done else str(index + 1)
		step_btn.add_theme_font_override("font", DISPLAY_FONT)
		step_btn.add_theme_font_size_override("font_size", 22)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			step_btn.add_theme_color_override(state, Color("#fff9e8"))
		var step_fill := Color("#17675f") if done else (Color("#d4851f") if is_current else Color("#1b264f"))
		var step_border := Color("#79eadc") if done else (Color("#ffd77a") if is_current else Color("#415284"))
		step_btn.add_theme_stylebox_override("normal", _style(step_fill, step_border, 14))
		step_btn.add_theme_stylebox_override("hover", _style(step_fill.lightened(0.1), step_border, 14))
		step_btn.add_theme_stylebox_override("disabled", _style(step_fill, step_border, 14))
		step_btn.disabled = not is_current
		if is_current:
			step_btn.pressed.connect(_start_task.bind(index))
		_steps_row.add_child(step_btn)

		if index < 2:
			var connector := Label.new()
			connector.text = "━━"
			connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			connector.add_theme_font_size_override("font_size", 18)
			connector.add_theme_color_override("font_color", Color("#79eadc") if done else Color("#415284"))
			_steps_row.add_child(connector)

	# Build the 1, 2, 3 exercise cards (sequential: start with 1, then auto 2, then auto 3)
	for index in range(3):
		var task: Dictionary = tasks[index]
		var done := bool(flags[index])
		var is_current := (index == active_index)
		var status_text := "✓ COMPLETED" if done else ("▶ START" if is_current else "🔒 NEXT")
		var card := Button.new()
		card.custom_minimum_size.y = 66
		card.text = "%d.  %s   —   %s" % [index + 1, TYPE_NAMES[int(task["type_index"])], status_text]
		card.add_theme_font_override("font", DISPLAY_FONT)
		card.add_theme_font_size_override("font_size", 19)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			card.add_theme_color_override(state, Color("#fff9e8") if (done or is_current) else Color("#9aa9cc"))
		var fill := Color("#17675f") if done else (Color("#2f468b") if is_current else Color("#182347"))
		var border := Color("#79eadc") if done else (Color("#ffd77a") if is_current else Color("#3b4c7a"))
		card.add_theme_stylebox_override("normal", _style(fill, border))
		card.add_theme_stylebox_override("disabled", _style(fill, border))
		card.add_theme_stylebox_override("hover", _style(Color("#3d58ab"), Color("#ffd77a")))
		card.disabled = not is_current
		if is_current:
			card.pressed.connect(_start_task.bind(index))
		_tasks_panel.add_child(card)

	_tasks_panel.visible = true
	if all_done:
		_instruction.text = "✓ DAILY EXERCISE COMPLETE!"
		_instruction.add_theme_color_override("font_color", Color("#79eadc"))
		if is_instance_valid(_today_label):
			_today_label.text = "%s  •  ✓ COMPLETE (3 / 3)" % today_str
			_today_label.add_theme_color_override("font_color", Color("#79eadc"))
	else:
		_instruction.text = "START WITH #%d — AUTO-ADVANCES 1 → 2 → 3" % (active_index + 1)
		_instruction.add_theme_color_override("font_color", Color("#ffd77a"))

func _start_task(index: int) -> void:
	var flags: Array = GameState.daily_history.get(GameState.today_key(), [false, false, false])
	var expected_index := _first_incomplete_index(flags)
	if index < 0 or index >= 3 or bool(flags[index]) or index != expected_index:
		return
	GameState.start_daily_task(index)
	if GameState.active_game_type == 0:
		get_tree().change_scene_to_file("res://scenes/balloon_match.tscn")
	elif GameState.active_game_type == 2:
		get_tree().change_scene_to_file("res://scenes/sentence_train.tscn")
	elif GameState.active_game_type == 8:
		get_tree().change_scene_to_file("res://scenes/bird_memory.tscn")
	elif GameState.active_game_type == 9:
		get_tree().change_scene_to_file("res://scenes/bird_catch_bugs.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_type_level.tscn")

func _change_month(step: int) -> void:
	_month += step
	if _month < 1:
		_month = 12
		_year -= 1
	elif _month > 12:
		_month = 1
		_year += 1
	_refresh_calendar()

func _refresh_calendar() -> void:
	for child in _calendar_grid.get_children():
		_calendar_grid.remove_child(child)
		child.queue_free()
	_month_label.text = "%s %d" % [MONTH_NAMES[_month - 1], _year]
	for weekday in ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]:
		_calendar_grid.add_child(_plain_cell(weekday, 30, Color("#99eee4")))
	var first_time := Time.get_unix_time_from_datetime_dict({"year": _year, "month": _month, "day": 1})
	var first_weekday := int(Time.get_datetime_dict_from_unix_time(first_time).weekday)
	for _index in range(first_weekday):
		_calendar_grid.add_child(_plain_cell("", 54, Color.TRANSPARENT))
	var days: int = [31, 28 + int(_year % 4 == 0 and (_year % 100 != 0 or _year % 400 == 0)), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][_month - 1]
	for day in range(1, days + 1):
		var key := "%04d-%02d-%02d" % [_year, _month, day]
		_calendar_grid.add_child(_day_cell(day, key))

func _plain_cell(value: String, height: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.custom_minimum_size = Vector2(56, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	return label

func _day_cell(day: int, key: String) -> Control:
	var is_today := key == GameState.today_key()
	var cell: Control = Button.new() if is_today else PanelContainer.new()
	cell.custom_minimum_size = Vector2(56, 54)
	var tracked := not GameState.daily_first_date.is_empty() and key >= GameState.daily_first_date and key <= GameState.today_key()
	var done := tracked and GameState.daily_completed_count(key) == 3
	var fill := Color("#135c59") if done else (Color("#753943") if tracked else Color("#18264e"))
	var border := Color("#79eadc") if done else (Color("#ff9b82") if tracked else Color("#33436e"))
	cell.add_theme_stylebox_override("panel", _style(fill, border, 10))
	if is_today:
		cell.add_theme_stylebox_override("normal", _style(fill, Color("#ffd77a"), 10))
		cell.add_theme_stylebox_override("hover", _style(Color("#36507e"), Color("#ffd77a"), 10))
		(cell as Button).pressed.connect(_show_today_tasks)
	var mark := "✓" if done else ("×" if tracked else "")
	var label := _plain_cell("%d\n%s" % [day, mark], 48, Color("#ffffff") if tracked else Color("#8293b4"))
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	if tracked:
		cell.tooltip_text = "%s: %d of 3 exercises completed" % [key, GameState.daily_completed_count(key)]
	return cell

func _style(fill: Color, border: Color, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
