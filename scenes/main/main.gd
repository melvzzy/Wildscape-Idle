extends Node3D

const REACH: float = 3.0
const SKILL_TITLES: Dictionary = {&"woodcutting": "Holzfällen", &"mining": "Bergbau"}
const UNLOCK_TITLES: Dictionary = {&"axe": "Steinaxt", &"pickaxe": "Spitzhacke", &"copper_axe": "Kupferaxt", &"kiln": "Meiler"}
var state := GameState.new()
var _target: GatherSpot
var _active: GatherSpot
var _gather_started_ms: int = 0
var _duration_ms: int = 0
var _recipe_buttons: Dictionary[StringName, Button] = {}
var _last_near_bench: bool = false
var _last_near_kiln: bool = false
var _last_tick_ms: int = 0

@onready var player: CharacterBody3D = $Player
@onready var bench: Node3D = $TestWorld/Workbench
@onready var kiln: Node3D = $TestWorld/Kiln
@onready var ui: Control = $HUD/Layout
@onready var content: VBoxContainer = $HUD/Layout/Panel/Margin/Scroll/Content

func _ready() -> void:
	get_tree().auto_accept_quit = false
	state.changed.connect(_refresh)
	for entry: RecipeDefinition in GameState.RECIPES:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_craft.bind(entry.id))
		content.get_node("Recipes").add_child(button)
		_recipe_buttons[entry.id] = button
	content.get_node("Save").pressed.connect(_save)
	content.get_node("Load").pressed.connect(_load)
	content.get_node("Close").pressed.connect(_toggle_panel)
	content.get_node("Production").pressed.connect(_toggle_production)
	var result := SaveGame.load_state(state)
	if result == ERR_FILE_NOT_FOUND:
		_notice("Sammle Holz und Stein. Stelle an der Werkbank eine Spitzhacke her.")
	elif result != OK:
		_notice("Spielstand nicht lesbar. Neue Sitzung; vorhandene Datei bleibt bis zum Speichern erhalten.")
	else:
		_notice("Spielstand geladen.")
	_refresh()
	_last_tick_ms = Time.get_ticks_msec()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		_toggle_panel()
	if event.is_action_pressed("save_game"):
		_save()
	if event.is_action_pressed("load_game"):
		_load()
	if event.is_action_pressed("interact") and _active == null:
		if _near_bench():
			if not ui.get_node("Panel").visible:
				_toggle_panel()
		elif _near_kiln():
			_toggle_production()
		elif _target != null and not ui.get_node("Panel").visible:
			_start_gather(_target)

func _physics_process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	state.advance_production(float(now - _last_tick_ms) / 1000.0)
	_last_tick_ms = now
	var near_bench := _near_bench()
	var near_kiln := _near_kiln()
	if near_bench != _last_near_bench or near_kiln != _last_near_kiln:
		_last_near_bench = near_bench
		_last_near_kiln = near_kiln
		_refresh()
	_target = _nearest_spot()
	if _active != null:
		if not _can_reach(_active) or ui.get_node("Panel").visible:
			_cancel_gather()
			_notice("Sammeln abgebrochen.")
		else:
			var elapsed := Time.get_ticks_msec() - _gather_started_ms
			ui.get_node("Progress").value = minf(1.0, float(elapsed) / _duration_ms)
			if elapsed >= _duration_ms:
				var completed := _active
				_active = null
				if completed.finish(state):
					_notice("+%d %s · +%d XP" % [state.gather_yield(completed.definition), _item_title(completed.definition.item), completed.definition.xp])
				else:
					_notice("Sammeln nicht möglich (Inventar voll oder Werkzeug fehlt).")
	ui.get_node("Progress").visible = _active != null
	var prompt := "Erkunde das Lager. Markierte Bäume und Felsen liefern Rohstoffe."
	if _active != null:
		prompt = "%s wird gesammelt … Bleibe in der Nähe." % _active.definition.title
	elif near_bench:
		prompt = "E · Werkbank öffnen"
	elif near_kiln:
		prompt = "E · Meiler ein-/ausschalten" if state.has_unlock(&"kiln") else "Meiler · an der Werkbank freischalten (Spitzhacke + Kupfer)"
	elif _target != null:
		if not _target.available():
			prompt = "%s · wächst bald nach" % _target.definition.title
		elif not state.has_unlock(_target.definition.required_tool):
			prompt = "%s · benötigt Spitzhacke (Werkbank)" % _target.definition.title
		else:
			prompt = "E · %s sammeln" % _target.definition.title
	ui.get_node("Prompt").text = prompt
	ui.get_node("Prompt").visible = not ui.get_node("Panel").visible
	if near_kiln and state.production_enabled():
		ui.get_node("Prompt").text += " · läuft / wartet auf Holz · %d %%" % int(state.production_progress() * 100)
	$TestWorld/Kiln/Label.text = "KOHLEMEILER\n" + ("AKTIV · E" if state.production_enabled() else "INAKTIV · E")

