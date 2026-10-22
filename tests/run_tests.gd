extends SceneTree

var checks: int = 0
var failures: int = 0
const SAVE_PATH: String = "user://wildscape_test_save.json"

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	_test_definitions()
	_test_inventory()
	_test_crafting_and_skills()
	_test_production()
	_test_save()
	await _test_world()
	print("Wildscape: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_definitions() -> void:
	var state := GameState.new()
	var ids: Array[StringName] = []
	for item: ItemDefinition in GameState.ITEMS:
		_check(item.id != &"" and not ids.has(item.id) and not item.title.is_empty(), "Valid unique item ID")
		ids.append(item.id)
	ids.clear()
	for recipe: RecipeDefinition in GameState.RECIPES:
		_check(recipe.id != &"" and not ids.has(recipe.id) and recipe.unlock == recipe.id, "Valid unique recipe ID")
		ids.append(recipe.id)
		_check(recipe.required_unlock == &"" or state.recipe(recipe.required_unlock) != null, "Known recipe prerequisite")
		for id: StringName in recipe.costs:
			_check(state.known_item(id) and recipe.costs[id] > 0, "Valid recipe ingredient")
	for definition: GatherDefinition in GameState.GATHERING:
		_check(state.known_item(definition.item) and GameState.SKILLS.has(definition.skill) and definition.duration > 0 and definition.respawn_seconds > 0, "Valid gathering definition")
	var production := GameState.PRODUCTION
	_check(state.known_item(production.input_item) and state.known_item(production.output_item) and production.input_amount > 0 and production.seconds_per_batch > 0, "Valid production definition")

func _test_inventory() -> void:
	var state := GameState.new()
	_check(state.amount(&"wood") == 0, "Empty inventory")
	_check(not state.add(&"unknown", 1), "Unknown item rejected")
	_check(not state.add(&"wood", -1) and not state.add(&"wood", 0), "Nonpositive additions rejected")
	_check(state.add(&"wood", 5) and state.amount(&"wood") == 5, "Add inventory")
	_check(not state.remove(&"wood", 6) and state.amount(&"wood") == 5, "Overdraft rejected")
	_check(not state.remove(&"wood", -1), "Negative removal rejected")
	_check(state.remove(&"wood", 5) and state.amount(&"wood") == 0, "Remove exact inventory")
	_check(state.add(&"wood", GameState.MAX_AMOUNT), "Inventory capacity accepted")
	_check(not state.add(&"wood", 1), "Overflow rejected")

func _test_crafting_and_skills() -> void:
	var state := GameState.new()
	state.add(&"wood", 10)
	var before := state.snapshot()
	_check(not state.craft(&"axe") and state.snapshot() == before, "Failed crafting is atomic")
	_check(not state.craft(&"unknown"), "Unknown recipe rejected")
	state.add(&"stone", 10)
	_check(state.craft(&"axe"), "Craft axe")
	_check(state.amount(&"wood") == 7 and state.amount(&"stone") == 8 and state.has_unlock(&"axe"), "Correct craft costs and unlock")
	before = state.snapshot()
	_check(not state.craft(&"axe") and state.snapshot() == before, "Duplicate crafting consumes nothing")
	var ore: GatherDefinition = GameState.GATHERING[2]
	_check(not state.gather(ore) and state.skill_xp(&"mining") == 0, "Ore requires tool")
	_check(state.craft(&"pickaxe") and state.gather(ore), "Pickaxe unlocks ore")
	_check(state.amount(&"ore") == 1 and state.skill_xp(&"mining") == 15, "Gather adds item and XP")
	var tree: GatherDefinition = GameState.GATHERING[0]
	var duration := state.gather_duration(tree)
	for index: int in range(5):
		_check(state.gather(tree), "Gather wood with axe")
	_check(state.amount(&"wood") == 13 and state.level(&"woodcutting") == 2, "Axe yield and skill level")
	_check(state.gather_duration(tree) < duration, "Skill accelerates gathering")
	state.add(&"ore", 3)
	state.add(&"charcoal", 2)
	_check(state.craft(&"copper_axe") and state.gather_yield(tree) == 3, "Copper has use in upgrade")
	var full := GameState.new()
	full.add(&"wood", GameState.MAX_AMOUNT)
	_check(not full.gather(tree) and full.skill_xp(&"woodcutting") == 0, "Full inventory gives no items or XP")
	var prerequisites := GameState.new()
	prerequisites.add(&"ore", 4)
	prerequisites.add(&"wood", 3)
	prerequisites.add(&"charcoal", 2)
	_check(not prerequisites.craft(&"copper_axe"), "Upgrade requires previous axe")

func _production_state() -> GameState:
	var state := GameState.new()
	state.add(&"wood", 20)
	state.add(&"stone", 8)
	state.add(&"ore", 2)
	state.craft(&"pickaxe")
	state.craft(&"kiln")
	return state

func _test_production() -> void:
	var locked := GameState.new()
	_check(not locked.toggle_production() and locked.advance_production(60) == 0, "Station requires unlock")
	var state := _production_state()
	_check(state.has_unlock(&"kiln") and state.amount(&"wood") == 11, "Station has recipe costs")
	_check(state.advance_production(60) == 0, "Disabled station does not produce")
	_check(state.toggle_production(), "Enable station")
	_check(state.advance_production(4) == 0 and is_equal_approx(state.production_progress(), 0.8), "Partial production interval")
	_check(state.advance_production(1) == 1 and state.amount(&"wood") == 9 and state.amount(&"charcoal") == 1, "Production atomically exchanges materials")
	_check(state.advance_production(999999) == 4 and state.amount(&"wood") == 1, "Large elapsed time limited by input")
	_check(state.advance_production(999999) == 0 and state.amount(&"charcoal") == 5, "No infinite production")
	state.add(&"wood", 1)
	_check(state.advance_production(4) == 0, "Blocked station banks no idle time")
	_check(state.advance_production(1) == 1 and state.amount(&"wood") == 0, "Production resumes with fresh interval")
	var whole := _production_state()
	var parts := _production_state()
	whole.toggle_production()
	parts.toggle_production()
	whole.advance_production(12.5)
	for index: int in range(50):
		parts.advance_production(0.25)
	_check(whole.snapshot() == parts.snapshot(), "Production independent of tick partition")
	var decimal := _production_state()
	decimal.toggle_production()
	for index: int in range(50):
		decimal.advance_production(0.1)
	_check(decimal.amount(&"charcoal") == 1 and is_zero_approx(decimal.production_progress()), "Decimal ticks complete exact interval")
	var before := parts.snapshot()
	_check(parts.advance_production(-5) == 0 and parts.advance_production(INF) == 0 and parts.snapshot() == before, "Invalid time rejected")
	parts.toggle_production()
	before = parts.snapshot()
	_check(parts.advance_production(60) == 0 and parts.snapshot() == before, "Pause preserves partial progress")
	var full := _production_state()
	full.add(&"charcoal", GameState.MAX_AMOUNT)
	full.toggle_production()
	var wood_before := full.amount(&"wood")
	_check(full.advance_production(60) == 0 and full.amount(&"wood") == wood_before, "Full output consumes no input")
	var invalid := parts.snapshot()
	invalid.production_progress = 5.0
	_check(not parts.restore(invalid), "Out-of-range saved progress rejected")

func _test_save() -> void:
	var state := GameState.new()
	state.add(&"wood", 20)
	state.add(&"stone", 20)
	state.craft(&"axe")
	state.gather(GameState.GATHERING[0])
	state.craft(&"pickaxe")
	state.add(&"ore", 2)
	state.craft(&"kiln")
	state.toggle_production()
	state.advance_production(2.5)
	_check(SaveGame.save_state(state, SAVE_PATH) == OK, "Save with temporary file")
	var restored := GameState.new()
	_check(SaveGame.load_state(restored, SAVE_PATH) == OK and restored.snapshot() == state.snapshot(), "JSON roundtrip includes items/tools/skills")
	_check(restored.production_enabled() and is_equal_approx(restored.production_progress(), 0.5), "Production progress survives load")
	state.add(&"wood", 1)
	_check(SaveGame.save_state(state, SAVE_PATH) == OK, "Replace existing save")
	_check(SaveGame.load_state(restored, SAVE_PATH) == OK and restored.snapshot() == state.snapshot(), "Replacement persisted")
	var valid := restored.snapshot()
	for invalid: Variant in [-1, 0.5, "5", true, 1000001]:
		var bad: Dictionary = JSON.parse_string(JSON.stringify(valid))
		bad.inventory[&"wood"] = invalid
		_check(not restored.restore(bad) and restored.snapshot() == valid, "Invalid inventory leaves state intact")
	var invalid_unlock := valid.duplicate(true)
	invalid_unlock.unlocks = {"copper_axe": true}
	_check(not restored.restore(invalid_unlock), "Invalid unlock dependency")
	var bad_skill := valid.duplicate(true)
	bad_skill.xp = {"unknown": 10}
	_check(not restored.restore(bad_skill), "Unknown skill rejected")
	for text: String in ["{", "[]", '{"version":999,"state":{}}', '{"version":1,"state":{"inventory":{"wood":-1},"unlocks":{},"xp":{}}}']:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		_check(SaveGame.load_state(restored, SAVE_PATH) == ERR_FILE_CORRUPT and restored.snapshot() == valid, "Malformed file leaves live state intact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_check(SaveGame.load_state(restored, SAVE_PATH) == ERR_FILE_NOT_FOUND, "Missing save handled")
	_check(SaveGame.save_state(state, "user://nonexistent_directory/save.json") != OK, "Write error reported")

func _test_world() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	# Runtime UI/movement integration uses an isolated fresh state, never writes the real save.
	main.state.restore({"inventory": {}, "unlocks": {}, "xp": {}})
	await physics_frame
	await physics_frame
	_check(get_nodes_in_group("gather_spots").size() == 9, "World gathering spots loaded")
	_check(main.get_node("Player/CameraPivot/SpringArm3D/Camera3D").current, "Player camera active")
	_check(InputMap.action_get_events("save_game")[0].physical_keycode == KEY_F6 and InputMap.action_get_events("load_game")[0].physical_keycode == KEY_F9, "Save/load input map matches HUD")
	var player: CharacterBody3D = main.get_node("Player")
	for frame: int in range(60):
		await physics_frame
	_check(player.is_on_floor() and absf(player.position.y) < 0.1, "Player rests on ground")
	Input.action_press("move_right")
	var start := player.position
	for frame: int in range(20):
		await physics_frame
	Input.action_release("move_right")
	_check(player.position.x > start.x + 1.0, "WASD moves character")
	var arm: SpringArm3D = player.get_node("CameraPivot/SpringArm3D")
	var zoom := InputEventAction.new()
	zoom.action = "zoom_in"
	zoom.pressed = true
	var previous_length := arm.spring_length
	player._unhandled_input(zoom)
	_check(arm.spring_length < previous_length, "Camera zoom action works")
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation.y = PI / 2
	player.position = Vector3(8, 0, 6)
	start = player.position
	Input.action_press("move_forward")
	for frame: int in range(20):
		await physics_frame
	Input.action_release("move_forward")
	_check(player.position.x < start.x - 1.0, "Movement relative to camera yaw")
	pivot.rotation.y = 0
	arm.spring_length = previous_length
	var spot: GatherSpot = main.get_node("TestWorld/Tree1")
	player.position = spot.position + Vector3(1.5, 0, 0)
	await physics_frame
	main._start_gather(spot)
	_check(main._active == spot, "Reachable resource starts gathering")
	main._start_gather(main.get_node("TestWorld/Tree2"))
	_check(main._active == spot, "Second action cannot replace active harvest")
	_check(not spot.begin(), "Concurrent gathering rejected")
	player.position = Vector3(0, 0, 10)
	await physics_frame
	await physics_frame
	_check(main._active == null and main.state.amount(&"wood") == 0, "Leaving range cancels without yield")
	player.position = spot.position + Vector3(1.5, 0, 0)
	await physics_frame
	main._start_gather(spot)
	await create_timer(1.7).timeout
	_check(main.state.amount(&"wood") == 1 and not spot.available(), "Gather completes once and depletes node")
	_check(not spot.finish(main.state) and not spot.begin(), "No double completion or early harvest")
	spot._available_at_ms = Time.get_ticks_msec() + 30
	await create_timer(0.06).timeout
	_check(spot.available() and spot.begin(), "Resource respawns")
	spot.cancel()
	main.state.add(&"wood", 10)
	main.state.add(&"stone", 10)
	player.position = Vector3(0, 0, 10)
	main._craft(&"axe")
	_check(not main.state.has_unlock(&"axe"), "Crafting requires bench proximity")
	player.position = Vector3(0, 0, 2)
	await physics_frame
	main._recipe_buttons[&"axe"].pressed.emit()
	_check(main.state.has_unlock(&"axe"), "Crafting at bench works")
	main.state.add(&"stone", 10)
	main.state.add(&"wood", 20)
	main._craft(&"pickaxe")
	main.state.add(&"ore", 2)
	main._craft(&"kiln")
	main._toggle_production()
	_check(not main.state.production_enabled(), "Station interaction requires proximity")
	player.position = Vector3(3, 0, 8)
	main._toggle_production()
	_check(main.state.production_enabled(), "Station UI uses shared production state")
	main._toggle_production()
	player.position = Vector3(0, 0, 3)
	await physics_frame
	await physics_frame
	main._toggle_panel()
	_check(main.get_node("HUD/Layout/Panel").visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Panel opens with mouse access")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://wildscape_ui_preview.png")
	main._toggle_panel()
	_check(player.controls_enabled, "Panel close restores controls")
	player.position = Vector3(0, -20, 4)
	await physics_frame
	await physics_frame
	_check(player.position.y >= 0, "Falling out of world resets player")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://wildscape_world_preview.png")
	main.queue_free()
	await process_frame
