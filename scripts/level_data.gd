class_name LevelData
extends RefCounted

const LEVEL_PATHS := ["res://assets/data/easy_levels.json", "res://assets/data/medium_levels.json", "res://assets/data/hard_levels.json", "res://assets/data/expert_levels.json"]
static var _difficulty_levels: Dictionary = {}

static func _load_difficulty(index: int) -> Array:
	index = clampi(index, 0, LEVEL_PATHS.size() - 1)
	if _difficulty_levels.has(index):
		return _difficulty_levels[index]
	var file := FileAccess.open(LEVEL_PATHS[index], FileAccess.READ)
	if file == null:
		push_error("Could not load level bank: " + LEVEL_PATHS[index])
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid level JSON: " + LEVEL_PATHS[index])
		return []
	var levels: Array = parsed.get("levels", [])
	_difficulty_levels[index] = levels
	return levels

static func get_level(level_num: int) -> Dictionary:
	var levels := _load_difficulty(GameState.difficulty_index)
	var index := clampi(level_num, 1, 1000) - 1
	if index < levels.size():
		var level_dict: Dictionary = levels[index].duplicate(true)
		var bank: Array = level_dict.get("bank", [])
		var is_invalid := bank.size() == 0 or (bank.size() > 0 and str(bank[0]).strip_edges() == "")
		if not is_invalid:
			return level_dict
	return get_procedural_level(level_num)

static func get_procedural_level(level_num: int) -> Dictionary:
	var cells: Array = []
	var cell_map: Dictionary = {}
	var use_division := level_num >= 150 and (level_num + GameState.win_streak) % 5 == 0
	var use_multiplication := not use_division and level_num >= 100 and (level_num + GameState.win_streak) % 3 == 0
	var equation_operator := "+"
	if use_division:
		equation_operator = GameState.divide_symbol
	elif use_multiplication:
		equation_operator = GameState.multiply_symbol

	# Deterministic values keep every generated level stable while allowing
	# the game to continue for any level number without a final level.
	var a := 2 + (level_num * 3) % 7
	var b := 1 + (level_num * 5) % 8
	var d := 2 + (level_num * 7) % 7
	var e := 1 + (level_num * 11) % 8
	var left_top := _sum_matrix(a, b, d, e)
	var left_lower := _continued_sum_matrix(left_top[2], 1 + level_num % 6, 2 + (level_num * 2) % 7)

	var ra := 3 + (level_num * 2) % 7
	var rb := 1 + (level_num * 4) % 8
	var rd := 2 + (level_num * 6) % 7
	var re := 1 + (level_num * 9) % 8
	var right_top := _sum_matrix(ra, rb, rd, re)
	var right_lower := _continued_sum_matrix(right_top[2], 2 + level_num % 5, 1 + (level_num * 3) % 7)
	if use_multiplication:
		a = 2 + level_num % 3
		b = 2 + (level_num * 2) % 3
		d = 2 + (level_num * 3) % 3
		e = 2 + (level_num * 5) % 3
		left_top = _product_matrix(a, b, d, e)
		left_lower = _continued_product_matrix(left_top[2], 2 + level_num % 3, 2 + (level_num + 1) % 3)
		right_top = _product_matrix(b, a, e, d)
		right_lower = _continued_product_matrix(right_top[2], 2 + (level_num + 2) % 3, 2 + level_num % 3)
	elif use_division:
		left_top = [[64, 8, 8], [8, 2, 4], [8, 4, 2]]
		left_lower = [[8, 4, 2], [4, 2, 2], [2, 2, 1]]
		right_top = [[81, 9, 9], [9, 3, 3], [9, 3, 3]]
		right_lower = [[9, 3, 3], [3, 3, 1], [3, 1, 3]]

	_add_equation_block(cell_map, 0, 0, left_top, equation_operator)
	_add_equation_block(cell_map, 4, 0, left_lower, equation_operator)
	_add_equation_block(cell_map, 0, 6, right_top, equation_operator)
	_add_equation_block(cell_map, 4, 6, right_lower, equation_operator)

	for cell in cell_map.values():
		cells.append(cell)

	var bank: Array = []
	var answer_positions := [
		Vector2i(0, 2), Vector2i(2, 0), Vector2i(2, 4),
		Vector2i(0, 8), Vector2i(2, 6), Vector2i(2, 10),
		Vector2i(6, 0), Vector2i(6, 4), Vector2i(8, 2),
		Vector2i(6, 8), Vector2i(8, 6), Vector2i(8, 10)
	]
	for position in answer_positions:
		var cell: Dictionary = cell_map[position]
		var answer := str(cell["val"])
		cell.erase("val")
		cell["type"] = "empty"
		cell["target"] = answer
		bank.append(answer)

	return {
		"level_num": level_num,
		"title": "Math Challenge." + str(level_num),
		"difficulty": _difficulty_for_level(level_num),
		"rows": 9,
		"cols": 11,
		"cells": cells,
		"bank": bank
	}

