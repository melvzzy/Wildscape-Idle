class_name RecipeDefinition
extends Resource

@export var id: StringName
@export var title: String
@export var costs: Dictionary[StringName, int] = {}
@export var unlock: StringName
@export var required_unlock: StringName
