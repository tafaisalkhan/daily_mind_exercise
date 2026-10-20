extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := get_root().get_node("GameState")
	for type_index in [0, 1, 2, 3, 4, 6, 7]:
		for level in [1, 1000]:
			state.start_game_type(type_index)
			state.type_level = level
			var scene_path := "res://scenes/game_type_level.tscn"
			if type_index == 0:
				scene_path = "res://scenes/balloon_match.tscn"
			elif type_index == 2:
				scene_path = "res://scenes/sentence_train.tscn"
			assert(change_scene_to_file(scene_path) == OK)
			await process_frame
			await process_frame
			assert(current_scene != null)
			var challenge: Dictionary = current_scene.get("level_data")
			assert(int(challenge.get("level", 0)) == level,
				"Game %d loaded level %d instead of %d" % [type_index, int(challenge.get("level", 0)), level])
			print("Game %d level %d loaded" % [type_index, level])
	quit()