func _near_kiln() -> bool:
	return player.global_position.distance_to(kiln.global_position) <= REACH

func _toggle_production() -> void:
	if not _near_kiln():
		_notice("Zum Bedienen näher an den Meiler gehen.")
	elif not state.toggle_production():
		_notice("Meiler zuerst an der Werkbank freischalten.")
	else:
		_notice("Meiler aktiv: 2 Holz → 1 Holzkohle alle 5 s." if state.production_enabled() else "Meiler angehalten.")

func _near_bench() -> bool:
	return player.global_position.distance_to(bench.global_position) <= REACH

func _can_reach(spot: GatherSpot) -> bool:
	if player.global_position.distance_to(spot.global_position) > REACH:
		return false
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, spot.global_position + Vector3.UP)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == spot

func _nearest_spot() -> GatherSpot:
	var nearest: GatherSpot
	var distance := REACH
	for node: Node in get_tree().get_nodes_in_group("gather_spots"):
		var spot := node as GatherSpot
		var candidate := player.global_position.distance_to(spot.global_position)
		if candidate < distance and _can_reach(spot):
			distance = candidate
			nearest = spot
	return nearest

func _start_gather(spot: GatherSpot) -> void:
	if _active != null:
		return
	if not _can_reach(spot) or not state.has_unlock(spot.definition.required_tool):
		_notice("Benötigtes Werkzeug fehlt oder Ressource ist zu weit entfernt.")
		return
	if not spot.begin():
		return
	_active = spot
	_gather_started_ms = Time.get_ticks_msec()
	_duration_ms = maxi(1, int(state.gather_duration(spot.definition) * 1000))

func _cancel_gather() -> void:
	if _active != null:
		_active.cancel()
		_active = null

func _craft(id: StringName) -> void:
	if not _near_bench():
		_notice("Zum Herstellen näher an die Werkbank gehen.")
		return
	if state.craft(id):
		_notice("Hergestellt: " + state.recipe(id).title)
	else:
		_notice("Materialien fehlen, Voraussetzung fehlt oder bereits hergestellt.")

func _toggle_panel() -> void:
	var panel: Control = ui.get_node("Panel")
	panel.visible = not panel.visible
	player.controls_enabled = not panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED
	if panel.visible:
		_cancel_gather()
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	var inventory_text := "INVENTAR"
	for item: ItemDefinition in GameState.ITEMS:
		inventory_text += "\n%s: %d" % [item.title, state.amount(item.id)]
	content.get_node("Inventory").text = inventory_text
	var skill_text := "SKILLS · jedes Level beschleunigt das Sammeln"
	for id: StringName in GameState.SKILLS:
		skill_text += "\n%s: Level %d · %d / 50 XP" % [SKILL_TITLES[id], state.level(id), state.skill_xp(id) % 50]
	content.get_node("Skills").text = skill_text
	var tools := "WERKZEUGE"
	for entry: RecipeDefinition in GameState.RECIPES:
		var costs := ""
		for item: StringName in entry.costs:
			costs += "%d %s  " % [entry.costs[item], _item_title(item)]
		var button: Button = _recipe_buttons[entry.id]
		button.text = entry.title + "\n" + costs
		button.disabled = not _near_bench() or not state.can_craft(entry.id)
		if state.has_unlock(entry.unlock):
			tools += " · " + UNLOCK_TITLES[entry.unlock]
	content.get_node("Tools").text = tools
	var production: Button = content.get_node("Production")
	production.disabled = not _near_kiln() or not state.has_unlock(&"kiln")
	production.text = "Meiler anhalten" if state.production_enabled() else "Meiler starten (am Meiler)"

func _item_title(id: StringName) -> String:
	for item: ItemDefinition in GameState.ITEMS:
		if item.id == id:
			return item.title
	return String(id)

func _notice(text: String) -> void:
	ui.get_node("Notice").text = text

func _save() -> void:
	var result := SaveGame.save_state(state)
	_notice("Spiel gespeichert." if result == OK else "Speichern fehlgeschlagen: " + error_string(result))

func _load() -> void:
	_cancel_gather()
	var result := SaveGame.load_state(state)
	_last_tick_ms = Time.get_ticks_msec()
	_notice("Spielstand geladen." if result == OK else "Laden fehlgeschlagen; Sitzung unverändert: " + error_string(result))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var result := SaveGame.save_state(state)
		if result == OK:
			get_tree().quit()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_notice("Speichern fehlgeschlagen. Fenster bleibt offen: " + error_string(result))
