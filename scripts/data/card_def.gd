class_name CardDef
extends Resource

const EffectDef := preload("res://scripts/data/effect_def.gd")

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var cost: int = 1
@export_enum("attack", "skill", "power") var card_type: String = "attack"
@export_enum("common", "uncommon", "rare") var rarity: String = "common"
@export var tags: Array[String] = []
@export var effects: Array[EffectDef] = []
