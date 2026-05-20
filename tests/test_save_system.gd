extends Node

## Tests for SaveSystem save/load functionality

const SaveSystem = preload("res://scripts/autoload/save_system.gd")

## Test save_game with valid data
func test_save_game_valid_data():
	var test_data = {
		"score": 1000,
		"grid": [[2, 4, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]],
		"tier": 3
	}
	
	var result = SaveSystem.save_game(test_data)
	assert_true(result, "Save should return true for valid data")

## Test save_game with empty data
func test_save_game_empty_data():
	var result = SaveSystem.save_game({})
	assert_false(result, "Save should return false for empty data")

## Test save_and_load_roundtrip
func test_save_and_load_roundtrip():
	var original_data = {
		"score": 2048,
		"grid": [[2, 4, 8, 16, 32], [2, 4, 8, 16, 32], [2, 4, 8, 16, 32], [2, 4, 8, 16, 32], [2, 4, 8, 16, 32]],
		"tier": 6,
		"name": "test_player"
	}
	
	var save_result = SaveSystem.save_game(original_data)
	assert_true(save_result, "Save should succeed")
	
	var loaded_data = SaveSystem.load_game()
	assert_eq(loaded_data.get("score", -1), 2048, "Score should match")
	assert_eq(loaded_data.get("tier", -1), 6, "Tier should match")
	assert_true(loaded_data.has("grid"), "Grid should be present")

## Test load_game_nonexistent_file():
func test_load_game_nonexistent():
	# First delete any existing save
	SaveSystem.delete_save()
	
	var loaded = SaveSystem.load_game()
	assert_true(loaded.is_empty(), "Should return empty dict for nonexistent file")

## Test delete_save
func test_delete_save():
	# First create a save
	var test_data = {"score": 100}
	SaveSystem.save_game(test_data)
	assert_true(SaveSystem.save_exists(), "Save should exist after save")
	
	var deleted = SaveSystem.delete_save()
	assert_true(deleted, "Delete should return true")
	assert_false(SaveSystem.save_exists(), "Save should not exist after delete")

## Test delete_nonexistent_save
func test_delete_nonexistent():
	SaveSystem.delete_save()  # Ensure clean state
	var result = SaveSystem.delete_save()
	assert_false(result, "Deleting nonexistent save should return false")

## Test save_exists
func test_save_exists():
	SaveSystem.delete_save()  # Clean state
	assert_false(SaveSystem.save_exists(), "No save should exist initially")
	
	SaveSystem.save_game({"score": 50})
	assert_true(SaveSystem.save_exists(), "Save should exist after saving")

## Helper assertion functions
func assert_true(condition: bool, message: String = "") -> bool:
	if not condition:
		print("ASSERTION FAILED: " + message)
		return false
	return true

func assert_false(condition: bool, message: String = "") -> bool:
	if condition:
		print("ASSERTION FAILED: " + message)
		return false
	return true

func assert_eq(actual, expected, message: String = "") -> bool:
	if actual != expected:
		print("ASSERTION FAILED: " + message + " (expected " + str(expected) + ", got " + str(actual) + ")")
		return false
	return true
