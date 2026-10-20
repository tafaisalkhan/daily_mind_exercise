extends Node

const SAVE_PATH := "user://math_mind_progress.cfg"
const SAVE_VERSION := 2
const DAILY_TYPES := [0, 1, 2, 3, 4, 6, 7]
const GAME_TYPE_COUNT := 8
const GAME_TYPE_LEVEL_COUNT := 1000

var highest_level: int = 1
var highest_levels: Array[int] = [1, 0, 0, 0]
var last_selected_levels: Array[int] = [1, 1, 1, 1]
var coins: int = 0
var total_stars: int = 0
var win_streak: int = 0
var games_played: int = 0
var selected_theme: String = "Classic"
var game_mode: String = "continue"
var requested_level: int = 1
var number_hunt_highest_level: int = 1
var number_hunt_selected_level: int = 1
var game_type_progress: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1]
var game_type_replay_levels: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1]
var active_game_type: int = 0
var type_level: int = 1
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var music_enabled: bool = true
var sfx_enabled: bool = true
var multiply_symbol: String = "×"
var divide_symbol: String = "÷"
var ads_removed: bool = false
var daily_notifications: bool = true
var privacy_accepted: bool = false
var show_privacy_on_start: bool = false
var difficulty_index: int = 0
var daily_history: Dictionary = {}
var daily_first_date := ""
var daily_date := ""
var daily_task_index := -1

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		save_progress()
		return
	var saved_version := int(config.get_value("progress", "save_version", 0))
	if saved_version < SAVE_VERSION:
		highest_level = 1
		total_stars = 0
		win_streak = 0
		games_played = 0
		save_progress()
		return
	highest_level = int(config.get_value("progress", "highest_level", 1))
	coins = int(config.get_value("progress", "coins", 0))
	total_stars = int(config.get_value("progress", "total_stars", 0))
	win_streak = int(config.get_value("progress", "win_streak", 0))
	games_played = int(config.get_value("progress", "games_played", 0))
	selected_theme = str(config.get_value("progress", "theme", "Classic"))
	music_volume = float(config.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(config.get_value("settings", "sfx_volume", 0.9))
	music_enabled = bool(config.get_value("settings", "music_enabled", true))
	sfx_enabled = bool(config.get_value("settings", "sfx_enabled", true))
	multiply_symbol = str(config.get_value("settings", "multiply_symbol", "×"))
	divide_symbol = str(config.get_value("settings", "divide_symbol", "÷"))
	ads_removed = bool(config.get_value("settings", "ads_removed", false))
	daily_notifications = bool(config.get_value("settings", "daily_notifications", true))
	privacy_accepted = bool(config.get_value("privacy", "accepted", false))
	show_privacy_on_start = bool(config.get_value("privacy", "show_on_start", false))
	difficulty_index = clampi(int(config.get_value("settings", "difficulty_index", 0)), 0, 3)
	daily_history = config.get_value("daily", "history", {})
	daily_first_date = str(config.get_value("daily", "first_date", ""))
	number_hunt_highest_level = clampi(int(config.get_value("number_hunt", "highest_level", 1)), 1, 1000)
	number_hunt_selected_level = clampi(int(config.get_value("number_hunt", "selected_level", number_hunt_highest_level)), 1, number_hunt_highest_level)
	var saved_type_progress: Array = config.get_value("game_types", "next_levels", [])
	var saved_replay_levels: Array = config.get_value("game_types", "replay_levels", [])
	for index in range(GAME_TYPE_COUNT):
		var fallback := number_hunt_highest_level if index == 6 else 1
		game_type_progress[index] = clampi(int(saved_type_progress[index]) if index < saved_type_progress.size() else fallback, 1, GAME_TYPE_LEVEL_COUNT + 1)
		game_type_replay_levels[index] = clampi(int(saved_replay_levels[index]) if index < saved_replay_levels.size() else 1, 1, GAME_TYPE_LEVEL_COUNT)
	highest_levels = [
		int(config.get_value("progress", "highest_easy", highest_level)),
		int(config.get_value("progress", "highest_medium", 0)),
		int(config.get_value("progress", "highest_hard", 0)),
		int(config.get_value("progress", "highest_expert", 0))
	]
	last_selected_levels = [
		int(config.get_value("progress", "last_easy", 1)),
		int(config.get_value("progress", "last_medium", 1)),
		int(config.get_value("progress", "last_hard", 1)),
		int(config.get_value("progress", "last_expert", 1))
	]
	var migrated_maze_progress := false
	for index in range(highest_levels.size()):
		if highest_levels[index] == 11 or highest_levels[index] == 12:
			highest_levels[index] = 13
			migrated_maze_progress = true
		if last_selected_levels[index] == 11 or last_selected_levels[index] == 12:
			last_selected_levels[index] = 13
			migrated_maze_progress = true
	if not is_difficulty_unlocked(difficulty_index):
		difficulty_index = 0
	highest_level = maxi(1, highest_levels[difficulty_index])
	requested_level = clampi(last_selected_levels[difficulty_index], 1, mini(highest_level, 1000))
	if migrated_maze_progress:
		save_progress()

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "save_version", SAVE_VERSION)
	config.set_value("number_hunt", "highest_level", number_hunt_highest_level)
	config.set_value("number_hunt", "selected_level", number_hunt_selected_level)
	config.set_value("game_types", "next_levels", game_type_progress)
	config.set_value("game_types", "replay_levels", game_type_replay_levels)
	highest_levels[difficulty_index] = maxi(highest_levels[difficulty_index], highest_level)
	config.set_value("progress", "highest_level", highest_level)
	config.set_value("progress", "highest_easy", highest_levels[0])
	config.set_value("progress", "highest_medium", highest_levels[1])
	config.set_value("progress", "highest_hard", highest_levels[2])
	config.set_value("progress", "highest_expert", highest_levels[3])
	config.set_value("progress", "last_easy", last_selected_levels[0])
	config.set_value("progress", "last_medium", last_selected_levels[1])
	config.set_value("progress", "last_hard", last_selected_levels[2])
	config.set_value("progress", "last_expert", last_selected_levels[3])
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "total_stars", total_stars)
	config.set_value("progress", "win_streak", win_streak)
	config.set_value("progress", "games_played", games_played)
	config.set_value("progress", "theme", selected_theme)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "music_enabled", music_enabled)
	config.set_value("settings", "sfx_enabled", sfx_enabled)
	config.set_value("settings", "multiply_symbol", multiply_symbol)
	config.set_value("settings", "divide_symbol", divide_symbol)
	config.set_value("settings", "ads_removed", ads_removed)
	config.set_value("settings", "daily_notifications", daily_notifications)
	config.set_value("privacy", "accepted", privacy_accepted)
	config.set_value("privacy", "show_on_start", show_privacy_on_start)
	config.set_value("settings", "difficulty_index", difficulty_index)
	config.set_value("daily", "history", daily_history)
	config.set_value("daily", "first_date", daily_first_date)
	config.save(SAVE_PATH)

