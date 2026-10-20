extends Node

const REMOVE_ADS_PRODUCT := "remove_ads"

signal status_changed(message: String)
signal ads_removed_changed(removed: bool)

var _client: BillingClient
var _product_available := false
var _connected := false

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("GodotGooglePlayBilling"):
		status_changed.emit("Purchases are available through Google Play")
		return
	_client = BillingClient.new()
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledged)
	_client.start_connection()

func purchase_remove_ads() -> void:
	if GameState.ads_removed:
		status_changed.emit("Ads are already removed")
		return
	if not _connected or _client == null:
		status_changed.emit("Connect to Google Play to purchase")
		return
	if not _product_available:
		_client.query_product_details(PackedStringArray([REMOVE_ADS_PRODUCT]), BillingClient.ProductType.INAPP)
		status_changed.emit("Checking Remove Ads in Google Play")
		return
	var result: Dictionary = _client.purchase(REMOVE_ADS_PRODUCT)
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		status_changed.emit(str(result.get("debug_message", "Could not start purchase")))

func restore_purchases() -> void:
	if not _connected or _client == null:
		status_changed.emit("Connect to Google Play to restore purchases")
		return
	status_changed.emit("Checking purchases...")
	_client.query_purchases(BillingClient.ProductType.INAPP)

func _on_connected() -> void:
	_connected = true
	_client.query_product_details(PackedStringArray([REMOVE_ADS_PRODUCT]), BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)

func _on_disconnected() -> void:
	_connected = false
	_product_available = false
	status_changed.emit("Google Play disconnected")

func _on_connect_error(_code: int, message: String) -> void:
	_connected = false
	status_changed.emit(message if not message.is_empty() else "Google Play Billing unavailable")

func _on_product_details(response: Dictionary) -> void:
	_product_available = int(response.get("response_code", -1)) == BillingClient.BillingResponseCode.OK and not response.get("product_details", []).is_empty()
	if not GameState.ads_removed:
		status_changed.emit("Remove banners and interstitials is ready" if _product_available else "Set up remove_ads in Google Play Console")

func _on_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		status_changed.emit(str(response.get("debug_message", "Could not check purchases")))
		return
	var owned := false
	for purchase in response.get("purchases", []):
		if _process_purchase(purchase):
			owned = true
	_set_ads_removed(owned)
	status_changed.emit("Ads removed" if owned else "No Remove Ads purchase found")

func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		status_changed.emit("Purchase cancelled")
		return
	if code != BillingClient.BillingResponseCode.OK:
		status_changed.emit(str(response.get("debug_message", "Purchase failed")))
		return
	for purchase in response.get("purchases", []):
		_process_purchase(purchase)

func _process_purchase(purchase: Dictionary) -> bool:
	if REMOVE_ADS_PRODUCT not in purchase.get("product_ids", PackedStringArray()):
		return false
	if int(purchase.get("purchase_state", -1)) != BillingClient.PurchaseState.PURCHASED:
		status_changed.emit("Purchase pending")
		return false
	_set_ads_removed(true)
	if not bool(purchase.get("is_acknowledged", false)):
		_client.acknowledge_purchase(str(purchase.get("purchase_token", "")))
	return true

func _on_acknowledged(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		status_changed.emit("Purchase completed; Google Play acknowledgement is pending")

func _set_ads_removed(removed: bool) -> void:
	if GameState.ads_removed == removed:
		return
	GameState.ads_removed = removed
	GameState.save_progress()
	if removed:
		AdManager.hide_banner()
	else:
		AdManager.show_banner()
	ads_removed_changed.emit(removed)
