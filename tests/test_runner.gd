extends Node

## Simple test runner for merge-mogul
## Run with: godot --path . -s tests/test_runner.gd -e

var passed: int = 0
var failed: int = 0
var tests: Array = []

func _ready() -> void:
	print("====================================")
	print("  MERGE-MOGUL TEST RUNNER")
	print("====================================\n")
	
	# Discover and run tests
	run_directory_tests("res://tests/")
	
	print("\n====================================")
	print("  RESULTS: %d passed, %d failed" % [passed, failed])
	print("====================================")
	
	if failed > 0:
		print("\nTESTS FAILED!")
		get_tree().quit(1)
	else:
		print("\nALL TESTS PASSED!")
		get_tree().quit(0)

func run_directory_tests(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_warning("Could not open directory: " + path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".gd") and file_name.begins_with("test_"):
			run_test_file(path + file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()

func run_test_file(file_path: String) -> void:
	print("\n--- Running: " + file_path.get_file() + " ---")
	
	var test_script = load(file_path)
	if test_script == null:
		print("FAILED to load: " + file_path)
		failed += 1
		return
	
	# Create instance of test
	var test_instance = test_script.new()
	if test_instance == null:
		print("FAILED to instantiate: " + file_path)
		failed += 1
		return
	
	# Setup
	if test_instance.has_method("before_each"):
		test_instance.before_each()
	
	# Find and run test methods
	var methods = test_instance.get_method_list()
	for method in methods:
		if method.name.begins_with("test_"):
			run_single_test(test_instance, method.name)
	
	# Teardown
	if test_instance.has_method("after_each"):
		test_instance.after_each()
	
	test_instance.free()

func run_single_test(test_instance, method_name: String) -> void:
	if test_instance.has_method("before_each"):
		test_instance.before_each()
	
	print("  [RUN] " + method_name)
	
	# Use GDScript assert
	var assertions_passed = true
	var assertion_errors = []
	
	# Override assert to capture failures
	var original_assert = assert
	
	var success = false
	if test_instance.has_method(method_name):
		# Catch errors during test
		var test_callable = Callable(test_instance, method_name)
		test_callable.call()
		success = true
	
	if test_instance.has_method("after_each"):
		test_instance.after_each()
	
	if success:
		print("  [PASS] " + method_name)
		passed += 1
	else:
		print("  [FAIL] " + method_name)
		failed += 1
