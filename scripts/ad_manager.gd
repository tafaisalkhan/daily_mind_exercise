extends Node
## AdManager - Google AdMob integration (Poing AdMob Plugin v5)
## Test banners, completion interstitials, and optional rewarded hints.

# Google AdMob Ad Unit IDs
const ADMOB_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const BANNER_AD_ID: String = "ca-app-pub-3940256099942544/6300978111"
const INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/1033173712"
const REWARDED_AD_ID: String = "ca-app-pub-3940256099942544/5224354917"
const REWARDED_INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/5354046379"

static var instance: Node
static var is_initialized: bool = false
var _plugin_available: bool = false

signal rewarded_video_completed
signal rewarded_video_unavailable(message: String)
signal rewarded_interstitial_completed
signal rewarded_interstitial_unavailable(message: String)

# Cached loaded ad objects
var _banner_view_top = null
var _banner_view_bottom = null
var _interstitial_ad = null
var _interstitial_loading := false
var _rewarded_ad = null
var _rewarded_loading := false
var _rewarded_interstitial_ad = null
var _retry_timer: Timer

# REQUIRED: Keep callbacks alive so Godot doesn't garbage collect them!
var _init_listener = null
var _banner_cb_top = null
var _banner_cb_bottom = null
var _interstitial_cb = null
var _interstitial_content_cb = null
var _rewarded_cb = null
var _reward_listener = null
var _rewarded_interstitial_cb = null
var _rewarded_interstitial_content_cb = null
var _rewarded_interstitial_listener = null

var banner_id: String = BANNER_AD_ID
var interstitial_id: String = INTERSTITIAL_AD_ID
var rewarded_id: String = REWARDED_AD_ID
var rewarded_interstitial_id: String = REWARDED_INTERSTITIAL_AD_ID
var _hint_reward: Callable = Callable()
var _hint_unavailable: Callable = Callable()

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	_retry_timer = Timer.new()
	_retry_timer.wait_time = 20.0
	_retry_timer.timeout.connect(_retry_unavailable_ads)
	add_child(_retry_timer)
	print("[AdManager] _ready - checking for MobileAds plugin...")
	if OS.get_name() == "Android":
		_plugin_available = true
		
		# Auto-inject test IDs in debug builds to prevent No Fill errors
		if OS.has_feature("debug"):
			print("[AdManager] Debug build detected: Using Test IDs")
			banner_id = "ca-app-pub-3940256099942544/6300978111"
			interstitial_id = "ca-app-pub-3940256099942544/1033173712"
			rewarded_id = "ca-app-pub-3940256099942544/5224354917"
		rewarded_interstitial_id = "ca-app-pub-3940256099942544/5354046379"
			
		print("[AdManager] Running on Android - initializing AdMob with banner: ", banner_id)
		_init_admob()
	else:
		print("[AdManager] Not on Android - ads disabled (desktop/editor mode)")

func _on_scene_changed() -> void:
	# Banner views are native overlays. Keep both visible across menu and game scenes.
	show_banner()

func _init_admob() -> void:
	if not _plugin_available:
		return
	_init_listener = OnInitializationCompleteListener.new()
	_init_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		print("[AdManager] MobileAds native initialization complete!")
		is_initialized = true
		if not GameState.ads_removed:
			_load_banner_top()
			_load_banner_bottom()
			_load_interstitial()
		_load_rewarded()
		_retry_timer.start()
	
	MobileAds.initialize(_init_listener)
	print("[AdManager] MobileAds.initialize() requested")

# =================== BANNERS ===================

func _load_banner_top() -> void:
	if not is_initialized or GameState.ads_removed or _banner_view_top != null:
		return
	_banner_view_top = AdView.new(banner_id, AdSize.BANNER, AdPosition.TOP)
	_banner_cb_top = AdListener.new()
	_banner_cb_top.on_ad_loaded = func() -> void:
		print("[AdManager] Top banner loaded")
		if _banner_view_top and not GameState.ads_removed:
			_banner_view_top.show()
	_banner_cb_top.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("[AdManager] Top banner failed: ", error.message)
		if _banner_view_top:
			_banner_view_top.destroy()
			_banner_view_top = null
	_banner_view_top.ad_listener = _banner_cb_top
	_banner_view_top.load_ad(AdRequest.new())

