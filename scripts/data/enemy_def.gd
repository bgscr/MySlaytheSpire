class_name EnemyDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var max_hp: int = 20
@export var intent_sequence: Array[String] = []
@export var reward_tier: String = "normal"
@export_enum("normal", "elite", "boss") var tier: String = "normal"
@export var encounter_weight: int = 100
@export var gold_reward_min: int = 8
@export var gold_reward_max: int = 14