static func _sum_matrix(a: int, b: int, d: int, e: int) -> Array:
	return [
		[a, b, a + b],
		[d, e, d + e],
		[a + d, b + e, a + b + d + e]
	]

static func _continued_sum_matrix(top_row: Array, d: int, e: int) -> Array:
	return [
		[top_row[0], top_row[1], top_row[2]],
		[d, e, d + e],
		[top_row[0] + d, top_row[1] + e, top_row[2] + d + e]
	]

static func _product_matrix(a: int, b: int, d: int, e: int) -> Array:
	return [
		[a, b, a * b],
		[d, e, d * e],
		[a * d, b * e, a * b * d * e]
	]

static func _continued_product_matrix(top_row: Array, d: int, e: int) -> Array:
	return [
		[top_row[0], top_row[1], top_row[2]],
		[d, e, d * e],
		[top_row[0] * d, top_row[1] * e, top_row[2] * d * e]
	]

static func _difficulty_for_level(level_num: int) -> String:
	if level_num % 10 == 0:
		return "Boss Challenge"
	if level_num % 7 == 0:
		return "Bonus Puzzle"
	if level_num < 100:
		return "Advanced"
	if level_num < 500:
		return "Expert"
	if level_num < 1000:
		return "Master"
	return "Endless"

static func get_easy_level_3() -> Dictionary:
	return {
		"level_num": 3,
		"title": "Easy Subtraction.3",
		"difficulty": "Easy",
		"rows": 1,
		"cols": 5,
		"cells": [
			{"r": 0, "c": 0, "type": "fixed", "val": "4"},
			{"r": 0, "c": 1, "type": "fixed", "val": "-"},
			{"r": 0, "c": 2, "type": "empty", "target": "1"},
			{"r": 0, "c": 3, "type": "fixed", "val": "="},
			{"r": 0, "c": 4, "type": "fixed", "val": "3"}
		],
		"bank": ["1"]
	}
static func get_complex_level_3() -> Dictionary:
	var cells: Array = []
	var cell_map: Dictionary = {}

	# Four connected 5x5 equation blocks fill a 9x11 board. Each block is
	# generated from a 3x3 number matrix where every row and column is a valid
	# a + b = c equation. Adjacent upper/lower blocks share their middle edge.
	_add_equation_block(cell_map, 0, 0, [[2, 3, 5], [4, 1, 5], [6, 4, 10]])
	_add_equation_block(cell_map, 0, 6, [[3, 4, 7], [2, 5, 7], [5, 9, 14]])
	_add_equation_block(cell_map, 4, 0, [[6, 4, 10], [2, 3, 5], [8, 7, 15]])
	_add_equation_block(cell_map, 4, 6, [[5, 9, 14], [4, 2, 6], [9, 11, 20]])

	for cell in cell_map.values():
		cells.append(cell)

	var bank: Array = []
	var answer_positions := [
		Vector2i(0, 2), Vector2i(2, 0), Vector2i(2, 4),
		Vector2i(0, 8), Vector2i(2, 6), Vector2i(2, 10),
		Vector2i(6, 0), Vector2i(6, 4), Vector2i(8, 2),
		Vector2i(6, 8), Vector2i(8, 6), Vector2i(8, 10)
	]
	for position in answer_positions:
		var key := Vector2i(position.x, position.y)
		if not cell_map.has(key):
			continue
		var cell: Dictionary = cell_map[key]
		var answer := str(cell["val"])
		cell.erase("val")
		cell["type"] = "empty"
		cell["target"] = answer
		bank.append(answer)

	return {
		"level_num": 3,
		"title": "Math Crossword.3",
		"difficulty": "Complex",
		"rows": 9,
		"cols": 11,
		"cells": cells,
		"bank": bank
	}

