class_name CombatBackgroundDef
extends Resource

@export var id: String = ""
@export var texture_path: String = ""
@export var environment_tag: String = ""
@export_enum("normal", "elite", "boss", "any") var encounter_tier: String = "any"
@export var accent_color: Color = Color.WHITE
@export_range(0.0, 1.0, 0.01) var dim_opacity: float = 0.35
