class_name ResultEffects
extends RefCounted

const COIN_TEXTURE := preload("res://assets/generated/reward-coin.png")

static func celebrate(host: Control, star_row: HBoxContainer, stars_earned: int, coin_target: Vector2 = Vector2.ZERO) -> void:
	for index in range(mini(stars_earned, star_row.get_child_count())):
		var star: Control = star_row.get_child(index)
		star.pivot_offset = star.size * 0.5
		star.scale = Vector2(0.2, 0.2)
		star.modulate.a = 0.0
		var star_tween := host.create_tween()
		star_tween.tween_interval(0.12 + index * 0.16)
		star_tween.tween_callback(AudioManager.play_star)
		star_tween.tween_property(star, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		star_tween.parallel().tween_property(star, "modulate:a", 1.0, 0.2)
	var target := coin_target if coin_target != Vector2.ZERO else Vector2(host.size.x - 55.0, 66.0)
	var origin := Vector2(host.size.x * 0.5, host.size.y * 0.53)
	for index in range(7):
		var coin := TextureRect.new()
		coin.texture = COIN_TEXTURE
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(34, 34)
		coin.size = Vector2(34, 34)
		coin.position = origin + Vector2(randf_range(-75.0, 75.0), randf_range(-25.0, 35.0))
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.z_index = 80
		host.add_child(coin)
		var coin_tween := host.create_tween()
		coin_tween.tween_interval(0.2 + index * 0.08)
		if index == 0:
			coin_tween.tween_callback(AudioManager.play_coin)
		coin_tween.tween_property(coin, "position", target, 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		coin_tween.parallel().tween_property(coin, "scale", Vector2(0.45, 0.45), 0.58)
		coin_tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.58)
		coin_tween.tween_callback(coin.queue_free)