static func _add_equation_block(
	cell_map: Dictionary,
	row_offset: int,
	column_offset: int,
	numbers: Array,
	equation_operator: String = "+"
) -> void:
	for number_row in range(3):
		for number_column in range(3):
			_set_math_cell(
				cell_map,
				row_offset + number_row * 2,
				column_offset + number_column * 2,
				str(numbers[number_row][number_column])
			)

	# Horizontal a + b = c equations.
	for row_index in range(3):
		var row := row_offset + row_index * 2
		_set_math_cell(cell_map, row, column_offset + 1, equation_operator)
		_set_math_cell(cell_map, row, column_offset + 3, "=")

	# Vertical a + b = c equations.
	for column_index in range(3):
		var column := column_offset + column_index * 2
		_set_math_cell(cell_map, row_offset + 1, column, equation_operator)
		_set_math_cell(cell_map, row_offset + 3, column, "=")

static func _set_math_cell(
	cell_map: Dictionary,
	row: int,
	column: int,
	value: String
) -> void:
	var key := Vector2i(row, column)
	cell_map[key] = {
		"r": row,
		"c": column,
		"type": "fixed",
		"val": value
	}

static func get_letter_pair_level(pair: String, level_num: int) -> Dictionary:
	var cells: Array = []
	var bank: Array = []

	# Each letter is drawn from intersecting five-cell equations.  Numbers at
	# intersections are shared, so every complete horizontal/vertical stroke is
	# mathematically valid instead of being a random digit silhouette.
	var first_cells := _math_letter_cells(pair.substr(0, 1), 0)
	var second_cells := _math_letter_cells(pair.substr(1, 1), 6)
	cells.append_array(first_cells)
	cells.append_array(second_cells)

	# Turn selected number cells into draggable answers. Operators always stay
	# visible, making the intended equation sequence immediately clear.
	var answer_positions := {
		1: [[0, 2], [2, 2], [4, 2], [0, 8], [2, 8], [4, 8]],
		2: [[0, 2], [2, 2], [4, 2], [0, 8], [2, 8], [4, 8]],
		3: [[0, 2], [2, 0], [4, 2], [0, 8], [2, 8], [4, 8]]
	}
	for position in answer_positions.get(level_num, []):
		for cell in cells:
			if cell["r"] == position[0] and cell["c"] == position[1] and cell.has("val"):
				var answer := str(cell["val"])
				cell.erase("val")
				cell["type"] = "empty"
				cell["target"] = answer
				bank.append(answer)
				break

	return {
		"level_num": level_num,
		"title": pair + " Math." + str(level_num),
		"difficulty": "Equation Letters",
		"rows": 5,
		"cols": 11,
		"cells": cells,
		"bank": bank
	}

static func _math_letter_cells(letter: String, offset: int) -> Array:
	match letter:
		"A":
			# Top 3+4=7; middle 2+3=5; left 3+2=5; right 7+5=12.
			return _cells_from_rows([
				["3", "+", "4", "=", "7"],
				["+", "", "", "", "+"],
				["2", "+", "3", "=", "5"],
				["=", "", "", "", "="],
				["5", "", "", "", "12"]
			], offset)
		"C":
			# Top 8-3=5; left 8-2=6; bottom 6+1=7.
			return _cells_from_rows([
				["8", "-", "3", "=", "5"],
				["-", "", "", "", ""],
				["2", "", "", "", ""],
				["=", "", "", "", ""],
				["6", "+", "1", "=", "7"]
			], offset)
		_: # B
			# Top 8+1=9; middle 3+2=5; bottom 5-1=4;
			# left 8-3=5 and right 9-5=4.
			return _cells_from_rows([
				["8", "+", "1", "=", "9"],
				["-", "", "", "", "-"],
				["3", "+", "2", "=", "5"],
				["=", "", "", "", "="],
				["5", "-", "1", "=", "4"]
			], offset)

static func _cells_from_rows(rows: Array, offset: int) -> Array:
	var result: Array = []
	for row in range(rows.size()):
		for column in range(rows[row].size()):
			var value: String = rows[row][column]
			if value.is_empty():
				continue
			result.append({
				"r": row,
				"c": column + offset,
				"type": "fixed",
				"val": value
			})
	return result

