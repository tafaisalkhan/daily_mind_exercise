extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _open_game(type_index: int, level: int = 1) -> Control:
	var state := get_root().get_node("GameState")
	state.start_game_type(type_index)
	state.type_level = level
	var path := "res://scenes/game_type_level.tscn"
	if type_index == 0:
		path = "res://scenes/balloon_match.tscn"
	elif type_index == 2:
		path = "res://scenes/sentence_train.tscn"
	assert(change_scene_to_file(path) == OK)
	await process_frame
	await process_frame
	return current_scene

func _run() -> void:
	for level in [1, 5, 7]:
		var word_scene := await _open_game(1, level)
		var word = word_scene.active_component
		var before: Array = word.word_slots.duplicate()
		word_scene._use_hint()
		assert(word.word_slots != before or word_scene.finished)
		print("Build Words level %d: hint acted" % level)

	var bridge_scene := await _open_game(3)
	var bridge = bridge_scene.active_component
	bridge_scene._hint_unavailable("Ad unavailable")
	assert(bridge_scene.prompt_label.text == "Ad unavailable")
	bridge_scene._use_hint()
	assert(bridge.bridge_slot_filled.count(true) == 1)
	print("Number Bridge: hint placed a step")

	var balance_scene := await _open_game(4)
	var balance = balance_scene.active_component
	for frame in range(400):
		if not balance.balance_intro_playing:
			break
		await process_frame
	assert(not balance.balance_intro_playing)
	balance_scene._use_hint()
	assert(balance.balance_user_balls.size() == 1)
	print("Balance the Scale: hint placed a ball")

	var maze_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/game_types/number_maze.json"))
	var maze = load("res://scripts/components/maze/number_maze_component.gd").new()
	get_root().add_child(maze)
	var maze_grid := GridContainer.new()
	get_root().add_child(maze_grid)
	maze.setup_level(maze_data.levels[0], 0, maze_grid)
	maze.rebuild_choices(maze_grid)
	assert(maze.use_hint(maze_grid))
	assert(maze.step_index == 1)
	print("Number Maze: hint advanced one step")
	maze.queue_free()
	maze_grid.queue_free()

	var hunt_scene := await _open_game(6)
	var hunt = hunt_scene.active_component
	hunt_scene._use_hint()
	assert(hunt.catches == 1)
	print("Number Hunter: hint caught target")

	var relay_scene := await _open_game(7)
	var relay = relay_scene.active_component
	relay_scene._use_hint()
	assert(relay.filled.count(false) < relay.filled.size() - relay.fixed_indices.size())
	print("Word Relay: hint placed a word")

	var train := await _open_game(2)
	train._use_hint()
	assert(train._first_empty_slot() > 0)
	print("Sentence Train: hint placed a word")

	var balloons := await _open_game(0)
	await process_frame
	while not balloons.pending_balloons.is_empty():
		balloons._spawn_next_balloon()
	balloons._hint()
	assert(balloons.completed_pairs == 1)
	print("Balloon Match: hint matched a pair")

	var state := get_root().get_node("GameState")
	state.requested_level = 1
	assert(change_scene_to_file("res://scenes/main.tscn") == OK)
	await process_frame
	await process_frame
	var main := current_scene
	main._on_hint_pressed()
	assert(main.hints_used == 1)
	print("Main puzzle: hint placed a tile")
	quit()
