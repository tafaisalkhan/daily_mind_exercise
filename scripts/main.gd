extends Control

const PUZZLE_TILE_SIZE: float = 40.0

const LevelDataScript = preload("res://scripts/level_data.gd")
const ChapterThemesScript = preload("res://scripts/chapter_themes.gd")
const GridTileScript = preload("res://scripts/grid_tile.gd")
const NumberTileScript = preload("res://scripts/number_tile.gd")
const RewardCoinTexture = preload("res://assets/generated/reward-coin.png")
const VictoryStarTexture = preload("res://assets/generated/victory-star.png")
const HINT_COST: int = 5

@export var grid_tile_scene: PackedScene
@export var number_tile_scene: PackedScene

# UI Node References
@onready var level_label: Label = $MainVBox/TopMenu/HeaderMargin/HeaderHBox/TitleVBox/LevelLabel
@onready var difficulty_label: Label = $MainVBox/TopMenu/DifficultyMargin/DifficultyHBox/DifficultyLabel
@onready var coins_label: Label = $MainVBox/TopMenu/HeaderMargin/HeaderHBox/CoinPanel/CoinHBox/CoinsLabel
@onready var grid_container: GridContainer = $MainVBox/PuzzleBoard/BoardCenter/GridContainer
@onready var bank_container: HFlowContainer = $MainVBox/PuzzleBoard/BankCenter/BankContainer
@onready var undo_btn: Button = $MainVBox/BottomMenu/ActionToolbar/UndoButton
@onready var hint_btn: Button = $MainVBox/BottomMenu/ActionToolbar/HintButton
@onready var search_btn: Button = $MainVBox/BottomMenu/ActionToolbar/SearchButton
@onready var previous_level_btn: Button = $MainVBox/TopMenu/HeaderMargin/HeaderHBox/PreviousLevelButton
@onready var browse_next_level_btn: Button = $MainVBox/TopMenu/HeaderMargin/HeaderHBox/BrowseNextLevelButton
@onready var menu_btn: Button = $MainVBox/TopMenu/HeaderMargin/HeaderHBox/MenuButton
@onready var victory_dialog: TextureRect = %VictoryDialog
@onready var victory_shadow: TextureRect = %VictoryShadow
@onready var victory_dimmer: ColorRect = %VictoryDimmer
@onready var victory_level_banner: Label = %LevelBanner
@onready var next_level_btn: Button = %NextLevelButton
@onready var victory_stars: HBoxContainer = %Stars
@onready var victory_reward: Label = %Reward
@onready var victory_streak: Label = %Streak
@onready var victory_title: Label = $VictoryDialog/VBox/VicTitle
@onready var gameplay_background: TextureRect = $Background
@onready var game_type_sprite: TextureRect = %GameTypeSprite
@onready var pause_dialog: TextureRect = %PauseDialog
@onready var pause_dimmer: ColorRect = %PauseDimmer
@onready var resume_btn: Button = %ResumeButton
@onready var back_to_menu_btn: Button = %BackToMenuButton

# Game State
var coins: int = 0
var current_level: int = 1
var level_info: Dictionary = {}
var grid_tiles: Dictionary = {} # Vector2i(r, c) -> Control
var bank_tiles: Array = [] # Array[Control]
var selected_bank_tile = null
var selected_grid_tile = null
var move_history: Array = [] # Stores history items: {"grid_tile": Control, "bank_tile": Control}
var mistakes: int = 0
var hints_used: int = 0
var level_started_at: int = 0
var level_completion_started: bool = false
var level_failed: bool = false
var failure_reward_btn: Button
var retry_level_btn: Button
var completion_reward_btn: Button