static func get_picture_pattern_level(
	pattern_name: String,
	bitmap: Array,
	level_num: int
) -> Dictionary:
	var cells: Array = []
	var bank: Array = []
	var stroke_index := 0

	for row in range(bitmap.size()):
		for column in range(9):
			if bitmap[row].substr(column, 1) != "1":
				continue
			var value := str(((row * 2 + column + level_num) % 9) + 1)
			var cell := {"r": row, "c": column}
			if stroke_index % 6 == (level_num - 4) % 6 and bank.size() < 7:
				cell["type"] = "empty"
				cell["target"] = value
				bank.append(value)
			else:
				cell["type"] = "fixed"
				cell["val"] = value
			cells.append(cell)
			stroke_index += 1

	return {
		"level_num": level_num,
		"title": pattern_name + " Pattern." + str(level_num),
		"difficulty": "Picture",
		"rows": bitmap.size(),
		"cols": 9,
		"cells": cells,
		"bank": bank
	}

static func get_apple_math_level() -> Dictionary:
	return {
		"level_num": 4, "title": "Apple Math.4", "difficulty": "Medium",
		"rows": 6, "cols": 9,
		"cells": [
			# Top: 3 + 4 = 7.
			{"r":0,"c":2,"type":"fixed","val":"3"}, {"r":0,"c":3,"type":"fixed","val":"+"},
			{"r":0,"c":4,"type":"empty","target":"4"}, {"r":0,"c":5,"type":"fixed","val":"="},
			{"r":0,"c":6,"type":"fixed","val":"7"},
			# Vertical operators.
			{"r":1,"c":2,"type":"fixed","val":"+"}, {"r":1,"c":6,"type":"fixed","val":"+"},
			# Wide middle: 8 - 3 = 5 + 4 = 9.
			{"r":2,"c":0,"type":"fixed","val":"8"}, {"r":2,"c":1,"type":"fixed","val":"-"},
			{"r":2,"c":2,"type":"empty","target":"3"}, {"r":2,"c":3,"type":"fixed","val":"="},
			{"r":2,"c":4,"type":"fixed","val":"5"}, {"r":2,"c":5,"type":"fixed","val":"+"},
			{"r":2,"c":6,"type":"empty","target":"4"}, {"r":2,"c":7,"type":"fixed","val":"="},
			{"r":2,"c":8,"type":"fixed","val":"9"},
			{"r":3,"c":2,"type":"fixed","val":"="}, {"r":3,"c":6,"type":"fixed","val":"="},
			# Bottom: 6 + 5 = 11. Vertically: 3 + 3 = 6 and 7 + 4 = 11.
			{"r":4,"c":2,"type":"fixed","val":"6"}, {"r":4,"c":3,"type":"fixed","val":"+"},
			{"r":4,"c":4,"type":"empty","target":"5"}, {"r":4,"c":5,"type":"fixed","val":"="},
			{"r":4,"c":6,"type":"fixed","val":"11"}
		],
		"bank": ["3", "4", "4", "5"]
	}

static func get_carrot_math_level() -> Dictionary:
	return {
		"level_num": 5, "title": "Carrot Math.5", "difficulty": "Medium",
		"rows": 5, "cols": 9,
		"cells": [
			# Wide top: 2 + 3 = 5 + 4 = 9.
			{"r":0,"c":0,"type":"fixed","val":"2"}, {"r":0,"c":1,"type":"fixed","val":"+"},
			{"r":0,"c":2,"type":"empty","target":"3"}, {"r":0,"c":3,"type":"fixed","val":"="},
			{"r":0,"c":4,"type":"fixed","val":"5"}, {"r":0,"c":5,"type":"fixed","val":"+"},
			{"r":0,"c":6,"type":"empty","target":"4"}, {"r":0,"c":7,"type":"fixed","val":"="},
			{"r":0,"c":8,"type":"fixed","val":"9"},
			{"r":1,"c":2,"type":"fixed","val":"+"}, {"r":1,"c":6,"type":"fixed","val":"+"},
			# Narrow middle: 4 + 2 = 6.
			{"r":2,"c":2,"type":"empty","target":"4"}, {"r":2,"c":3,"type":"fixed","val":"+"},
			{"r":2,"c":4,"type":"empty","target":"2"}, {"r":2,"c":5,"type":"fixed","val":"="},
			{"r":2,"c":6,"type":"fixed","val":"6"},
			{"r":3,"c":2,"type":"fixed","val":"="}, {"r":3,"c":6,"type":"fixed","val":"="},
			# Tip: 7 - 1 = 6. Vertically: 3 + 4 = 7 and 4 + 2 = 6.
			{"r":4,"c":2,"type":"fixed","val":"7"}, {"r":4,"c":3,"type":"fixed","val":"-"},
			{"r":4,"c":4,"type":"empty","target":"1"}, {"r":4,"c":5,"type":"fixed","val":"="},
			{"r":4,"c":6,"type":"fixed","val":"6"}
		],
		"bank": ["1", "2", "3", "4", "4"]
	}

