class_name CardDef
extends Resource

const EffectDef := preload("res://scripts/data/effect_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var cost: int = 1
@export_enum("attack", "skill", "power") var card_type: String = "attack"
@export_enum("common", "uncommon", "rare") var rarity: String = "common"
@export var tags: Array[String] = []
@export var effects: Array[EffectDef] = []
@export var presentation_cues: Array[CardPresentationCueDef] = []
@export var character_id: String = ""
@export var pool_tags: Array[String] = []
@export var reward_weight: int = 100
