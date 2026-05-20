extends Control
## App Launcher for utility tab.
## Queries PackageManager for installed apps, filters by category,
## searches by name, launches apps via Intent, and gets app icons.

enum Category { ALL, GAMES, UTILITIES }

const CATEGORY_ALL: int = Category.ALL
const CATEGORY_GAMES: int = Category.GAMES
const CATEGORY_UTILITIES: int = Category.UTILITIES

## Signals
signal app_selected(app_info: Dictionary)
signal apps_loaded(app_count: int)
signal load_failed(error: String)

## App info dictionary keys
const KEY_PACKAGE_NAME := "package_name"
const KEY_APP_NAME := "app_name"
const KEY_CATEGORY := "category"
const KEY_ICON := "icon"
const KEY_IS_SYSTEM_APP := "is_system_app"

## Internal state
var _installed_apps: Array[Dictionary] = []
var _filtered_apps: Array[Dictionary] = []
var _selected_app_index: int = -1

## UI References (set via scene or manually)
var search_line_edit: LineEdit
var category_option_button: OptionButton
var apps_grid: GridContainer
var launch_button: Button
var count_label: Label

## Platform check
var _is_android: bool = false


func _ready() -> void:
	_setup_ui_references()
	_connect_signals()
	load_apps()


func _setup_ui_references() -> void:
	"""Get UI node references from the scene tree."""
	var panel = $Panel
	if panel:
		var vbox = panel.get_node_or_null("VBoxContainer")
		if vbox:
			search_line_edit = vbox.get_node_or_null("Header/SearchLineEdit")
			category_option_button = vbox.get_node_or_null("Header/CategoryOptionButton")
			var scroll = vbox.get_node_or_null("ScrollContainer")
			apps_grid = scroll.get_node_or_null("AppsGrid") if scroll else null
			
			var footer = vbox.get_node_or_null("Footer")
			if footer:
				launch_button = footer.get_node_or_null("LaunchButton")
				count_label = footer.get_node_or_null("CountLabel")
	
	# Disable launch button initially
	if launch_button:
		launch_button.disabled = true


func _connect_signals() -> void:
	if search_line_edit:
		search_line_edit.text_changed.connect(_on_search_text_changed)
	if category_option_button:
		category_option_button.item_selected.connect(_on_category_selected)
	if launch_button:
		launch_button.pressed.connect(_on_launch_pressed)


## Load installed applications from PackageManager
func load_apps() -> void:
	_installed_apps.clear()
	
	# Check if running on Android
	_is_android = OS.get_name() == "Android"
	
	if not _is_android:
		# Desktop fallback - show message that app list is only available on Android
		push_warning("App list is only available on Android. Showing placeholder.")
		_load_desktop_placeholder()
		return
	
	# Android: Query package manager via JNI singleton
	var context = Engine.get_singleton("GodotAndroidTools")
	if not context:
		push_error("Failed to get Android context singleton")
		load_failed.emit("Failed to get Android context")
		return
	
	var package_manager = context.getPackageManager()
	if not package_manager:
		push_error("Failed to get PackageManager")
		load_failed.emit("Failed to get PackageManager")
		return
	
	# Get list of installed applications
	var apps_array = package_manager.getInstalledApplications()
	
	if not apps_array:
		load_failed.emit("No apps found or error querying PackageManager")
		return
	
	# Process each installed app
	for i in range(apps_array.size()):
		var app_info = apps_array[i]
		var app_dict = _create_app_dict(app_info, package_manager)
		if app_dict:
			_installed_apps.append(app_dict)
	
	# Sort by app name
	_installed_apps.sort_custom(func(a, b): return a[KEY_APP_NAME].to_lower() < b[KEY_APP_NAME].to_lower())
	
	apps_loaded.emit(_installed_apps.size())
	_apply_filters()


## Load desktop placeholder apps (for non-Android platforms)
func _load_desktop_placeholder() -> void:
	# Create placeholder apps for desktop to demonstrate UI functionality
	var placeholder_apps = [
		{KEY_PACKAGE_NAME: "com.example.app1", KEY_APP_NAME: "Example App 1", KEY_CATEGORY: CATEGORY_UTILITIES},
		{KEY_PACKAGE_NAME: "com.example.app2", KEY_APP_NAME: "Example App 2", KEY_CATEGORY: CATEGORY_GAMES},
		{KEY_PACKAGE_NAME: "com.example.app3", KEY_APP_NAME: "Settings", KEY_CATEGORY: CATEGORY_UTILITIES},
	]
	
	for app_data in placeholder_apps:
		var app_dict := {
			KEY_PACKAGE_NAME: app_data[KEY_PACKAGE_NAME],
			KEY_APP_NAME: app_data[KEY_APP_NAME],
			KEY_CATEGORY: app_data[KEY_CATEGORY],
			KEY_ICON: null,
			KEY_IS_SYSTEM_APP: true
		}
		_installed_apps.append(app_dict)
	
	apps_loaded.emit(_installed_apps.size())
	_apply_filters()