static func get_car_math_level() -> Dictionary:
	return {
		"level_num": 6, "title": "Car Math.6", "difficulty": "Hard",
		"rows": 5, "cols": 9,
		"cells": [
			# Roof: 3 + 4 = 7.
			{"r":0,"c":2,"type":"fixed","val":"3"}, {"r":0,"c":3,"type":"fixed","val":"+"},
			{"r":0,"c":4,"type":"empty","target":"4"}, {"r":0,"c":5,"type":"fixed","val":"="},
			{"r":0,"c":6,"type":"fixed","val":"7"},
			{"r":1,"c":2,"type":"fixed","val":"+"}, {"r":1,"c":6,"type":"fixed","val":"-"},
			# Body: 8 - 6 = 2 + 3 = 5.
			{"r":2,"c":0,"type":"fixed","val":"8"}, {"r":2,"c":1,"type":"fixed","val":"-"},
			{"r":2,"c":2,"type":"empty","target":"6"}, {"r":2,"c":3,"type":"fixed","val":"="},
			{"r":2,"c":4,"type":"fixed","val":"2"}, {"r":2,"c":5,"type":"fixed","val":"+"},
			{"r":2,"c":6,"type":"empty","target":"3"}, {"r":2,"c":7,"type":"fixed","val":"="},
			{"r":2,"c":8,"type":"fixed","val":"5"},
			{"r":3,"c":2,"type":"fixed","val":"="}, {"r":3,"c":6,"type":"fixed","val":"="},
			# Wheels/base: 9 - 5 = 4. Vertically: 3 + 6 = 9 and 7 - 3 = 4.
			{"r":4,"c":2,"type":"fixed","val":"9"}, {"r":4,"c":3,"type":"fixed","val":"-"},
			{"r":4,"c":4,"type":"empty","target":"5"}, {"r":4,"c":5,"type":"fixed","val":"="},
			{"r":4,"c":6,"type":"fixed","val":"4"}
		],
		"bank": ["3", "4", "5", "6"]
	}

static func get_level_1() -> Dictionary:
	return {
		"level_num": 1,
		"title": "First Steps.1",
		"difficulty": "Beginner",
		"rows": 1,
		"cols": 5,
		"cells": [
			{"r": 0, "c": 0, "type": "fixed", "val": "2"},
			{"r": 0, "c": 1, "type": "fixed", "val": "+"},
			{"r": 0, "c": 2, "type": "empty", "target": "1"},
			{"r": 0, "c": 3, "type": "fixed", "val": "="},
			{"r": 0, "c": 4, "type": "fixed", "val": "3"}
		],
		"bank": ["1"]
	}

static func get_level_2() -> Dictionary:
	return {
		"level_num": 2,
		"title": "Easy Addition.2",
		"difficulty": "Easy",
		"rows": 1,
		"cols": 5,
		"cells": [
			{"r": 0, "c": 0, "type": "fixed", "val": "3"},
			{"r": 0, "c": 1, "type": "fixed", "val": "+"},
			{"r": 0, "c": 2, "type": "empty", "target": "2"},
			{"r": 0, "c": 3, "type": "fixed", "val": "="},
			{"r": 0, "c": 4, "type": "fixed", "val": "5"}
		],
		"bank": ["2"]
	}

