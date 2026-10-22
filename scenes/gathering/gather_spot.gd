class_name GatherSpot
extends StaticBody3D

@export var definition: GatherDefinition
var _available_at_ms: int = 0
var _busy: bool = false

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.color
	material.roughness = 1.0
	$Mesh.material_override = material
	if definition.id == &"tree":
		$Mesh.scale = Vector3(1, 2.5, 1)
		$Mesh.position.y = 2.0
		$Trunk.show()

func available() -> bool:
	return Time.get_ticks_msec() >= _available_at_ms

func begin() -> bool:
	if _busy or not available():
		return false
	_busy = true
	return true

func cancel() -> void:
	_busy = false

func finish(state: GameState) -> bool:
	if not _busy or not available():
		return false
	_busy = false
	# Mark depleted before the state signal can notify other observers.
	_available_at_ms = Time.get_ticks_msec() + int(definition.respawn_seconds * 1000)
	if not state.gather(definition):
		_available_at_ms = 0
		return false
	return true

func _process(_delta: float) -> void:
	$Mesh.visible = available()