## Create an app info dictionary from ApplicationInfo JNI object
func _create_app_dict(app_info, package_manager) -> Dictionary:
	var app_dict := {
		KEY_PACKAGE_NAME: "",
		KEY_APP_NAME: "",
		KEY_CATEGORY: CATEGORY_UTILITIES,
		KEY_ICON: null,
		KEY_IS_SYSTEM_APP: false
	}
	
	# Get package name
	var package_name = app_info.packageName
	if package_name:
		app_dict[KEY_PACKAGE_NAME] = str(package_name)
	
	# Get app name (load from package manager to get the label)
	if package_manager and app_dict[KEY_PACKAGE_NAME]:
		var app_name = package_manager.getApplicationLabel(app_info)
		app_dict[KEY_APP_NAME] = str(app_name) if app_name else app_dict[KEY_PACKAGE_NAME]
	else:
		app_dict[KEY_APP_NAME] = app_dict[KEY_PACKAGE_NAME]
	
	# Check if system app
	app_dict[KEY_IS_SYSTEM_APP] = app_info.isSystemApp if "isSystemApp" in app_info else false
	
	# Determine category based on category flag
	if "category" in app_info:
		var category_flag = app_info.category
		# Category flags from Android ApplicationInfo
		const CATEGORY_GAME = 0x00000001
		const CATEGORY_UTILITIES = 0x00000002
		match category_flag:
			CATEGORY_GAME:
				app_dict[KEY_CATEGORY] = CATEGORY_GAMES
			CATEGORY_UTILITIES:
				app_dict[KEY_CATEGORY] = CATEGORY_UTILITIES
			_:
				app_dict[KEY_CATEGORY] = CATEGORY_UTILITIES
	
	# Load icon
	app_dict[KEY_ICON] = _load_app_icon(app_info, package_manager)
	
	return app_dict


## Load app icon from PackageManager
func _load_app_icon(app_info, package_manager) -> ImageTexture:
	var icon: ImageTexture = null
	
	if package_manager and app_info:
		var drawable = package_manager.getApplicationIcon(app_info)
		if drawable:
			icon = _drawable_to_texture(drawable)
	
	return icon


## Convert Android Drawable to Godot ImageTexture
func _drawable_to_texture(drawable) -> ImageTexture:
	var texture := ImageTexture.new()
	
	if not _is_android:
		return texture
	
	# Get the bitmap from drawable
	var bitmap = drawable.getBitmap()
	if bitmap:
		var width = bitmap.getWidth()
		var height = bitmap.getHeight()
		
		# Create Image from bitmap pixels
		var pixels = bitmap.getPixels()
		if pixels and pixels.size() > 0:
			var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 1, 1, 1))  # Fallback white
			texture.create_from_image(img)
	
	return texture


## Apply search and category filters
func _apply_filters() -> void:
	_filtered_apps.clear()
	
	var search_text := search_line_edit.text.to_lower() if search_line_edit else ""
	var category_idx := category_option_button.selected if category_option_button else CATEGORY_ALL
	
	for app in _installed_apps:
		# Category filter
		if category_idx != CATEGORY_ALL and app[KEY_CATEGORY] != category_idx:
			continue
		
		# Search filter
		if search_text and search_text != "":
			var app_name = app[KEY_APP_NAME].to_lower()
			if not search_text in app_name:
				continue
		
		_filtered_apps.append(app)
	
	_update_grid()
	_update_count_label()


## Update the apps grid with filtered apps
func _update_grid() -> void:
	if not apps_grid:
		return
	
	# Clear existing items (except we don't add items directly to grid in this implementation)
	# The scene has placeholder items - we update their content instead
	# For a dynamic approach, children would need to be managed
	
	# Update placeholder items or notify that count changed
	var item_count = _filtered_apps.size()
	
	# Find all AppItem children in the grid
	var grid_children = apps_grid.get_children()
	var item_index = 0
	
	for child in grid_children:
		if item_index < item_count:
			var app = _filtered_apps[item_index]
			_update_app_item(child, app, item_index)
			child.visible = true
		else:
			child.visible = false
		item_index += 1
	
	# Update selection if out of bounds
	if _selected_app_index >= item_count:
		_selected_app_index = -1
		_update_launch_button_state()