func unlocked_chapter() -> int:
	return maxi(1, int((highest_level - 1) / 10) + 1)

func daily_level() -> int:
	var date := Time.get_date_dict_from_system()
	return 1000 + int(date.year) * 372 + int(date.month) * 31 + int(date.day)

func today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func daily_tasks_for_date(date_key: String) -> Array[Dictionary]:
	var pool := DAILY_TYPES.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(date_key.replace("-", ""))
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = value
	var tasks: Array[Dictionary] = []
	for slot in range(3):
		var type_index: int = pool[slot]
		var variant: int = (int(date_key.replace("-", "")) + slot) % 2
		tasks.append({"type_index": type_index, "level": type_index * 2 + 1 + variant})
	return tasks

func open_daily() -> void:
	daily_date = today_key()
	if daily_first_date.is_empty():
		daily_first_date = daily_date
	if not daily_history.has(daily_date):
		daily_history[daily_date] = [false, false, false]
	game_mode = "daily"
	daily_task_index = -1
	save_progress()

func start_daily_task(index: int) -> void:
	open_daily()
	daily_task_index = clampi(index, 0, 2)
	active_game_type = int(daily_tasks_for_date(daily_date)[daily_task_index]["type_index"])
	requested_level = active_game_type * 2 + 1
	type_level = next_game_type_level(active_game_type)

