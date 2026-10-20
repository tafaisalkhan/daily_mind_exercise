extends SceneTree

const StateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://math_mind_progress.cfg"
	var existed := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	var state = StateScript.new()
	for type_index in range(8):
		state.game_type_progress[type_index] = 1
	for type_index in range(8):
		state.start_game_type(type_index)
		assert(state.type_level == 1)
		state.register_game_type_win(type_index, 1, 3, 15)
		assert(state.type_level == 2)
	var restored = StateScript.new()
	restored.load_progress()
	for type_index in range(8):
		restored.start_game_type(type_index)
		assert(restored.type_level == 2)
	restored.game_type_progress[3] = 1000
	restored.start_game_type(3)
	restored.register_game_type_win(3, 1000, 3, 15)
	assert(restored.game_type_progress[3] == 1001)
	assert(restored.next_game_type_level(3) == 1)
	restored.register_game_type_win(3, 1, 3, 15)
	assert(restored.game_type_progress[3] == 1001)
	assert(restored.next_game_type_level(3) == 2)
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.free()
	restored.free()
	print("Progress save/reload and 1,000-level completion passed")
	quit()
