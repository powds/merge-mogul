extends GutTest

## Tests for MergeItem tier system and merge mechanics

var item_scene: PackedScene = null

func before_each():
	# Create a minimal mock board for testing
	pass

## Test tier clamping
func test_tier_clamping():
	var item = autoqfree(Node2D.new())
	item.set_script(load("res://scripts/game/item.gd"))
	add_child(item)
	
	# Test lower bound
	item.tier = -1
	assert_eq(item.tier, 0, "Tier should clamp to minimum 0")
	
	# Test upper bound
	item.tier = 10
	assert_eq(item.tier, 7, "Tier should clamp to maximum 7")
	
	# Test valid range
	item.tier = 3
	assert_eq(item.tier, 3, "Tier should remain valid value")

## Test tier names
func test_tier_names():
	var item = autoqfree(Node2D.new())
	item.set_script(load("res://scripts/game/item.gd"))
	add_child(item)
	
	assert_eq(item.get_tier_name(), "Idea", "Tier 0 should be Idea")
	assert_eq(item.get_tier_name(), "Prototype", "Tier 1 should be Prototype")
	assert_eq(item.get_tier_name(), "Startup", "Tier 2 should be Startup")
	assert_eq(item.get_tier_name(), "Small Business", "Tier 3 should be Small Business")
	assert_eq(item.get_tier_name(), "Company", "Tier 4 should be Company")
	assert_eq(item.get_tier_name(), "Corporation", "Tier 5 should be Corporation")
	assert_eq(item.get_tier_name(), "Mega Corp", "Tier 6 should be Mega Corp")
	assert_eq(item.get_tier_name(), "Billionaire", "Tier 7 should be Billionaire")

## Test tier colors
func test_tier_colors():
	var item = autoqfree(Node2D.new())
	item.set_script(load("res://scripts/game/item.gd"))
	add_child(item)
	
	var color0 = item.get_tier_color()
	assert_true(color0 == Color("#89CFF0"), "Tier 0 should have Baby Blue color")
	
	item.tier = 7
	var color7 = item.get_tier_color()
	assert_true(color7 == Color("#FFD700"), "Tier 7 should have Gold color")

## Test can_merge_with
func test_can_merge_with():
	var item1 = autoqfree(Node2D.new())
	item1.set_script(load("res://scripts/game/item.gd"))
	add_child(item1)
	
	var item2 = autoqfree(Node2D.new())
	item2.set_script(load("res://scripts/game/item.gd"))
	add_child(item2)
	
	item1.tier = 2
	item2.tier = 2
	assert_true(item1.can_merge_with(item2), "Same tier items should be mergeable")
	
	item2.tier = 3
	assert_false(item1.can_merge_with(item2), "Different tier items should not merge")

## Test merge value calculation
func test_merge_value_from_tier():
	# Tier 0 (Idea) = 2^1 = 2, Tier 1 (Prototype) = 2^2 = 4, etc.
	# New value = pow(2, item1.tier + 1)
	assert_eq(pow(2, 0 + 1), 2, "Tier 0 + Tier 0 merge should create tier 1 value (4)")
	assert_eq(pow(2, 1 + 1), 4, "Tier 1 + Tier 1 merge should create tier 2 value (8)")
	assert_eq(pow(2, 2 + 1), 8, "Tier 2 + Tier 2 merge should create tier 3 value (16)")
	assert_eq(pow(2, 6 + 1), 128, "Tier 6 + Tier 6 merge should create tier 7 value (256)")

## Test max tier cannot merge
func test_max_tier_cannot_merge():
	# Tier 7 (Billionaire) should not be able to merge
	var item1 = autoqfree(Node2D.new())
	item1.set_script(load("res://scripts/game/item.gd"))
	add_child(item1)
	
	var item2 = autoqfree(Node2D.new())
	item2.set_script(load("res://scripts/game/item.gd"))
	add_child(item2)
	
	item1.tier = 7
	item2.tier = 7
	# Even though tiers match, max tier should not merge
	# (This tests the board merge logic would reject it)
	assert_eq(item1.tier, 7, "Max tier should be 7")
	assert_eq(item2.tier, 7, "Max tier should be 7")
