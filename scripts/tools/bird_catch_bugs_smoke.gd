extends SceneTree

const StateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var picker = StateScript.new()
	var picks: Array[int] = []
	for _index in range(16):
		picker._pick_bug_catch_mode()
		picks.append(picker.bug_catch_mode)
	for index in range(4, picks.size()):
		assert(picks[index] == picks[index - 4])
		assert(picks[index] != picks[index - 1])
	assert(picks.slice(0, 4).has(0) and picks.slice(0, 4).has(1) and picks.slice(0, 4).has(2) and picks.slice(0, 4).has(3))
	picker.free()
	var state := get_root().get_node("GameState")
	for mode in range(4):
		for level in [1, 100, 400, 1000]:
			state.game_mode = "game_type"
			state.bug_catch_mode = mode
			state.type_level = level
			assert(change_scene_to_file("res://scenes/bird_catch_bugs.tscn") == OK)
			await process_frame
			await process_frame
			var scene := current_scene
			assert(scene != null and scene.current_level == level and scene.current_mode == mode)
			assert(scene.level_label.text.ends_with("LEVEL %d" % level))
			assert(not scene.level_label.text.contains("/"))
			assert(scene.level_label.has_theme_stylebox_override("normal"))
			assert(scene.hearts_label.has_theme_stylebox_override("normal"))
			assert(scene.bird_icon.size.x <= 38.0 and scene.bird_icon.size.y <= 38.0)
			assert(scene.bug_area.size.x > 200.0 and scene.bugs.size() == 6)
			assert(scene.targets.size() >= 5 and scene.targets.size() <= 12)
			assert(scene.targets.count(mode) == scene.targets.size())
			var correct_count := 0
			for bug in scene.bugs:
				if scene._is_correct_bug(bug):
					correct_count += 1
			assert(correct_count == (2 if mode < 2 else 1))
			if mode == 0 and level == 1:
				scene._toggle_pause()
				assert(paused and scene.pause_button.text == "▶")
				scene._toggle_pause()
				assert(not paused and scene.pause_button.text == "Ⅱ")
				var first_bug = scene.bugs.filter(func(bug): return scene._is_correct_bug(bug))[0]
				scene._tap_bug(first_bug)
				await create_timer(0.9).timeout
				assert(scene.target_index == 1 and scene.bird_icon.visible and not scene.catching)
			if mode >= 2:
				for step in range(3):
					scene.target_index = step
					scene._update_prompt()
					scene._refresh_bugs()
					assert(scene.bugs.any(func(bug): return scene._is_correct_bug(bug)))
					assert(scene.prompt_label.text.contains("×") if mode == 2 else scene.prompt_label.text.contains("DIVISIBLE"))
			print("Bird Catch Bugs %s level %d loaded" % [scene.TYPE_NAMES[mode], level])
	quit()