func _ready() -> void:
	_apply_game_styles()
	# Connect UI buttons
	undo_btn.pressed.connect(_on_undo_pressed)
	hint_btn.pressed.connect(_on_hint_pressed)
	hint_btn.tooltip_text = "Hint" if OS.get_name() != "Android" else "Watch an ad for a hint"
	search_btn.pressed.connect(_on_search_pressed)
	previous_level_btn.pressed.connect(_on_previous_level_pressed)
	browse_next_level_btn.pressed.connect(_on_browse_next_level_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	next_level_btn.pressed.connect(_on_next_level_pressed)
	_setup_failure_reward_button()
	_setup_retry_level_button()
	_setup_completion_reward_button()
	resume_btn.pressed.connect(_resume_game)
	back_to_menu_btn.pressed.connect(_return_to_main_menu)
	victory_dialog.visible = false
	victory_shadow.visible = false
	victory_dimmer.visible = false
	coins = GameState.coins
	current_level = GameState.requested_level
	load_level(current_level)

func _auto_solve_current_level() -> void:
	await get_tree().create_timer(1.0).timeout
	for grid_tile in grid_tiles.values():
		if not grid_tile.is_empty_slot or grid_tile.is_filled:
			continue
		for bank_tile in bank_tiles:
			if not bank_tile.is_used and bank_tile.value == grid_tile.target_value:
				_place_bank_tile(grid_tile, bank_tile)
				await get_tree().create_timer(0.45).timeout
				break

func update_coins_display() -> void:
	if coins_label:
		coins_label.text = str(coins)

func load_level(level_num: int) -> void:
	current_level = level_num
	GameState.remember_level(current_level)
	level_info = LevelDataScript.get_level(level_num)
	move_history.clear()
	selected_bank_tile = null
	selected_grid_tile = null
	mistakes = 0
	hints_used = 0
	level_started_at = Time.get_ticks_msec()
	level_completion_started = false
	level_failed = false
	if failure_reward_btn:
		failure_reward_btn.visible = false
	if retry_level_btn:
		retry_level_btn.visible = false
	if completion_reward_btn:
		completion_reward_btn.visible = false
	next_level_btn.text = "▶  NEXT LEVEL"
	victory_title.text = "COMPLETE!"
	victory_dialog.visible = false
	victory_shadow.visible = false
	victory_dimmer.visible = false
	
	# Update Header Labels
	level_label.text = "LEVEL %d" % level_num
	var chapter_theme := ChapterThemesScript.theme_for_level(level_num)
	var game_type: Dictionary = ChapterThemesScript.game_type_for_level(level_num)
	difficulty_label.text = "%s %s  •  %s" % [chapter_theme["icon"], chapter_theme["name"], level_info.get("difficulty", "Easy")]
	gameplay_background.texture = load(str(game_type["background"]))
	gameplay_background.modulate = Color.WHITE
	game_type_sprite.texture = load(str(game_type["sprite"]))
	game_type_sprite.tooltip_text = str(game_type["id"]).replace("_", " ").capitalize()
	_apply_level_theme(chapter_theme)
	update_coins_display()
	
	# Build Grid
	var rows: int = level_info.get("rows", 9)
	var cols: int = level_info.get("cols", 7)
	var available_width: float = minf(500.0, get_viewport_rect().size.x - 24.0)
	var tile_size: float = clampf(available_width / float(cols), 42.0, 72.0)
	grid_container.columns = cols
	
	# Clear previous grid children
	for child in grid_container.get_children():
		child.queue_free()
	grid_tiles.clear()
	
	# Pre-index cells from level data
	var cell_dict: Dictionary = {}
	var cells_arr: Array = level_info.get("cells", [])
	for c_data in cells_arr:
		var pos = Vector2i(c_data.get("r"), c_data.get("c"))
		cell_dict[pos] = c_data
		
	# Populate GridContainer
	for r in range(rows):
		for c in range(cols):
			var pos = Vector2i(r, c)
			if cell_dict.has(pos):
				var data = cell_dict[pos]
				var tile = grid_tile_scene.instantiate()
				tile.setup(data)
				grid_container.add_child(tile)
				tile.set_mobile_size(tile_size)
				tile.tile_clicked.connect(_on_grid_tile_clicked)
				tile.number_dropped.connect(_on_number_dropped)
				grid_tiles[pos] = tile
			else:
				# Empty spacer cell (invisible background cell)
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(tile_size, tile_size)
				grid_container.add_child(spacer)

	# Build Bank Inventory
	for child in bank_container.get_children():
		child.queue_free()
	bank_tiles.clear()
	
	var bank_vals: Array = level_info.get("bank", [])
	for val in bank_vals:
		var n_tile = number_tile_scene.instantiate()
		n_tile.setup(val)
		bank_container.add_child(n_tile)
		n_tile.set_mobile_size(tile_size)
		n_tile.bank_tile_selected.connect(_on_bank_tile_selected)
		n_tile.touch_drop_requested.connect(_on_touch_drop_requested)
		bank_tiles.append(n_tile)

func _on_bank_tile_selected(tile) -> void:
	if selected_grid_tile != null and not selected_grid_tile.is_filled and not tile.is_used:
		_fly_bank_tile_to_selected_cell(tile, selected_grid_tile)
		return
	if selected_bank_tile == tile:
		# Deselect if tapped again
		selected_bank_tile.set_selected(false)
		selected_bank_tile = null
	else:
		if selected_bank_tile != null:
			selected_bank_tile.set_selected(false)
		selected_bank_tile = tile
		selected_bank_tile.set_selected(true)

func _on_grid_tile_clicked(tile) -> void:
	if not tile.is_empty_slot:
		return # Fixed cell cannot be modified
		
	if tile.is_filled:
		# Player tapped a filled grid tile -> return the tile back to bank
		tile.remove_value()
		# Restore the exact bank tile used for this placement. This matters
		# when the bank contains duplicate values.
		for i in range(move_history.size() - 1, -1, -1):
			if move_history[i]["grid_tile"] == tile:
				var original_bank_tile = move_history[i]["bank_tile"]
				if is_instance_valid(original_bank_tile):
					original_bank_tile.set_used(false)
				move_history.remove_at(i)
				break
	else:
		# Player tapped an empty grid tile
		if selected_grid_tile != null and selected_grid_tile != tile:
			selected_grid_tile.set_target_selected(false)
		selected_grid_tile = tile
		selected_grid_tile.set_target_selected(true)
		if selected_bank_tile != null and not selected_bank_tile.is_used:
			_fly_bank_tile_to_selected_cell(selected_bank_tile, tile)

func _on_number_dropped(grid_tile, bank_tile) -> void:
	if grid_tile.is_empty_slot and not grid_tile.is_filled and not bank_tile.is_used:
		_place_bank_tile(grid_tile, bank_tile)

func _on_touch_drop_requested(bank_tile, viewport_position: Vector2) -> void:
	if bank_tile.is_used:
		return
	for grid_tile in grid_tiles.values():
		if (
			grid_tile.is_empty_slot
			and not grid_tile.is_filled
			and grid_tile.get_global_rect().has_point(viewport_position)
		):
			_place_bank_tile(grid_tile, bank_tile)
			return

func _place_bank_tile(grid_tile, bank_tile) -> void:
	if selected_grid_tile != null:
		selected_grid_tile.set_target_selected(false)
	selected_grid_tile = null
	if selected_bank_tile != null:
		selected_bank_tile.set_selected(false)
	selected_bank_tile = null

	grid_tile.place_value(bank_tile.value)
	AudioManager.play_place(bank_tile.value == grid_tile.target_value)
	if bank_tile.value != grid_tile.target_value:
		mistakes += 1
		_deduct_wrong_answer_coins()
		_spawn_tile_feedback(grid_tile, false)
	else:
		_spawn_tile_feedback(grid_tile, true)
	bank_tile.set_used(true)
	move_history.append({
		"grid_tile": grid_tile,
		"bank_tile": bank_tile
	})
	check_level_completion()

func _deduct_wrong_answer_coins() -> void:
	coins = maxi(0, coins - 10)
	GameState.coins = coins
	GameState.save_progress()
	update_coins_display()
	if coins == 0 and not level_failed:
		level_failed = true
		call_deferred("_show_zero_coin_failure")
func _fly_bank_tile_to_selected_cell(bank_tile, grid_tile) -> void:
	var flying_tile: Control = bank_tile.make_visual_copy()
	flying_tile.global_position = bank_tile.global_position
	flying_tile.z_index = 220
	flying_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(flying_tile)
	bank_tile.set_used(true)
	grid_tile.set_target_selected(false)
	selected_grid_tile = null
	if selected_bank_tile != null:
		selected_bank_tile.set_selected(false)
	selected_bank_tile = null
	var destination: Vector2 = grid_tile.global_position + (grid_tile.size - flying_tile.size) * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flying_tile, "global_position", destination, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying_tile, "scale", Vector2(1.12, 1.12), 0.28)
	tween.chain().tween_callback(func() -> void:
		flying_tile.queue_free()
		grid_tile.place_value(bank_tile.value)
		if bank_tile.value != grid_tile.target_value:
			mistakes += 1
			_deduct_wrong_answer_coins()
			_spawn_tile_feedback(grid_tile, false)
		else:
			_spawn_tile_feedback(grid_tile, true)
		move_history.append({"grid_tile": grid_tile, "bank_tile": bank_tile})
		check_level_completion()
	)