static func get_level_3() -> Dictionary:
	return {
		"level_num": 3,
		"title": "Main Level.3",
		"difficulty": "Easy",
		"rows": 9,
		"cols": 9,
		"cells": [
			# Top-right: 6 - 4 = 2
			{"r": 0, "c": 4, "type": "fixed", "val": "6"},
			{"r": 0, "c": 5, "type": "fixed", "val": "-"},
			{"r": 0, "c": 6, "type": "empty", "target": "4"},
			{"r": 0, "c": 7, "type": "fixed", "val": "="},
			{"r": 0, "c": 8, "type": "fixed", "val": "2"},
			{"r": 1, "c": 8, "type": "fixed", "val": "+"},

			# Separate left branches and middle-right: 2 + 2 = 4
			{"r": 2, "c": 0, "type": "fixed", "val": "8"},
			{"r": 2, "c": 2, "type": "empty", "target": "6"},
			{"r": 2, "c": 4, "type": "fixed", "val": "2"},
			{"r": 2, "c": 5, "type": "fixed", "val": "+"},
			{"r": 2, "c": 6, "type": "empty", "target": "2"},
			{"r": 2, "c": 7, "type": "fixed", "val": "="},
			{"r": 2, "c": 8, "type": "empty", "target": "4"},

			# Operators are separated by spacer columns.
			{"r": 3, "c": 0, "type": "fixed", "val": "+"},
			{"r": 3, "c": 2, "type": "fixed", "val": "+"},
			{"r": 3, "c": 6, "type": "fixed", "val": "+"},
			{"r": 3, "c": 8, "type": "fixed", "val": "="},

			# Middle-right: 9 - 3 = 6
			{"r": 4, "c": 0, "type": "empty", "target": "2"},
			{"r": 4, "c": 2, "type": "fixed", "val": "3"},
			{"r": 4, "c": 4, "type": "fixed", "val": "9"},
			{"r": 4, "c": 5, "type": "fixed", "val": "-"},
			{"r": 4, "c": 6, "type": "empty", "target": "3"},
			{"r": 4, "c": 7, "type": "fixed", "val": "="},
			{"r": 4, "c": 8, "type": "fixed", "val": "6"},

			{"r": 5, "c": 0, "type": "fixed", "val": "="},
			{"r": 5, "c": 2, "type": "fixed", "val": "="},
			{"r": 5, "c": 4, "type": "fixed", "val": "-"},
			{"r": 5, "c": 6, "type": "fixed", "val": "="},

			# Left across: 10 - 9 = 1; vertical: 2 + 3 = 5.
			{"r": 6, "c": 0, "type": "fixed", "val": "10"},
			{"r": 6, "c": 1, "type": "fixed", "val": "-"},
			{"r": 6, "c": 2, "type": "fixed", "val": "9"},
			{"r": 6, "c": 3, "type": "fixed", "val": "="},
			{"r": 6, "c": 4, "type": "empty", "target": "1"},
			{"r": 6, "c": 6, "type": "fixed", "val": "5"},

			{"r": 7, "c": 4, "type": "fixed", "val": "="},

			# Bottom: 8 + 2 = 10; vertical: 9 - 1 = 8.
			{"r": 8, "c": 4, "type": "empty", "target": "8"},
			{"r": 8, "c": 5, "type": "fixed", "val": "+"},
			{"r": 8, "c": 6, "type": "fixed", "val": "2"},
			{"r": 8, "c": 7, "type": "fixed", "val": "="},
			{"r": 8, "c": 8, "type": "fixed", "val": "10"}
		],
		"bank": ["1", "2", "2", "3", "4", "4", "6", "8"]
	}

static func get_level_4() -> Dictionary:
	return {
		"level_num": 4,
		"title": "T Puzzle.4",
		"difficulty": "Medium",
		"rows": 5,
		"cols": 9,
		"cells": [
			# Top of the T: 9 - 4 = 5.
			{"r": 0, "c": 2, "type": "fixed", "val": "9"},
			{"r": 0, "c": 3, "type": "fixed", "val": "-"},
			{"r": 0, "c": 4, "type": "empty", "target": "4"},
			{"r": 0, "c": 5, "type": "fixed", "val": "="},
			{"r": 0, "c": 6, "type": "fixed", "val": "5"},

			# Vertical stem starts at the shared 4.
			{"r": 1, "c": 4, "type": "fixed", "val": "+"},

			# Middle bar: 6 - 3 = 3.
			{"r": 2, "c": 2, "type": "fixed", "val": "6"},
			{"r": 2, "c": 3, "type": "fixed", "val": "-"},
			{"r": 2, "c": 4, "type": "empty", "target": "3"},
			{"r": 2, "c": 5, "type": "fixed", "val": "="},
			{"r": 2, "c": 6, "type": "fixed", "val": "3"},
			{"r": 3, "c": 4, "type": "fixed", "val": "="},

			# Bottom bar shares 7 from 4 + 3 = 7: 7 - 2 = 5.
			{"r": 4, "c": 4, "type": "fixed", "val": "7"},
			{"r": 4, "c": 5, "type": "fixed", "val": "-"},
			{"r": 4, "c": 6, "type": "empty", "target": "2"},
			{"r": 4, "c": 7, "type": "fixed", "val": "="},
			{"r": 4, "c": 8, "type": "fixed", "val": "5"}
		],
		"bank": ["2", "3", "4"]
	}

