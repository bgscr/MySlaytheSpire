class_name CombatPresentationAssetCatalog
extends RefCounted

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")

const TEXTURE_SLASH_CYAN := "res://assets/presentation/textures/slash_cyan.png"
const TEXTURE_SLASH_GOLD := "res://assets/presentation/textures/slash_gold.png"
const TEXTURE_MIST_GREEN := "res://assets/presentation/textures/mist_green.png"
const TEXTURE_MIST_VIOLET := "res://assets/presentation/textures/mist_violet.png"
const TEXTURE_SLOW_WASH := "res://assets/presentation/textures/slow_motion_wash.png"
const AUDIO_SLASH_LIGHT := "res://assets/presentation/audio/slash_light.wav"
const AUDIO_ALCHEMY_MIST := "res://assets/presentation/audio/alchemy_mist.wav"
const AUDIO_SPIRIT_IMPACT_HEAVY := "res://assets/presentation/audio/spirit_impact_heavy.wav"

var _cue_assets := {
	"cinematic_slash:sword.strike": {
		"texture_path": TEXTURE_SLASH_CYAN,
		"size": Vector2(118.0, 38.0),
		"travel": Vector2(34.0, -4.0),
		"rotation": -0.45,
		"duration": 0.28,
		"scale_to": Vector2(1.18, 1.05),
		"color": Color(0.92, 0.98, 1.0, 0.95),
	},
	"particle_burst:alchemy.toxic_pill": {
		"texture_path": TEXTURE_MIST_VIOLET,
		"particle_count": 7,
		"radius": 30.0,
		"duration": 0.48,
		"size": Vector2(20.0, 20.0),
		"color": Color(0.82, 0.72, 1.0, 0.92),
	},
	"cinematic_slash:enemy.attack": {
		"texture_path": TEXTURE_SLASH_GOLD,
		"size": Vector2(122.0, 40.0),
		"travel": Vector2(-28.0, 6.0),
		"rotation": 0.45,
		"duration": 0.24,
		"scale_to": Vector2(1.14, 1.04),
		"color": Color(1.0, 0.86, 0.58, 0.95),
	},
	"camera_impulse:enemy.attack": {
		"strength": 5.5,
		"duration": 0.16,
		"direction": Vector2(-1.0, 0.45),
	},
	"particle_burst:enemy.block": {
		"texture_path": TEXTURE_MIST_GREEN,
		"particle_count": 5,
		"radius": 22.0,
		"duration": 0.36,
		"size": Vector2(18.0, 18.0),
		"color": Color(0.7, 1.0, 0.78, 0.9),
	},
	"particle_burst:enemy.status.poison": {
		"texture_path": TEXTURE_MIST_VIOLET,
		"particle_count": 7,
		"radius": 28.0,
		"duration": 0.44,
		"size": Vector2(20.0, 20.0),
		"color": Color(0.78, 0.65, 1.0, 0.92),
	},
	"particle_burst:enemy.status.broken_stance": {
		"texture_path": TEXTURE_SLASH_GOLD,
		"particle_count": 4,
		"radius": 24.0,
		"duration": 0.32,
		"size": Vector2(22.0, 12.0),
		"color": Color(1.0, 0.82, 0.48, 0.9),
	},
	"particle_burst:enemy.status.sword_focus": {
		"texture_path": TEXTURE_SLASH_CYAN,
		"particle_count": 4,
		"radius": 20.0,
		"duration": 0.34,
		"size": Vector2(20.0, 12.0),
		"color": Color(0.76, 0.95, 1.0, 0.9),
	},
	"slow_motion:sword.heaven_cutting_arc": {
		"texture_path": TEXTURE_SLOW_WASH,
		"scale": 0.45,
		"duration": 0.52,
		"size": Vector2(144.0, 144.0),
		"color": Color(0.72, 0.92, 1.0, 0.28),
	},
	"audio_cue:sword.heaven_cutting_arc": {
		"audio_path": AUDIO_SPIRIT_IMPACT_HEAVY,
		"volume_db": -7.0,
	},
}

var _event_assets := {
	"cinematic_slash": {
		"texture_path": TEXTURE_SLASH_CYAN,
		"size": Vector2(104.0, 34.0),
		"travel": Vector2(28.0, -2.0),
		"rotation": -0.55,
		"duration": 0.32,
		"scale_to": Vector2(1.12, 1.0),
		"color": Color(0.9, 0.96, 1.0, 0.9),
	},
	"particle_burst": {
		"texture_path": TEXTURE_MIST_GREEN,
		"particle_count": 6,
		"radius": 26.0,
		"duration": 0.42,
		"size": Vector2(18.0, 18.0),
		"color": Color(0.62, 1.0, 0.72, 0.9),
	},
	"camera_impulse": {
		"strength": 4.0,
		"duration": 0.18,
		"direction": Vector2(1.0, -0.5),
	},
	"slow_motion": {
		"texture_path": TEXTURE_SLOW_WASH,
		"scale": 0.65,
		"duration": 0.35,
		"size": Vector2(120.0, 120.0),
		"color": Color(0.72, 0.92, 1.0, 0.2),
	},
}

func resolve(event: CombatPresentationEvent) -> Dictionary:
	if event == null:
		return {}
	var event_type := String(event.event_type)
	var cue_id := String(event.payload.get("cue_id", ""))
	if not cue_id.is_empty():
		var cue_key := "%s:%s" % [event_type, cue_id]
		if _cue_assets.has(cue_key):
			return _cue_assets[cue_key].duplicate(true)
	if _event_assets.has(event_type):
		return _event_assets[event_type].duplicate(true)
	return {}

func resource_paths() -> Array[String]:
	var paths: Array[String] = []
	for asset in _cue_assets.values():
		_append_asset_paths(paths, asset)
	for asset in _event_assets.values():
		_append_asset_paths(paths, asset)
	for path in [
		TEXTURE_SLASH_GOLD,
		AUDIO_SLASH_LIGHT,
		AUDIO_ALCHEMY_MIST,
	]:
		if not paths.has(path):
			paths.append(path)
	return paths

func _append_asset_paths(paths: Array[String], asset: Dictionary) -> void:
	for key in ["texture_path", "audio_path"]:
		var path := String(asset.get(key, ""))
		if not path.is_empty() and not paths.has(path):
			paths.append(path)