func daily_completed_count(date_key: String) -> int:
	var flags: Array = daily_history.get(date_key, [])
	var count := 0
	for done in flags:
		if bool(done):
			count += 1
	return count

func complete_daily_task() -> void:
	if game_mode != "daily" or daily_task_index < 0 or daily_date.is_empty():
		return
	var flags: Array = daily_history.get(daily_date, [false, false, false])
	flags[daily_task_index] = true
	daily_history[daily_date] = flags

func start_mode(mode: String) -> void:
	game_mode = mode
	match mode:
		"daily": requested_level = 1 + (daily_level() % 16)
		"endless": requested_level = maxi(highest_level, 11)
		_: requested_level = clampi(last_selected_levels[difficulty_index], 1, mini(highest_level, 1000))
	requested_level = _playable_level(requested_level)

func start_game_type(type_index: int) -> void:
	game_mode = "game_type"
	active_game_type = clampi(type_index, 0, GAME_TYPE_COUNT - 1)
	requested_level = active_game_type * 2 + 1
	type_level = next_game_type_level(active_game_type)

func next_game_type_level(type_index: int) -> int:
	type_index = clampi(type_index, 0, GAME_TYPE_COUNT - 1)
	var next_level := game_type_progress[type_index]
	return game_type_replay_levels[type_index] if next_level > GAME_TYPE_LEVEL_COUNT else next_level

func register_game_type_win(type_index: int, level: int, stars: int, reward: int) -> void:
	type_index = clampi(type_index, 0, GAME_TYPE_COUNT - 1)
	if game_mode == "daily":
		complete_daily_task()
	if level == game_type_progress[type_index]:
		game_type_progress[type_index] = mini(GAME_TYPE_LEVEL_COUNT + 1, level + 1)
	elif game_type_progress[type_index] > GAME_TYPE_LEVEL_COUNT and level == game_type_replay_levels[type_index]:
		game_type_replay_levels[type_index] = level % GAME_TYPE_LEVEL_COUNT + 1
	# A finished game can be replayed only after its full bank is complete.
	type_level = next_game_type_level(type_index)
	coins += reward
	total_stars += stars
	win_streak += 1
	games_played += 1
	save_progress()

func start_number_hunt(level: int) -> void:
	start_game_type(6)
	type_level = clampi(level, 1, next_game_type_level(6))

func register_number_hunt_win(level: int, stars: int, reward: int) -> void:
	register_game_type_win(6, level, stars, reward)
	number_hunt_highest_level = mini(GAME_TYPE_LEVEL_COUNT, game_type_progress[6])
	number_hunt_selected_level = type_level
	save_progress()
func start_selected_level(level: int) -> void:
	game_mode = "selected"
	level = _playable_level(level)
	if level > highest_level:
		return
	requested_level = clampi(level, 1, 1000)
	last_selected_levels[difficulty_index] = requested_level
	save_progress()
func is_difficulty_unlocked(_index: int) -> bool:
	return true

func set_difficulty(index: int) -> bool:
	index = clampi(index, 0, 3)
	if not is_difficulty_unlocked(index):
		return false
	highest_levels[difficulty_index] = maxi(highest_levels[difficulty_index], highest_level)
	difficulty_index = index
	highest_level = maxi(1, highest_levels[index])
	requested_level = clampi(last_selected_levels[index], 1, mini(highest_level, 1000))
	save_progress()
	return true

func remember_level(level: int) -> void:
	requested_level = _playable_level(clampi(level, 1, 1000))
	last_selected_levels[difficulty_index] = requested_level
	save_progress()

func register_win(level: int, stars: int, reward: int) -> void:
	# Only the next sequential level can be unlocked by a win.
	if game_mode == "daily":
		complete_daily_task()
	elif level <= highest_level:
		highest_level = maxi(highest_level, _playable_level(mini(1001, level + 1)))
		highest_levels[difficulty_index] = highest_level
		last_selected_levels[difficulty_index] = mini(1000, highest_level)
		requested_level = last_selected_levels[difficulty_index]
	coins += reward
	total_stars += stars
	win_streak += 1
	games_played += 1
	save_progress()

func _playable_level(level: int) -> int:
	return 13 if level == 11 or level == 12 else level


