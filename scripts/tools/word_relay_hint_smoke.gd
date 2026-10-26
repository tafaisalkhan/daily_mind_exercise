extends SceneTree

class FakeBanner:
	var shown := false
	var show_count := 0
	var hide_count := 0
	func show() -> void:
		shown = true
		show_count += 1
	func hide() -> void:
		shown = false
		hide_count += 1
	func destroy() -> void:
		shown = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := get_root().get_node("GameState")
	for level in [1, 2, 9, 1000]:
		state.start_game_type(7)
		state.type_level = level
		assert(change_scene_to_file("res://scenes/game_type_level.tscn") == OK)
		await process_frame
		await process_frame
		var scene := current_scene
		var relay = scene.active_component
		assert(relay != null)
		assert(is_instance_valid(relay.owl_hint_button))
		assert(scene.hint_button.text == "HINT")
		var remaining := 0
		for filled in relay.filled:
			if not filled:
				remaining += 1
		assert(remaining > 0)
		scene._hint_unavailable("Ad unavailable")
		assert(relay.status_label.text == "Ad unavailable")
		for index in range(remaining):
			if index == 0:
				relay._on_owl_hint_pressed()
			else:
				scene._use_hint()
			var new_remaining := 0
			for filled in relay.filled:
				if not filled:
					new_remaining += 1
			assert(new_remaining == remaining - index - 1)
		assert(scene.finished)
		print("Word Relay level %d: hints (owl bubble + button) filled every blank" % level)

	# Verify AdManager top (5s show / 2s hide cycle) and bottom (always shown) banner logic
	var ad_mgr := get_root().get_node("AdManager")
	var top_banner := FakeBanner.new()
	var bottom_banner := FakeBanner.new()
	ad_mgr._plugin_available = true
	ad_mgr.is_initialized = true
	ad_mgr._banner_view_top = top_banner
	ad_mgr._banner_view_bottom = bottom_banner
	ad_mgr._top_banner_loaded = true
	ad_mgr.show_banner()
	assert(top_banner.shown and bottom_banner.shown)
	assert(is_equal_approx(ad_mgr._top_banner_cycle_timer.wait_time, 5.0))
	ad_mgr._on_top_banner_cycle_timeout()
	assert(not top_banner.shown and bottom_banner.shown)
	assert(is_equal_approx(ad_mgr._top_banner_cycle_timer.wait_time, 2.0))
	ad_mgr._on_top_banner_cycle_timeout()
	assert(top_banner.shown and bottom_banner.shown)
	assert(is_equal_approx(ad_mgr._top_banner_cycle_timer.wait_time, 5.0))
	print("AdManager banner cycle verified: top shows 5s -> hides 2s -> shows 5s, bottom stays shown")
	quit()