func _on_undo_pressed() -> void:
	if move_history.is_empty():
		return
		
	var last_move = move_history.pop_back()
	var g_tile = last_move["grid_tile"]
	var b_tile = last_move["bank_tile"]
	
	if g_tile and g_tile.is_filled:
		g_tile.remove_value()
	if b_tile:
		b_tile.set_used(false)
		
	AudioManager.play_undo()
	if selected_bank_tile:
		selected_bank_tile.set_selected(false)
		selected_bank_tile = null

func _on_hint_pressed() -> void:
	if OS.get_name() != "Android":
		_apply_rewarded_hint()
		return
	AdManager.request_rewarded_hint(Callable(self, "_apply_rewarded_hint"), Callable(self, "_on_hint_ad_unavailable"))

func _on_hint_ad_unavailable(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "AD NOT READY"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 220))

func _apply_rewarded_hint() -> void:
	for pos in grid_tiles.keys():
		var g_tile = grid_tiles[pos]
		if g_tile.is_empty_slot and not g_tile.is_filled:
			var needed_target = g_tile.target_value
			for b_tile in bank_tiles:
				if not b_tile.is_used and b_tile.value == needed_target:
					g_tile.place_value(needed_target)
					b_tile.set_used(true)
					move_history.append({"grid_tile": g_tile, "bank_tile": b_tile})
					AudioManager.play_hint()
					hints_used += 1
					check_level_completion()
					return