## Update a single app item in the grid
func _update_app_item(item: Node, app: Dictionary, index: int) -> void:
	if not item:
		return
	
	var vbox = item.get_node_or_null("VBox")
	if not vbox:
		return
	
	var icon_rect = vbox.get_node_or_null("AppIcon")
	var name_label = vbox.get_node_or_null("AppName")
	
	if icon_rect and app[KEY_ICON]:
		icon_rect.texture = app[KEY_ICON]
	elif icon_rect:
		# Use a placeholder or empty
		icon_rect.texture = null
	
	if name_label:
		name_label.text = app[KEY_APP_NAME]
	
	# Store app data on the item for selection
	item.set_meta("app_index", index)
	item.set_meta("app_package", app[KEY_PACKAGE_NAME])


## Update the count label
func _update_count_label() -> void:
	if count_label:
		var count = _filtered_apps.size()
		var text = "1 app" if count == 1 else "%d apps" % count
		count_label.text = text


## Update launch button state
func _update_launch_button_state() -> void:
	if launch_button:
		launch_button.disabled = _selected_app_index < 0 or _selected_app_index >= _filtered_apps.size()


## Select an app by index
func select_app(index: int) -> void:
	if index >= 0 and index < _filtered_apps.size():
		_selected_app_index = index
		var app = _filtered_apps[index]
		app_selected.emit(app)
	_update_launch_button_state()


## Get currently selected app
func get_selected_app() -> Dictionary:
	if _selected_app_index >= 0 and _selected_app_index < _filtered_apps.size():
		return _filtered_apps[_selected_app_index]
	return {}


## Launch the selected app via Intent
func launch_selected_app() -> bool:
	if _selected_app_index < 0 or _selected_app_index >= _filtered_apps.size():
		return false
	
	var app = _filtered_apps[_selected_app_index]
	return launch_app_by_package(app[KEY_PACKAGE_NAME])


## Launch an app by package name
func launch_app_by_package(package_name: String) -> bool:
	if not package_name or package_name == "":
		push_error("Empty package name")
		return false
	
	if not _is_android:
		push_error("App launching is only available on Android")
		return false
	
	var context = Engine.get_singleton("GodotAndroidTools")
	if not context:
		push_error("Failed to get Android context singleton")
		return false
	
	var package_manager = context.getPackageManager()
	if not package_manager:
		push_error("Failed to get PackageManager")
		return false
	
	# Get the launch intent for the package
	var launch_intent = package_manager.getLaunchIntentForPackage(package_name)
	
	if not launch_intent:
		push_error("No launch intent found for package: " + package_name)
		return false
	
	# Add flags to the intent
	launch_intent.addFlags(0x10000000)  # Intent.FLAG_ACTIVITY_NEW_TASK
	launch_intent.addFlags(0x04000000)  # Intent.FLAG_ACTIVITY_CLEAR_TOP
	
	# Start the activity
	context.startActivity(launch_intent)
	
	return true


## Get all installed apps
func get_installed_apps() -> Array[Dictionary]:
	return _installed_apps.duplicate()


## Get filtered apps
func get_filtered_apps() -> Array[Dictionary]:
	return _filtered_apps.duplicate()


## Get apps by category
func get_apps_by_category(category: int) -> Array[Dictionary]:
	return _installed_apps.filter(func(app): return app[KEY_CATEGORY] == category)


## Search apps by name
func search_apps(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var lower_query = query.to_lower()
	
	for app in _installed_apps:
		if query.to_lower() in app[KEY_APP_NAME].to_lower():
			results.append(app)
	
	return results


## Signal handlers
func _on_search_text_changed(new_text: String) -> void:
	_apply_filters()


func _on_category_selected(index: int) -> void:
	_apply_filters()


func _on_launch_pressed() -> void:
	launch_selected_app()


func _on_close_pressed() -> void:
	# Emit signal for parent to handle closing
	# close_requested.emit()
	pass


## Handle app item selection (call this from item gui_input)
func _on_app_item_clicked(item_index: int) -> void:
	select_app(item_index)
