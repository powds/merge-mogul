extends Control

signal banner_toggled(enabled: bool)
signal interstitial_requested
signal rewarded_requested

@onready var banner_panel: Panel = $BannerPanel
@onready var banner_label: Label = $BannerPanel/VBoxContainer/BannerLabel
@onready var banner_toggle: CheckButton = $BannerPanel/VBoxContainer/BannerToggle
@onready var interstitial_btn: Button = $InterstitialPanel/VBoxContainer/InterstitialButton
@onready var rewarded_btn: Button = $RewardedPanel/VBoxContainer/RewardedButton
@onready var status_label: Label = $StatusPanel/StatusLabel

var _banner_visible := false

func _ready() -> void:
	_connect_signals()
	_update_banner_position()

func _connect_signals() -> void:
	banner_toggle.toggled.connect(_on_banner_toggled)
	interstitial_btn.pressed.connect(_on_interstitial_pressed)
	rewarded_btn.pressed.connect(_on_rewarded_pressed)
	AdManager.ad_loaded.connect(_on_ad_loaded)
	AdManager.ad_opened.connect(_on_ad_opened)
	AdManager.ad_closed.connect(_on_ad_closed)
	AdManager.ad_rewarded.connect(_on_ad_rewarded)
	AdManager.ad_failed_to_load.connect(_on_ad_failed_to_load)

func _on_banner_toggled(enabled: bool) -> void:
	_banner_visible = enabled
	if enabled:
		banner_label.text = "[ BANNER AD - TOP ]"
		AdManager.show_ad(AdManager.AdType.BANNER)
	else:
		banner_label.text = "[ BANNER AD - HIDDEN ]"
		AdManager.hide_ad(AdManager.AdType.BANNER)
	_update_banner_position()
	banner_toggled.emit(enabled)

func _on_interstitial_pressed() -> void:
	_set_status("Loading interstitial ad...")
	interstitial_btn.disabled = true
	AdManager.load_interstitial()

func _on_rewarded_pressed() -> void:
	_set_status("Loading rewarded ad...")
	rewarded_btn.disabled = true
	AdManager.load_rewarded()

func _on_ad_loaded(type: int) -> void:
	match type:
		AdManager.AdType.BANNER:
			_set_status("Banner ad loaded")
		AdManager.AdType.INTERSTITIAL:
			_set_status("Interstitial ad ready")
			interstitial_btn.disabled = false
			_show_interstitial_stub()
		AdManager.AdType.REWARDED:
			_set_status("Rewarded ad ready - tap to watch")
			rewarded_btn.disabled = false

func _on_ad_opened(type: int) -> void:
	match type:
		AdManager.AdType.INTERSTITIAL:
			_set_status("Showing interstitial ad...")
		AdManager.AdType.REWARDED:
			_set_status("Playing rewarded ad...")

func _on_ad_closed(type: int) -> void:
	match type:
		AdManager.AdType.INTERSTITIAL:
			_set_status("Interstitial closed")
		AdManager.AdType.REWARDED:
			_set_status("Rewarded ad completed")

func _on_ad_rewarded(type: int, amount: int) -> void:
	if type == AdManager.AdType.REWARDED:
		_set_status("Rewarded: +%d coins!" % amount)
		rewarded_requested.emit()

func _on_ad_failed_to_load(type: int, error_code: int) -> void:
	_set_status("Ad failed to load: error %d" % error_code)
	match type:
		AdManager.AdType.INTERSTITIAL:
			interstitial_btn.disabled = false
		AdManager.AdType.REWARDED:
			rewarded_btn.disabled = false

func _show_interstitial_stub() -> void:
	# Show interstitial placeholder overlay
	var stub = ColorRect.new()
	stub.color = Color(0.1, 0.1, 0.1, 0.95)
	stub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stub)
	
	var label = Label.new()
	label.text = "[ INTERSTITIAL AD PLACEHOLDER ]"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stub.add_child(label)
	
	# Auto-dismiss after short delay (simulating ad view)
	await get_tree().create_timer(2.0).timeout
	stub.queue_free()
	AdManager.show_interstitial()

func _update_banner_position() -> void:
	if _banner_visible:
		banner_panel.offset_top = 0
		banner_panel.offset_bottom = 60
	else:
		banner_panel.offset_top = -60
		banner_panel.offset_bottom = 0

func _set_status(text: String) -> void:
	status_label.text = "Status: %s" % text