func _setup_retry_level_button() -> void:
	retry_level_btn = Button.new()
	retry_level_btn.text = "↻  RETRY LEVEL"
	retry_level_btn.custom_minimum_size = Vector2(220, 54)
	retry_level_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_level_btn.visible = false
	$VictoryDialog/VBox.add_child(retry_level_btn)
	retry_level_btn.pressed.connect(func() -> void: load_level(current_level))

func _setup_completion_reward_button() -> void:
	completion_reward_btn = Button.new()
	completion_reward_btn.text = "▶  WATCH AD +100 COINS"
	completion_reward_btn.custom_minimum_size = Vector2(290, 54)
	completion_reward_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	completion_reward_btn.visible = false
	$VictoryDialog/VBox.add_child(completion_reward_btn)
	completion_reward_btn.pressed.connect(_watch_completion_reward_ad)

func _setup_failure_reward_button() -> void:
	failure_reward_btn = Button.new()
	failure_reward_btn.text = "WATCH AD  +100 COINS"
	failure_reward_btn.custom_minimum_size = Vector2(260, 54)
	failure_reward_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	failure_reward_btn.visible = false
	$VictoryDialog/VBox.add_child(failure_reward_btn)
	failure_reward_btn.pressed.connect(_watch_failure_reward_ad)

