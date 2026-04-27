class_name EventDef
extends Resource

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")

@export var id: String = ""
@export var title_key: String = ""
@export var body_key: String = ""
@export var event_weight: int = 1
@export var options: Array[EventOptionDef] = []
