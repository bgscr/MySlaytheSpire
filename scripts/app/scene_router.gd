class_name SceneRouter
extends Node

const MAIN_MENU := "res://scenes/menu/MainMenu.tscn"
const MAP := "res://scenes/map/MapScreen.tscn"
const COMBAT := "res://scenes/combat/CombatScreen.tscn"
const REWARD := "res://scenes/reward/RewardScreen.tscn"
const SUMMARY := "res://scenes/summary/RunSummaryScreen.tscn"

var host: Control
var current_scene: Node

func setup(scene_host: Control) -> void:
	host = scene_host

func go_to(scene_path: String) -> Node:
	if current_scene:
		current_scene.queue_free()
	var packed := load(scene_path) as PackedScene
	current_scene = packed.instantiate()
	host.add_child(current_scene)
	return current_scene