func _show_zero_coin_failure() -> void:
	if not level_failed:
		return
	victory_title.text = "LEVEL FAILED"
	victory_level_banner.text = "LEVEL %d" % current_level
	victory_reward.text = "0 COINS LEFT"
	victory_streak.text = "Retry or watch an ad to earn coins"
	victory_stars.visible = false
	retry_level_btn.visible = false
	for star_node in victory_stars.get_children():
		star_node.modulate = Color(0.25, 0.25, 0.25, 0.22)
	next_level_btn.text = "↻  RETRY"
	next_level_btn.disabled = false
	failure_reward_btn.text = "WATCH AD  +100 COINS"
	failure_reward_btn.disabled = false
	failure_reward_btn.visible = true
	victory_dimmer.visible = true
	victory_dimmer.modulate.a = 0.0
	victory_shadow.visible = true
	victory_shadow.modulate.a = 0.0
	victory_dialog.visible = true
	victory_dialog.pivot_offset = victory_dialog.size * 0.5
	victory_dialog.scale = Vector2(0.55, 0.55)
	victory_dialog.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(victory_dimmer, "modulate:a", 1.0, 0.2)
	tween.tween_property(victory_shadow, "modulate:a", 0.72, 0.25)
	tween.tween_property(victory_dialog, "modulate:a", 1.0, 0.25)
	tween.tween_property(victory_dialog, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _watch_failure_reward_ad() -> void:
	failure_reward_btn.disabled = true
	failure_reward_btn.text = "LOADING AD..."
	var reward_callback := Callable(self, "_grant_failure_reward")
	var unavailable_callback := Callable(self, "_on_failure_reward_unavailable").bind(reward_callback)
	AdManager.rewarded_video_completed.connect(reward_callback, CONNECT_ONE_SHOT)
	AdManager.rewarded_video_unavailable.connect(unavailable_callback, CONNECT_ONE_SHOT)
	AdManager.show_rewarded_video()

func _grant_failure_reward() -> void:
	coins += 100
	GameState.coins = coins
	GameState.save_progress()
	load_level(current_level)

func _on_failure_reward_unavailable(message: String, reward_callback: Callable) -> void:
	if AdManager.rewarded_video_completed.is_connected(reward_callback):
		AdManager.rewarded_video_completed.disconnect(reward_callback)
	failure_reward_btn.disabled = false
	failure_reward_btn.text = "AD NOT READY - TRY AGAIN"
	victory_streak.text = message
func _watch_completion_reward_ad() -> void:
	completion_reward_btn.disabled = true
	completion_reward_btn.text = "LOADING AD..."
	var reward_callback := Callable(self, "_grant_completion_reward")
	var unavailable_callback := Callable(self, "_on_completion_reward_unavailable").bind(reward_callback)
	AdManager.rewarded_video_completed.connect(reward_callback, CONNECT_ONE_SHOT)
	AdManager.rewarded_video_unavailable.connect(unavailable_callback, CONNECT_ONE_SHOT)
	AdManager.show_rewarded_video()

func _grant_completion_reward() -> void:
	GameState.coins = coins + 100
	GameState.save_progress()
	completion_reward_btn.visible = false
	await _fly_reward_coins(100)

func _on_completion_reward_unavailable(message: String, reward_callback: Callable) -> void:
	if AdManager.rewarded_video_completed.is_connected(reward_callback):
		AdManager.rewarded_video_completed.disconnect(reward_callback)
	completion_reward_btn.disabled = false
	completion_reward_btn.text = "AD NOT READY - TRY AGAIN"
	victory_streak.text = message

func _show_rewarded_ad_prompt() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "GET MORE COINS"
	dialog.dialog_text = "Watch a rewarded ad to earn 100 coins?"
	dialog.ok_button_text = "WATCH AD"
	dialog.get_cancel_button().text = "NOT NOW"
	add_child(dialog)
	dialog.confirmed.connect(_play_rewarded_ad.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 240))

func _play_rewarded_interstitial(dialog: ConfirmationDialog) -> void:
	dialog.dialog_text = "Loading rewarded interstitial..."
	dialog.get_ok_button().disabled = true
	var reward_callback := _grant_rewarded_interstitial_coins.bind(dialog)
	var unavailable_callback := _on_rewarded_interstitial_unavailable.bind(dialog, reward_callback)
	AdManager.rewarded_interstitial_completed.connect(reward_callback, CONNECT_ONE_SHOT)
	AdManager.rewarded_interstitial_unavailable.connect(unavailable_callback, CONNECT_ONE_SHOT)
	AdManager.show_rewarded_interstitial()

func _grant_rewarded_interstitial_coins(dialog: ConfirmationDialog) -> void:
	GameState.coins = coins + 100
	GameState.save_progress()
	if is_instance_valid(dialog):
		dialog.queue_free()
	await _fly_reward_coins(100)

func _on_rewarded_interstitial_unavailable(message: String, dialog: ConfirmationDialog, reward_callback: Callable) -> void:
	if AdManager.rewarded_interstitial_completed.is_connected(reward_callback):
		AdManager.rewarded_interstitial_completed.disconnect(reward_callback)
	if is_instance_valid(dialog):
		dialog.dialog_text = message
		dialog.get_ok_button().disabled = false
