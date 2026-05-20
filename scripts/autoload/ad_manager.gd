extends Node

signal ad_loaded(type: int)
signal ad_failed_to_load(type: int, error_code: int)
signal ad_opened(type: int)
signal ad_closed(type: int)
signal ad_rewarded(type: int, amount: int)

const AdType := {
	BANNER: 0,
	INTERSTITIAL: 1,
	REWARDED: 2,
}

var _is_initialized := false

func _init() -> void:
	print("AdManager: Initializing stubs")

func initialize(app_id: String) -> void:
	print("AdManager: Initializing with app_id: ", app_id)
	_is_initialized = true
	emit_signal("ad_loaded", AdType.BANNER)

func load_ad(type: int) -> void:
	print("AdManager: Loading ad type: ", type)
	await get_tree().create_timer(1.0).timeout
	emit_signal("ad_loaded", type)

func show_ad(type: int) -> bool:
	if not _is_initialized:
		return false
	print("AdManager: Showing ad type: ", type)
	emit_signal("ad_opened", type)
	return true

func hide_ad(type: int) -> void:
	print("AdManager: Hiding ad type: ", type)

func is_loaded(type: int) -> bool:
	return _is_initialized

func set_banner_position(x: int, y: int) -> void:
	print("AdManager: Setting banner position to ", x, ", ", y)

func load_rewarded_ad() -> void:
	print("AdManager: Loading rewarded ad")
	await get_tree().create_timer(1.0).timeout
	emit_signal("ad_loaded", AdType.REWARDED)

func show_rewarded_ad() -> bool:
	if not _is_initialized:
		return false
	print("AdManager: Showing rewarded ad")
	emit_signal("ad_opened", AdType.REWARDED)
	await get_tree().create_timer(0.5).timeout
	emit_signal("ad_rewarded", AdType.REWARDED, 1)
	emit_signal("ad_closed", AdType.REWARDED)
	return true