func _load_banner_bottom() -> void:
	if not is_initialized or GameState.ads_removed or _banner_view_bottom != null:
		return

	_banner_view_bottom = AdView.new(banner_id, AdSize.BANNER, AdPosition.BOTTOM)
	_banner_cb_bottom = AdListener.new()
	_banner_cb_bottom.on_ad_loaded = func() -> void:
		print("[AdManager] Bottom banner loaded")
		if _banner_view_bottom and not GameState.ads_removed:
			_banner_view_bottom.show()
	_banner_cb_bottom.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("[AdManager] Bottom banner failed: ", error.message)
		if _banner_view_bottom:
			_banner_view_bottom.destroy()
			_banner_view_bottom = null
	_banner_view_bottom.ad_listener = _banner_cb_bottom
	_banner_view_bottom.load_ad(AdRequest.new())

func show_banner() -> void:
	if GameState.ads_removed:
		hide_banner()
		return
	if not _plugin_available or not is_initialized:
		return
	if _banner_view_top == null:
		_load_banner_top()
	else:
		_banner_view_top.show()
	if _banner_view_bottom == null:
		_load_banner_bottom()
	else:
		_banner_view_bottom.show()

func hide_banner() -> void:
	if _banner_view_top:
		_banner_view_top.hide()
	if _banner_view_bottom:
		_banner_view_bottom.hide()

# =================== INTERSTITIAL ===================

func _load_interstitial() -> void:
	if not is_initialized or GameState.ads_removed or _interstitial_ad or _interstitial_loading:
		return
	_interstitial_loading = true

	var loader := InterstitialAdLoader.new()
	_interstitial_cb = InterstitialAdLoadCallback.new()

	_interstitial_cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_loading = false
		_interstitial_ad = ad
		print("[AdManager] Interstitial Ad loaded!")
		_interstitial_content_cb = FullScreenContentCallback.new()
		_interstitial_content_cb.on_ad_dismissed_full_screen_content = func() -> void:
			_interstitial_ad.destroy()
			_interstitial_ad = null
			_load_interstitial()
		_interstitial_content_cb.on_ad_failed_to_show_full_screen_content = func(_err: AdError) -> void:
			_interstitial_ad.destroy()
			_interstitial_ad = null
			_load_interstitial()
		ad.full_screen_content_callback = _interstitial_content_cb

	_interstitial_cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_interstitial_loading = false
		_interstitial_ad = null
		print("[AdManager] Interstitial failed to load: ", error.message)

	loader.load(interstitial_id, AdRequest.new(), _interstitial_cb)

func show_interstitial() -> void:
	if GameState.ads_removed: return
	if not _plugin_available: return
	if _interstitial_ad:
		_interstitial_ad.show()
	else:
		_load_interstitial()

# =================== REWARDED ===================

func _load_rewarded() -> void:
	if not is_initialized or _rewarded_ad or _rewarded_loading: return
	_rewarded_loading = true

	var loader := RewardedAdLoader.new()
	_rewarded_cb = RewardedAdLoadCallback.new()

	_rewarded_cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded_loading = false
		_rewarded_ad = ad
		print("[AdManager] Rewarded Ad loaded!")
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_rewarded_ad = null
			_load_rewarded()
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			_rewarded_ad = null
			_load_rewarded()

	_rewarded_cb.on_ad_failed_to_load = func(_err) -> void:
		_rewarded_loading = false
		_rewarded_ad = null
		print("[AdManager] Rewarded Ad failed to load: ", _err)

	loader.load(rewarded_id, AdRequest.new(), _rewarded_cb)

func _retry_unavailable_ads() -> void:
	if not is_initialized:
		return
	if not GameState.ads_removed:
		_load_banner_top()
		_load_banner_bottom()
		_load_interstitial()
	_load_rewarded()