func _play_rewarded_ad(dialog: ConfirmationDialog) -> void:
	dialog.dialog_text = "Loading rewarded ad..."
	dialog.get_ok_button().disabled = true
	if not AdManager.rewarded_video_completed.is_connected(_grant_rewarded_coins):
		AdManager.rewarded_video_completed.connect(_grant_rewarded_coins.bind(dialog), CONNECT_ONE_SHOT)
	AdManager.show_rewarded_video()

func _grant_rewarded_coins(dialog: ConfirmationDialog) -> void:
	coins += 100
	GameState.coins = coins
	GameState.save_progress()
	update_coins_display()
	if is_instance_valid(dialog):
		dialog.queue_free()
func _on_search_pressed() -> void:
	if coins < 150:
		return
	# Highlight any incorrect placements
	coins -= 150
	GameState.coins = coins
	GameState.save_progress()
	update_coins_display()
	
	for pos in grid_tiles.keys():
		var g_tile = grid_tiles[pos]
		if g_tile.is_empty_slot and g_tile.is_filled:
			if g_tile.current_value != g_tile.target_value:
				# Automatically remove wrong placement
				_on_grid_tile_clicked(g_tile)

func _offer_tenth_level_reward() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "10-LEVEL BONUS"
	dialog.dialog_text = "Watch a rewarded ad to collect 100 bonus coins?"
	dialog.ok_button_text = "WATCH AD"
	dialog.get_cancel_button().text = "NOT NOW"
	add_child(dialog)
	dialog.confirmed.connect(_play_rewarded_ad.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 240))
func check_level_completion() -> void:
	# Check if all empty grid slots are filled
	var all_filled = true
	var all_correct = true
	
	for pos in grid_tiles.keys():
		var g_tile = grid_tiles[pos]
		if g_tile.is_empty_slot:
			if not g_tile.is_filled:
				all_filled = false
				break
			if g_tile.current_value != g_tile.target_value:
				all_correct = false
				
	if all_filled and all_correct:
		if level_completion_started:
			return
		level_completion_started = true
		var stars := 3
		var reward := 10
		GameState.coins = coins
		GameState.register_win(current_level, stars, reward)
		# The visible balance increases only when animated coins arrive.
		victory_streak.text = "🔥 STREAK %d" % GameState.win_streak
		victory_reward.text = "+%d COINS" % reward
		victory_level_banner.text = "LEVEL %d" % current_level
		_play_level_complete_sequence(stars, reward)

