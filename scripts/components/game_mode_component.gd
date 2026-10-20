class_name GameModeComponent
extends Control

## Base component contract for modular mini-game modes hosted in GameTypeLevel.
## To add a new interactive game type in the future, extend GameModeComponent,
## implement the virtual lifecycle methods below, and register the script in
## GameTypeLevel.MODE_COMPONENTS.

signal level_completed()
signal mistake_made(source_button: Button)

var level_data: Dictionary = {}
var stage_index: int = 0
var choices_grid: GridContainer = null
var is_finished: bool = false

func setup_level(p_level_data: Dictionary, p_stage_index: int, p_choices_grid: GridContainer) -> void:
	level_data = p_level_data
	stage_index = p_stage_index
	choices_grid = p_choices_grid
	is_finished = false
	_on_setup_level()

func _on_setup_level() -> void:
	pass

func rebuild_choices(_grid: GridContainer) -> bool:
	return false

func use_hint(_grid: GridContainer) -> bool:
	return false

func cancel_interactions() -> void:
	pass

func set_finished(value: bool) -> void:
	is_finished = value
	if value:
		cancel_interactions()

func is_timer_paused() -> bool:
	return false

func get_prompt_override() -> String:
	return ""

func get_choices_height(choice_count: int) -> float:
	return 180.0 if choice_count > 5 else 140.0