static func get_level_5() -> Dictionary:
	return {
		"level_num": 5,
		"title": "H Puzzle.5",
		"difficulty": "Medium",
		"rows": 5,
		"cols": 9,
		"cells": [
			# Two separated vertical sides of the H.
			{"r": 0, "c": 0, "type": "fixed", "val": "8"},
			{"r": 0, "c": 8, "type": "fixed", "val": "15"},
			{"r": 1, "c": 0, "type": "fixed", "val": "+"},
			{"r": 1, "c": 8, "type": "fixed", "val": "-"},

			# H crossbar: 4 + 5 = 9.
			{"r": 2, "c": 0, "type": "empty", "target": "4"},
			{"r": 2, "c": 2, "type": "fixed", "val": "+"},
			{"r": 2, "c": 4, "type": "empty", "target": "5"},
			{"r": 2, "c": 6, "type": "fixed", "val": "="},
			{"r": 2, "c": 8, "type": "empty", "target": "9"},
			{"r": 3, "c": 0, "type": "fixed", "val": "="},
			{"r": 3, "c": 8, "type": "fixed", "val": "="},

			# Left: 8 + 4 = 12. Right: 15 - 9 = 6.
			{"r": 4, "c": 0, "type": "fixed", "val": "12"},
			{"r": 4, "c": 8, "type": "fixed", "val": "6"}
		],
		"bank": ["4", "5", "9"]
	}

static func get_level_6() -> Dictionary:
	return {
		"level_num": 6,
		"title": "L Puzzle.6",
		"difficulty": "Medium",
		"rows": 5,
		"cols": 5,
		"cells": [
			# Vertical 7 + 5 = 12.
			{"r": 0, "c": 0, "type": "fixed", "val": "7"},
			{"r": 1, "c": 0, "type": "fixed", "val": "+"},
			{"r": 2, "c": 0, "type": "empty", "target": "5"},
			{"r": 3, "c": 0, "type": "fixed", "val": "="},
			# Bottom of the L: 12 - 4 = 8.
			{"r": 4, "c": 0, "type": "fixed", "val": "12"},
			{"r": 4, "c": 1, "type": "fixed", "val": "-"},
			{"r": 4, "c": 2, "type": "empty", "target": "4"},
			{"r": 4, "c": 3, "type": "fixed", "val": "="},
			{"r": 4, "c": 4, "type": "fixed", "val": "8"}
		],
		"bank": ["4", "5"]
	}

static func get_level_7() -> Dictionary:
	return {
		"level_num": 7,
		"title": "U Puzzle.7",
		"difficulty": "Medium",
		"rows": 5,
		"cols": 9,
		"cells": [
			# Left 9 - 3 = 6; right 14 - 6 = 8.
			{"r": 0, "c": 0, "type": "fixed", "val": "9"},
			{"r": 0, "c": 8, "type": "fixed", "val": "14"},
			{"r": 1, "c": 0, "type": "fixed", "val": "-"},
			{"r": 1, "c": 8, "type": "fixed", "val": "-"},
			{"r": 2, "c": 0, "type": "empty", "target": "3"},
			{"r": 2, "c": 8, "type": "empty", "target": "6"},
			{"r": 3, "c": 0, "type": "fixed", "val": "="},
			{"r": 3, "c": 8, "type": "fixed", "val": "="},
			# Bottom: 6 + 2 = 8.
			{"r": 4, "c": 0, "type": "fixed", "val": "6"},
			{"r": 4, "c": 2, "type": "fixed", "val": "+"},
			{"r": 4, "c": 4, "type": "empty", "target": "2"},
			{"r": 4, "c": 6, "type": "fixed", "val": "="},
			{"r": 4, "c": 8, "type": "fixed", "val": "8"}
		],
		"bank": ["2", "3", "6"]
	}