func _play_level_complete_sequence(stars: int, reward: int) -> void:
	victory_stars.visible = true
	AudioManager.play_victory()
	next_level_btn.disabled = true
	next_level_btn.text = "COLLECTING COINS..."
	# Wave through the solved board, similar to polished mobile puzzle games.
	var ordered_tiles: Array = grid_tiles.values()
	ordered_tiles.sort_custom(func(a, b):
		return (a.cell_row * 20 + a.cell_col) < (b.cell_row * 20 + b.cell_col)
	)
	for index in range(ordered_tiles.size()):
		var tile: Control = ordered_tiles[index]
		tile.pivot_offset = tile.size * 0.5
		var tile_tween := create_tween()
		tile_tween.tween_interval(float(index) * 0.025)
		tile_tween.tween_property(tile, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tile_tween.parallel().tween_property(tile, "modulate", Color(1.15, 1.08, 0.72, 1.0), 0.11)
		tile_tween.tween_property(tile, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tile_tween.parallel().tween_property(tile, "modulate", Color.WHITE, 0.14)

	await get_tree().create_timer(0.35 + float(ordered_tiles.size()) * 0.025).timeout
	_spawn_board_flash()
	await get_tree().create_timer(0.22).timeout

	victory_dimmer.visible = true
	victory_dimmer.modulate.a = 0.0
	victory_dialog.visible = true
	victory_shadow.visible = true
	victory_shadow.pivot_offset = victory_shadow.size * 0.5
	victory_shadow.scale = Vector2(0.32, 0.32)
	victory_shadow.rotation = deg_to_rad(-3.0)
	victory_shadow.modulate.a = 0.0
	victory_dialog.pivot_offset = victory_dialog.size * 0.5
	victory_dialog.scale = Vector2(0.35, 0.35)
	victory_dialog.rotation = deg_to_rad(-3.0)
	victory_dialog.modulate.a = 0.0
	for star_node in victory_stars.get_children():
		star_node.modulate = Color(0.35, 0.35, 0.35, 0.3)
	var panel_tween := create_tween().set_parallel(true)
	panel_tween.tween_property(victory_dimmer, "modulate:a", 1.0, 0.25)
	panel_tween.tween_property(victory_shadow, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(victory_shadow, "rotation", 0.0, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(victory_shadow, "modulate:a", 0.72, 0.3)
	panel_tween.tween_property(victory_dialog, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(victory_dialog, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(victory_dialog, "modulate:a", 1.0, 0.26)
	await panel_tween.finished

	for earned in range(stars):
		var star_control: Control = victory_stars.get_child(earned)
		star_control.pivot_offset = star_control.size * 0.5
		star_control.scale = Vector2(1.65, 1.65)
		star_control.modulate = Color.WHITE
		var star_tween := create_tween()
		star_tween.tween_property(star_control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_spawn_star_burst(star_control.global_position + star_control.size * 0.5)
		await get_tree().create_timer(0.34).timeout

	_spawn_victory_particles()
	retry_level_btn.visible = false
	completion_reward_btn.visible = true
	completion_reward_btn.disabled = false
	completion_reward_btn.text = "▶  WATCH AD +100 COINS"
	await _fly_reward_coins(reward)
	next_level_btn.text = "▶  NEXT LEVEL"
	next_level_btn.disabled = false
	# Show an interstitial after the full victory and coin animation.
	AdManager.show_interstitial()
func _spawn_board_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.82, 0.24, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 140
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.32, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.24)
	tween.tween_callback(flash.queue_free)

func _spawn_star_burst(center: Vector2) -> void:
	for index in range(10):
		var sparkle := TextureRect.new()
		sparkle.texture = VictoryStarTexture
		sparkle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sparkle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sparkle_size := 14.0 + float(index % 4) * 4.0
		sparkle.size = Vector2(sparkle_size, sparkle_size)
		sparkle.global_position = center - sparkle.size * 0.5
		sparkle.pivot_offset = sparkle.size * 0.5
		sparkle.scale = Vector2(0.35, 0.35)
		sparkle.z_index = 240
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(sparkle)
		var angle := TAU * float(index) / 10.0 + 0.28
		var direction := Vector2.from_angle(angle)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(sparkle, "global_position", center + direction * (62.0 + index * 3.0) - sparkle.size * 0.5, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "rotation", angle + PI, 0.62)
		tween.tween_property(sparkle, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.62).set_delay(0.2)
		tween.chain().tween_callback(sparkle.queue_free)

func _on_next_level_pressed() -> void:
	if level_failed:
		load_level(current_level)
		return
	_on_browse_next_level_pressed()

func _on_previous_level_pressed() -> void:
	var previous := current_level - 1
	if previous < 1:
		previous = 1
	load_level(previous)

func _on_browse_next_level_pressed() -> void:
	var next := current_level + 1
	if next > ChapterThemesScript.total_levels():
		return
	if GameState.game_mode == "continue" and next > GameState.highest_level:
		return
	load_level(next)

func _on_menu_pressed() -> void:
	pause_dimmer.visible = true
	pause_dialog.visible = true
	pause_dialog.pivot_offset = pause_dialog.size * 0.5
	pause_dialog.scale = Vector2(0.72, 0.72)
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(pause_dialog, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().paused = true

func _resume_game() -> void:
	get_tree().paused = false
	pause_dialog.visible = false
	pause_dimmer.visible = false

func _return_to_main_menu() -> void:
	get_tree().paused = false
	GameState.coins = coins
	GameState.save_progress()
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _apply_level_theme(theme_data: Dictionary) -> void:
	var popup_frame_path := str(theme_data.get("popup_frame", "res://assets/generated/victory-frame.png"))
	var popup_frame: Texture2D = load(popup_frame_path)
	victory_dialog.material = null
	pause_dialog.material = null
	victory_dialog.texture = popup_frame
	victory_shadow.texture = popup_frame
	pause_dialog.texture = popup_frame
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = theme_data.get("button", Color("#249b58"))
	button_style.border_color = Color("#f4d06f")
	button_style.set_border_width_all(3)
	button_style.set_corner_radius_all(16)
	button_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	button_style.shadow_size = 11
	button_style.shadow_offset = Vector2(0, 7)
	for themed_button in [next_level_btn, resume_btn, back_to_menu_btn]:
		themed_button.add_theme_stylebox_override("normal", button_style)
		themed_button.add_theme_color_override("font_color", Color.WHITE)
func _apply_game_styles() -> void:
	var top_panel := StyleBoxFlat.new()
	top_panel.bg_color = Color(0.04, 0.28, 0.21, 0.94)
	top_panel.border_color = Color("#ffc83d")
	top_panel.set_border_width_all(2)
	top_panel.set_corner_radius_all(14)
	$MainVBox/TopMenu/HeaderMargin.add_theme_stylebox_override("panel", top_panel)
	level_label.add_theme_color_override("font_color", Color("#ffd13d"))
	difficulty_label.add_theme_color_override("font_color", Color("#2d2218"))
	for button in [menu_btn, previous_level_btn, browse_next_level_btn]:
		button.add_theme_color_override("font_color", Color("#ffc83d"))

func _spawn_tile_feedback(tile: Control, correct: bool) -> void:
	var symbol := Label.new()
	symbol.text = "✦" if correct else "×"
	symbol.add_theme_font_size_override("font_size", 28)
	symbol.add_theme_color_override("font_color", Color("#38d477") if correct else Color("#e7655a"))
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.global_position = tile.global_position + Vector2(8, 3)
	symbol.z_index = 150
	get_tree().root.add_child(symbol)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(symbol, "global_position", symbol.global_position + Vector2(0, -34), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(symbol, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(symbol.queue_free)

func _spawn_victory_particles() -> void:
	var center := Vector2(270, 430)
	for i in range(32):
		var particle := TextureRect.new()
		particle.texture = VictoryStarTexture if i % 3 == 0 else RewardCoinTexture
		particle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		particle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var particle_size := 18.0 + float((i * 7) % 18)
		particle.size = Vector2(particle_size, particle_size)
		particle.position = center - particle.size * 0.5
		particle.pivot_offset = particle.size * 0.5
		particle.scale = Vector2(0.25, 0.25)
		particle.z_index = 230
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(particle)
		var angle := float(i) * 0.86
		var distance := 75.0 + float(i) * 5.5
		var target := center + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, 55)
		var duration := 1.15 + float(i % 5) * 0.1
		var tween := create_tween().set_parallel(true)
		tween.tween_property(particle, "position", target - particle.size * 0.5, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "rotation", angle + TAU * (1.0 + float(i % 3)), duration)
		tween.tween_property(particle, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, duration * 0.55).set_delay(duration * 0.45)
		tween.chain().tween_callback(particle.queue_free)

func _fly_reward_coins(reward: int) -> void:
	var coin_count := mini(8, maxi(3, reward / 20))
	var target_balance := GameState.coins
	var base_increment := floori(float(reward) / float(coin_count))
	var remainder := reward % coin_count
	for i in range(coin_count):
		var coin := TextureRect.new()
		coin.texture = RewardCoinTexture
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(64, 64)
		coin.position = Vector2(238 + i * 7, 480)
		coin.z_index = 190
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(coin)
		var target: Vector2 = coins_label.global_position - global_position - coin.size * 0.5
		var increment := base_increment + (1 if i < remainder else 0)
		var tween := create_tween()
		tween.tween_interval(i * 0.18)
		tween.tween_property(coin, "position", target, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(_on_reward_coin_arrived.bind(increment, coin))
	await get_tree().create_timer(2.2 + float(coin_count - 1) * 0.18).timeout
	coins = target_balance
	update_coins_display()

func _on_reward_coin_arrived(amount: int, coin: TextureRect) -> void:
	coins += amount
	update_coins_display()
	if is_instance_valid(coin):
		coin.queue_free()


