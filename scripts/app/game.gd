class_name Game
extends Node

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

var router := SceneRouterScript.new()
var current_run
var platform_service
var save_service
