class_name RelicDef
extends Resource

const EffectDef := preload("res://scripts/data/effect_def.gd")

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var trigger_event: String = ""
@export var effects: Array[EffectDef] = []
