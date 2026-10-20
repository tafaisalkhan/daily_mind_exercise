class_name ChapterThemes
extends RefCounted

const WORLD_SIZE: int = 200
const MANIFEST_PATH := "res://assets/data/level_manifest.json"
const GAME_TYPES := [
	{"id": "synonyms", "background": "res://assets/level_backgrounds/synonym-meadow.png", "sprite": "res://assets/gameplay_sprites/synonym-balloons.png"},
	{"id": "word_builder", "background": "res://assets/level_backgrounds/word-garden.png", "sprite": "res://assets/gameplay_sprites/word-builder.png"},
	{"id": "sentence_train", "background": "res://assets/level_backgrounds/sentence-valley.png", "sprite": "res://assets/gameplay_sprites/sentence-train.png"},
	{"id": "number_bridge", "background": "res://assets/level_backgrounds/number-river.png", "sprite": "res://assets/gameplay_sprites/number-bridge.png"},
	{"id": "number_balance", "background": "res://assets/level_backgrounds/balance-tower.png", "sprite": "res://assets/gameplay_sprites/balance-scale.png"},
	{"id": "number_maze", "background": "res://assets/level_backgrounds/number-maze.png", "sprite": "res://assets/gameplay_sprites/maze-explorer.png"},
	{"id": "number_hunt", "background": "res://assets/level_backgrounds/number-hunt.png", "sprite": "res://assets/gameplay_sprites/number-orbs.png"},
	{"id": "word_relay", "background": "res://assets/level_backgrounds/word-relay.png", "sprite": "res://assets/gameplay_sprites/word-relay.png"}
]

static var _worlds: Array = []

static func _load_worlds() -> Array:
	if not _worlds.is_empty():
		return _worlds
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_worlds = parsed.get("worlds", [])
	return _worlds

static func index_for_level(level: int) -> int:
	# Each themed world contains 200 levels.
	return int((maxi(level, 1) - 1) / WORLD_SIZE) % 5

static func chapter_for_level(level: int) -> int:
	return index_for_level(level) + 1

static func game_type_for_level(level: int) -> Dictionary:
	return GAME_TYPES[int((maxi(level, 1) - 1) / 2) % GAME_TYPES.size()]

static func theme_for_level(level: int) -> Dictionary:
	var worlds := _load_worlds()
	var index := index_for_level(level)
	if index < worlds.size():
		var world: Dictionary = worlds[index].duplicate(true)
		var popup_frames := [
			"res://assets/generated/victory-frame.png",
			"res://assets/generated/victory-frame-ice.png",
			"res://assets/generated/victory-frame-ocean.png",
			"res://assets/generated/victory-frame-mountain.png",
			"res://assets/generated/victory-frame-volcano.png"
		]
		world["popup_frame"] = popup_frames[index]
		world["tint"] = Color.WHITE
		world["button"] = Color(str(world.get("button_color", "#249b58")))
		world["popup"] = Color(str(world.get("popup_tint", "#e7ffe8")))
		return world
	return {
		"name": "Jungle Academy",
		"icon": "J",
		"background": "res://assets/generated/world-jungle.png",
		"tint": Color.WHITE,
		"button": Color("#249b58"),
		"popup": Color("#e7ffe8"),
		"popup_frame": "res://assets/generated/victory-frame.png"
	}

static func level_range(chapter: int) -> String:
	var first := (chapter - 1) * WORLD_SIZE + 1
	return "%d–%d" % [first, first + WORLD_SIZE - 1]
static func total_levels() -> int:
	return 1000


