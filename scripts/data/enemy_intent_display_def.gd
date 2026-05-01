class_name EnemyIntentDisplayDef
extends Resource

@export var id: String = ""
@export_enum("attack", "block", "apply_status", "self_status", "unknown") var intent_kind: String = "unknown"
@export var icon_key: String = ""
@export var label: String = ""
@export var color: Color = Color.WHITE
@export var show_amount: bool = true
@export var show_target: bool = true
