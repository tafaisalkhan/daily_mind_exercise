extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := get_root().get_node("GameState")
	for level in [1, 1000]:
		state.start_game_type(8)
		state.type_level = level
		assert(change_scene_to_file("res://scenes/bird_memory.tscn") == OK)
		await process_frame
		await process_frame
		var scene := current_scene
		assert(scene != null)
		assert(scene.current_level == level)
		assert(scene.level_label.text == "LEVEL %d" % level)
		assert(scene.level_label.has_theme_stylebox_override("normal"))
		assert(scene.hearts_label.has_theme_stylebox_override("normal"))
		assert(scene.coins_label.text == "%d COINS" % state.coins)
		assert(scene.sequence.size() >= 3 and scene.sequence.size() <= 7)
		assert(scene.bird_buttons.size() == 4)
		scene._toggle_pause()
		assert(paused and scene.pause_button.text == "▶")
		scene._toggle_pause()
		assert(not paused and scene.pause_button.text == "Ⅱ")
		scene.playback_id += 1
		scene.showing = false
		var wrong: int = (int(scene.sequence[0]) + 1) % 4
		scene._choose_bird(wrong)
		assert(scene.hearts == 2 and scene.answer_index == 0)
		for index in range(scene.sequence.size() - 1):
			scene._choose_bird(scene.sequence[index])
		assert(scene.answer_index == scene.sequence.size() - 1)
		assert(not scene.finished)
		print("Bird Parade level %d loaded with %d birds" % [level, scene.sequence.size()])
	quit()
