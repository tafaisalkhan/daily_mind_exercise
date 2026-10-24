extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := get_root().get_node("GameState")
	for level in [1, 1000]:
		state.start_game_type(7)
		state.type_level = level
		assert(change_scene_to_file("res://scenes/game_type_level.tscn") == OK)
		await process_frame
		await process_frame
		var scene := current_scene
		var relay = scene.active_component
		assert(relay != null)
		assert(scene.hint_button.text == "HINT")
		var remaining := 0
		for filled in relay.filled:
			if not filled:
				remaining += 1
		assert(remaining > 0)
		scene._hint_unavailable("Ad unavailable")
		assert(relay.status_label.text == "Ad unavailable")
		for index in range(remaining):
			scene._use_hint()
			var new_remaining := 0
			for filled in relay.filled:
				if not filled:
					new_remaining += 1
			assert(new_remaining == remaining - index - 1)
		assert(scene.finished)
		print("Word Relay level %d: hints filled every blank" % level)
	quit()
