extends Control

signal accepted

@onready var agree_check: CheckButton = $Dimmer/Card/Margin/VBox/AgreeCheck
@onready var accept_button: Button = $Dimmer/Card/Margin/VBox/AcceptButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#fff8e8")
	card_style.border_color = Color("#ffc83d")
	card_style.set_border_width_all(4)
	card_style.set_corner_radius_all(22)
	card_style.shadow_color = Color(0.0, 0.08, 0.05, 0.55)
	card_style.shadow_size = 18
	$Dimmer/Card.add_theme_stylebox_override("panel", card_style)
	accept_button.disabled = true
	agree_check.toggled.connect(_on_agreement_toggled)
	accept_button.pressed.connect(_on_accept_pressed)

func _on_agreement_toggled(enabled: bool) -> void:
	accept_button.disabled = not enabled

func _on_accept_pressed() -> void:
	GameState.privacy_accepted = true
	GameState.save_progress()
	DailyReminder.refresh()
	accepted.emit()
	queue_free()
