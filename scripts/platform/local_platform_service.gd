class_name LocalPlatformService
extends "res://scripts/platform/platform_service.gd"

var achievements: Dictionary[String, bool] = {}
var stats: Dictionary[String, int] = {}

func unlock_achievement(achievement_id: String) -> void:
	achievements[achievement_id] = true

func set_stat(stat_id: String, value: int) -> void:
	stats[stat_id] = value