func show_rewarded_video() -> bool:
	if not _plugin_available:
		rewarded_video_unavailable.emit("Rewarded ads are available on Android builds only.")
		return false

	if _rewarded_ad:
		var user_rewarded: Array[bool] = [false]
		_reward_listener = OnUserEarnedRewardListener.new()
		_reward_listener.on_user_earned_reward = func(_item):
			user_rewarded[0] = true
		_rewarded_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_rewarded_ad.destroy()
			_rewarded_ad = null
			_load_rewarded()
			if user_rewarded[0]:
				rewarded_video_completed.emit()
			else:
				rewarded_video_unavailable.emit("Watch the full ad to unlock the hint.")
		_rewarded_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error):
			_rewarded_ad.destroy()
			_rewarded_ad = null
			_load_rewarded()
			rewarded_video_unavailable.emit("The ad could not open. Please try again.")
		_rewarded_ad.show(_reward_listener)
		return true

	rewarded_video_unavailable.emit("The rewarded ad is still loading. Please try again shortly.")
	if is_initialized:
		_load_rewarded()
	return false

func request_rewarded_hint(on_reward: Callable, on_unavailable: Callable) -> void:
	if _hint_reward.is_valid():
		return
	_hint_reward = on_reward
	_hint_unavailable = on_unavailable
	rewarded_video_completed.connect(_on_hint_rewarded, CONNECT_ONE_SHOT)
	rewarded_video_unavailable.connect(_on_hint_unavailable, CONNECT_ONE_SHOT)
	show_rewarded_video()

func _on_hint_rewarded() -> void:
	if rewarded_video_unavailable.is_connected(_on_hint_unavailable):
		rewarded_video_unavailable.disconnect(_on_hint_unavailable)
	var callback := _hint_reward
	_hint_reward = Callable()
	_hint_unavailable = Callable()
	if callback.is_valid():
		callback.call()

func _on_hint_unavailable(message: String) -> void:
	if rewarded_video_completed.is_connected(_on_hint_rewarded):
		rewarded_video_completed.disconnect(_on_hint_rewarded)
	var callback := _hint_unavailable
	_hint_reward = Callable()
	_hint_unavailable = Callable()
	if callback.is_valid():
		callback.call(message)
# =================== REWARDED INTERSTITIAL ===================

func _load_rewarded_interstitial() -> void:
	if not is_initialized or _rewarded_interstitial_ad:
		return
	var loader := RewardedInterstitialAdLoader.new()
	_rewarded_interstitial_cb = RewardedInterstitialAdLoadCallback.new()
	_rewarded_interstitial_cb.on_ad_loaded = func(ad: RewardedInterstitialAd) -> void:
		_rewarded_interstitial_ad = ad
		_rewarded_interstitial_content_cb = FullScreenContentCallback.new()
		_rewarded_interstitial_content_cb.on_ad_dismissed_full_screen_content = func():
			_destroy_rewarded_interstitial()
		_rewarded_interstitial_content_cb.on_ad_failed_to_show_full_screen_content = func(_error):
			_destroy_rewarded_interstitial()
		ad.full_screen_content_callback = _rewarded_interstitial_content_cb
	_rewarded_interstitial_cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_rewarded_interstitial_ad = null
		push_warning("Rewarded interstitial failed to load: %s" % error.message)
	loader.load(rewarded_interstitial_id, AdRequest.new(), _rewarded_interstitial_cb)

func show_rewarded_interstitial() -> bool:
	if not _plugin_available:
		rewarded_interstitial_unavailable.emit("Rewarded interstitials are available on Android builds only.")
		return false
	if not _rewarded_interstitial_ad:
		rewarded_interstitial_unavailable.emit("The rewarded interstitial is still loading. Please try again shortly.")
		if is_initialized:
			_load_rewarded_interstitial()
		return false
	_rewarded_interstitial_listener = OnUserEarnedRewardListener.new()
	_rewarded_interstitial_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		rewarded_interstitial_completed.emit()
	_rewarded_interstitial_ad.show(_rewarded_interstitial_listener)
	return true

func _destroy_rewarded_interstitial() -> void:
	if _rewarded_interstitial_ad:
		_rewarded_interstitial_ad.destroy()
		_rewarded_interstitial_ad = null