static func get_level_8() -> Dictionary:
	return {
		"level_num": 8,
		"title": "Plus Puzzle.8",
		"difficulty": "Hard",
		"rows": 5,
		"cols": 5,
		"cells": [
			# Vertical: 8 + 4 = 12.
			{"r": 0, "c": 2, "type": "fixed", "val": "8"},
			{"r": 1, "c": 2, "type": "fixed", "val": "+"},
			# Horizontal: 7 - 4 = 3, sharing the center.
			{"r": 2, "c": 0, "type": "fixed", "val": "7"},
			{"r": 2, "c": 1, "type": "fixed", "val": "-"},
			{"r": 2, "c": 2, "type": "empty", "target": "4"},
			{"r": 2, "c": 3, "type": "fixed", "val": "="},
			{"r": 2, "c": 4, "type": "fixed", "val": "3"},
			{"r": 3, "c": 2, "type": "fixed", "val": "="},
			{"r": 4, "c": 2, "type": "fixed", "val": "12"}
		],
		"bank": ["4"]
	}

static func get_level_9() -> Dictionary:
	return {
		"level_num": 9,
		"title": "Z Puzzle.9",
		"difficulty": "Hard",
		"rows": 9,
		"cols": 5,
		"cells": [
			# Top: 4 + 5 = 9.
			{"r": 0, "c": 0, "type": "fixed", "val": "4"},
			{"r": 0, "c": 1, "type": "fixed", "val": "+"},
			{"r": 0, "c": 2, "type": "empty", "target": "5"},
			{"r": 0, "c": 3, "type": "fixed", "val": "="},
			{"r": 0, "c": 4, "type": "fixed", "val": "9"},
			# Right side: 9 + 1 = 10.
			{"r": 1, "c": 4, "type": "fixed", "val": "+"},
			{"r": 2, "c": 4, "type": "empty", "target": "1"},
			{"r": 3, "c": 4, "type": "fixed", "val": "="},
			# Middle bridge: 7 + 3 = 10.
			{"r": 4, "c": 0, "type": "fixed", "val": "7"},
			{"r": 4, "c": 1, "type": "fixed", "val": "+"},
			{"r": 4, "c": 2, "type": "empty", "target": "3"},
			{"r": 4, "c": 3, "type": "fixed", "val": "="},
			{"r": 4, "c": 4, "type": "fixed", "val": "10"},
			# Left side: 7 - 1 = 6.
			{"r": 5, "c": 0, "type": "fixed", "val": "-"},
			{"r": 6, "c": 0, "type": "empty", "target": "1"},
			{"r": 7, "c": 0, "type": "fixed", "val": "="},
			{"r": 8, "c": 0, "type": "fixed", "val": "6"}
		],
		"bank": ["1", "1", "3", "5"]
	}

static func get_level_10() -> Dictionary:
	return {
		"level_num": 10,
		"title": "Frame Puzzle.10",
		"difficulty": "Hard",
		"rows": 5,
		"cols": 5,
		"cells": [
			# Top: 8 + 4 = 12.
			{"r": 0, "c": 0, "type": "fixed", "val": "8"},
			{"r": 0, "c": 1, "type": "fixed", "val": "+"},
			{"r": 0, "c": 2, "type": "empty", "target": "4"},
			{"r": 0, "c": 3, "type": "fixed", "val": "="},
			{"r": 0, "c": 4, "type": "fixed", "val": "12"},
			# Frame sides.
			{"r": 1, "c": 0, "type": "fixed", "val": "+"},
			{"r": 1, "c": 4, "type": "fixed", "val": "-"},
			{"r": 2, "c": 0, "type": "empty", "target": "5"},
			{"r": 2, "c": 4, "type": "empty", "target": "3"},
			{"r": 3, "c": 0, "type": "fixed", "val": "="},
			{"r": 3, "c": 4, "type": "fixed", "val": "="},
			# Bottom: 13 - 4 = 9.
			{"r": 4, "c": 0, "type": "fixed", "val": "13"},
			{"r": 4, "c": 1, "type": "fixed", "val": "-"},
			{"r": 4, "c": 2, "type": "empty", "target": "4"},
			{"r": 4, "c": 3, "type": "fixed", "val": "="},
			{"r": 4, "c": 4, "type": "fixed", "val": "9"}
		],
		"bank": ["3", "4", "4", "5"]
	}
