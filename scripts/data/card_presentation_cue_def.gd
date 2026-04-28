class_name CardPresentationCueDef
extends Resource

@export var event_type: String = ""
@export_enum("played_target", "source", "player", "none") var target_mode: String = "played_target"
@export var amount: int = 0
@export var intensity: float = 1.0
@export var cue_id: String = ""
@export var tags: Array[String] = []
@export var payload: Dictionary = {}
