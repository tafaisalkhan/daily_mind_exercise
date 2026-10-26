extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := get_root().get_node("GameState")
	for mistakes in range(5):
		var expected_stars := 3 if mistakes == 0 else (2 if mistakes == 1 else 1)
		var expected_coins := 5 if mistakes == 0 else (3 if mistakes == 1 else 1)
		var stars: int = state.stars_for_mistakes(mistakes)
		assert(stars == expected_stars)
		assert(state.coins_for_stars(stars) == expected_coins)
	print("Reward rules passed: 0 mistakes = 3 stars/5 coins, 1 = 2/3, 2+ = 1/1")
	quit()
