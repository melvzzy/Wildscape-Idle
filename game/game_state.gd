class_name GameState
extends RefCounted

signal changed

const ITEMS = [preload("res://data/items/wood.tres"), preload("res://data/items/stone.tres"), preload("res://data/items/ore.tres"), preload("res://data/items/charcoal.tres")]
const RECIPES = [preload("res://data/recipes/axe.tres"), preload("res://data/recipes/pickaxe.tres"), preload("res://data/recipes/kiln.tres"), preload("res://data/recipes/copper_axe.tres")]
const PRODUCTION: ProductionDefinition = preload("res://data/production/kiln.tres")
const GATHERING = [preload("res://data/gathering/tree.tres"), preload("res://data/gathering/stone.tres"), preload("res://data/gathering/ore.tres")]
const MAX_AMOUNT: int = 1000000
const SKILLS: Array[StringName] = [&"woodcutting", &"mining"]

var _inventory: Dictionary[StringName, int] = {}
var _unlocks: Dictionary[StringName, bool] = {}
var _xp: Dictionary[StringName, int] = {}
var _production_enabled: bool = false
var _production_progress: float = 0.0

func amount(id: StringName) -> int:
	return _inventory.get(id, 0)

func has_unlock(id: StringName) -> bool:
	return id == &"" or _unlocks.get(id, false)

func skill_xp(id: StringName) -> int:
	return _xp.get(id, 0)

func level(id: StringName) -> int:
	@warning_ignore("integer_division")
	return 1 + skill_xp(id) / 50

func known_item(id: StringName) -> bool:
	for item: ItemDefinition in ITEMS:
		if item.id == id:
			return true
	return false

func add(id: StringName, count: int) -> bool:
	if not known_item(id) or count <= 0 or count > MAX_AMOUNT - amount(id):
		return false
	_inventory[id] = amount(id) + count
	changed.emit()
	return true

func remove(id: StringName, count: int) -> bool:
	if not known_item(id) or count <= 0 or amount(id) < count:
		return false
	_inventory[id] = amount(id) - count
	changed.emit()
	return true

func recipe(id: StringName) -> RecipeDefinition:
	for entry: RecipeDefinition in RECIPES:
		if entry.id == id:
			return entry
	return null

func can_craft(id: StringName) -> bool:
	var entry := recipe(id)
	if entry == null or has_unlock(entry.unlock) or not has_unlock(entry.required_unlock):
		return false
	for item: StringName in entry.costs:
		if amount(item) < entry.costs[item]:
			return false
	return true

func craft(id: StringName) -> bool:
	if not can_craft(id):
		return false
	var entry := recipe(id)
	# Commit the entire transaction before notifying observers.
	for item: StringName in entry.costs:
		_inventory[item] = amount(item) - entry.costs[item]
	_unlocks[entry.unlock] = true
	changed.emit()
	return true

func gather_yield(definition: GatherDefinition) -> int:
	if definition.item == &"wood":
		if has_unlock(&"copper_axe"):
			return 3
		if has_unlock(&"axe"):
			return 2
	return 1

func gather_duration(definition: GatherDefinition) -> float:
	return definition.duration / (1.0 + mini(level(definition.skill) - 1, 10) * 0.05)

func gather(definition: GatherDefinition) -> bool:
	if not GATHERING.has(definition) or not has_unlock(definition.required_tool):
		return false
	var count := gather_yield(definition)
	if amount(definition.item) > MAX_AMOUNT - count:
		return false
	_inventory[definition.item] = amount(definition.item) + count
	_xp[definition.skill] = mini(MAX_AMOUNT, skill_xp(definition.skill) + definition.xp)
	changed.emit()
	return true

func snapshot() -> Dictionary:
	return {"inventory": _inventory.duplicate(), "unlocks": _unlocks.duplicate(), "xp": _xp.duplicate(), "production_enabled": _production_enabled, "production_progress": _production_progress}

func production_enabled() -> bool:
	return _production_enabled

func production_progress() -> float:
	return _production_progress / PRODUCTION.seconds_per_batch

func toggle_production() -> bool:
	if not has_unlock(PRODUCTION.required_unlock):
		return false
	_production_enabled = not _production_enabled
	changed.emit()
	return true

func advance_production(seconds: float) -> int:
	if not is_finite(seconds) or seconds <= 0 or not _production_enabled or not has_unlock(PRODUCTION.required_unlock):
		return 0
	@warning_ignore("integer_division")
	var available_batches := mini(amount(PRODUCTION.input_item) / PRODUCTION.input_amount, MAX_AMOUNT - amount(PRODUCTION.output_item))
	if available_batches <= 0:
		_production_progress = 0.0
		return 0
	# Cap elapsed time to material capacity before converting it to integer batches.
	var elapsed := minf(_production_progress + seconds, available_batches * PRODUCTION.seconds_per_batch)
	# Tolerate floating-point roundoff at exact batch boundaries.
	var batches := mini(int(floor(elapsed / PRODUCTION.seconds_per_batch + 0.000000001)), available_batches)
	_production_progress = maxf(0.0, elapsed - batches * PRODUCTION.seconds_per_batch)
	if batches > 0:
		_inventory[PRODUCTION.input_item] = amount(PRODUCTION.input_item) - batches * PRODUCTION.input_amount
		_inventory[PRODUCTION.output_item] = amount(PRODUCTION.output_item) + batches
		changed.emit()
	return batches

func restore(data: Dictionary) -> bool:
	# Validate into temporary dictionaries; a failed load leaves the live game intact.
	var inventory: Dictionary[StringName, int] = {}
	var unlocks: Dictionary[StringName, bool] = {}
	var xp: Dictionary[StringName, int] = {}
	for field: String in ["inventory", "unlocks", "xp"]:
		if not data.get(field) is Dictionary:
			return false
	for key: Variant in data.inventory:
		if not key is String and not key is StringName:
			return false
		var id := StringName(key)
		if not known_item(id) or not _valid_count(data.inventory[key]):
			return false
		inventory[id] = int(data.inventory[key])
	for key: Variant in data.xp:
		if not key is String and not key is StringName:
			return false
		var id := StringName(key)
		if not SKILLS.has(id) or not _valid_count(data.xp[key]):
			return false
		xp[id] = int(data.xp[key])
	for key: Variant in data.unlocks:
		if not key is String and not key is StringName:
			return false
		var id := StringName(key)
		if recipe(id) == null or not data.unlocks[key] is bool:
			return false
		unlocks[id] = data.unlocks[key]
	if unlocks.get(&"copper_axe", false) and not unlocks.get(&"axe", false):
		return false
	if unlocks.get(&"kiln", false) and not unlocks.get(&"pickaxe", false):
		return false
	var enabled: Variant = data.get("production_enabled", false)
	var progress: Variant = data.get("production_progress", 0.0)
	if not enabled is bool or (not progress is int and not progress is float):
		return false
	if not is_finite(float(progress)) or float(progress) < 0 or float(progress) >= PRODUCTION.seconds_per_batch:
		return false
	if (enabled or float(progress) > 0) and not unlocks.get(PRODUCTION.required_unlock, false):
		return false
	_inventory = inventory
	_unlocks = unlocks
	_xp = xp
	_production_enabled = enabled
	_production_progress = float(progress)
	changed.emit()
	return true

func _valid_count(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	return is_finite(float(value)) and float(value) >= 0 and float(value) <= MAX_AMOUNT and float(value) == floorf(float(value))
