extends Control

const BACK_ICON := preload("res://assets/ui/back-arrow.svg")

@onready var settings_panel: PanelContainer = $Margin/VBox/Panel
@onready var back_button: Button = $Margin/VBox/Header/BackButton
@onready var music_toggle: CheckButton = $Margin/VBox/Panel/Scroll/Content/MusicToggle
@onready var sfx_toggle: CheckButton = $Margin/VBox/Panel/Scroll/Content/SfxToggle
@onready var remove_ads_button: Button = $Margin/VBox/Panel/Scroll/Content/RemoveAdsButton
@onready var restore_ads_button: Button = $Margin/VBox/Panel/Scroll/Content/RestoreAdsButton
@onready var purchase_status: Label = $Margin/VBox/Panel/Scroll/Content/PurchaseStatus

func _ready() -> void:
	back_button.text = ""
	back_button.icon = BACK_ICON
	back_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	music_toggle.button_pressed = GameState.music_enabled
	sfx_toggle.button_pressed = GameState.sfx_enabled
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	back_button.pressed.connect(_go_back)
	remove_ads_button.pressed.connect(BillingManager.purchase_remove_ads)
	restore_ads_button.pressed.connect(BillingManager.restore_purchases)
	BillingManager.status_changed.connect(_on_billing_status)
	BillingManager.ads_removed_changed.connect(_on_ads_removed_changed)
	_apply_style()
	_update_purchase_status()

func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#fff1b8")
	panel_style.border_color = Color("#14865f")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(24)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.shadow_color = Color(0.02, 0.08, 0.05, 0.65)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 9)
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	for toggle in [music_toggle, sfx_toggle]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			toggle.add_theme_color_override(state, Color("#261b12"))
		toggle.add_theme_stylebox_override("normal", _button_style(Color("#fff8d9"), Color("#d7b348")))
		toggle.add_theme_stylebox_override("hover", _button_style(Color("#fffdf0"), Color("#f0c94d")))
		toggle.add_theme_stylebox_override("pressed", _button_style(Color("#d7f6e8"), Color("#14865f")))
		toggle.add_theme_stylebox_override("hover_pressed", _button_style(Color("#e7fff4"), Color("#14865f")))
	for button in [remove_ads_button, restore_ads_button]:
		button.add_theme_stylebox_override("normal", _button_style(Color("#ff8a3d"), Color("#b94716")))
		button.add_theme_stylebox_override("hover", _button_style(Color("#ffa14f"), Color("#b94716")))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#df6f2c"), Color("#8f3110")))
		button.add_theme_color_override("font_color", Color.WHITE)
	back_button.add_theme_stylebox_override("normal", _button_style(Color("#e94f45"), Color("#8f211d")))
	back_button.add_theme_color_override("font_color", Color.WHITE)
	settings_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.22)

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(5)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.02, 0.08, 0.05, 0.55)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	return style

func _go_back() -> void:
	if back_button.disabled:
		return
	back_button.disabled = true
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()

func _on_sfx_toggled(enabled: bool) -> void:
	GameState.sfx_enabled = enabled
	GameState.save_progress()

func _on_music_toggled(enabled: bool) -> void:
	GameState.music_enabled = enabled
	AudioManager.set_music_enabled(enabled)
	GameState.save_progress()

func _on_billing_status(message: String) -> void:
	purchase_status.text = message

func _on_ads_removed_changed(_removed: bool) -> void:
	_update_purchase_status()

func _update_purchase_status() -> void:
	if GameState.ads_removed:
		remove_ads_button.text = "BANNERS + INTERSTITIALS REMOVED"
		remove_ads_button.disabled = true
		purchase_status.text = "Rewarded ads remain available for hints and bonuses."
	else:
		remove_ads_button.text = "REMOVE BANNERS + INTERSTITIALS"
		remove_ads_button.disabled = false
		purchase_status.text = "One-time purchase. Rewarded ads remain available."
