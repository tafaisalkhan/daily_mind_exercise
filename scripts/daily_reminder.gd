extends Node

func _ready() -> void:
	_apply_setting()

func set_enabled(enabled: bool) -> void:
	GameState.daily_notifications = enabled
	GameState.save_progress()
	_apply_setting()

func refresh() -> void:
	_apply_setting()

func consume_open_daily_request() -> bool:
	if OS.get_name() != "Android":
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var reminder = JavaClassWrapper.wrap("com.godot.game.DailyReminder")
	var open_daily: bool = reminder.consumeOpenDaily(runtime.getActivity())
	var error = JavaClassWrapper.get_exception()
	if error != null:
		push_warning("Could not read daily reminder launch: %s" % error)
		return false
	return open_daily

func _apply_setting() -> void:
	if OS.get_name() != "Android" or not GameState.privacy_accepted:
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return
	var reminder = JavaClassWrapper.wrap("com.godot.game.DailyReminder")
	reminder.setEnabled(runtime.getActivity(), GameState.daily_notifications)
	var error = JavaClassWrapper.get_exception()
	if error != null:
		push_warning("Daily reminder could not be scheduled: %s" % error)
