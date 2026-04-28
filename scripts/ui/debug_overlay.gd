extends PanelContainer

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

func _ready() -> void:
	visible = OS.is_debug_build()
	var box := VBoxContainer.new()
	add_child(box)

	var heal := Button.new()
	heal.text = "Debug: Full HP"
	heal.pressed.connect(_full_hp)
	box.add_child(heal)

	var gold := Button.new()
	gold.text = "Debug: +100 Gold"
	gold.pressed.connect(_add_gold)
	box.add_child(gold)

	var map := Button.new()
	map.text = "Debug: Map"
	map.pressed.connect(_go_map)
	box.add_child(map)

	_add_presentation_toggle(box, "DebugPresentationEnabled", "Presentation", "enabled")
	_add_presentation_toggle(box, "DebugPresentationDrag", "Drag Play", "drag_enabled")
	_add_presentation_toggle(box, "DebugPresentationFloatingText", "Float Text", "floating_text_enabled")
	_add_presentation_toggle(box, "DebugPresentationFlash", "Hit Flash", "flash_enabled")
	_add_presentation_toggle(box, "DebugPresentationHighlight", "Target Highlight", "target_highlight_enabled")
	_add_presentation_toggle(box, "DebugPresentationStatusPulse", "Status Pulse", "status_pulse_enabled")
	_add_presentation_toggle(box, "DebugPresentationCinematic", "Future Cinematic", "cinematic_enabled")
	_add_presentation_toggle(box, "DebugPresentationParticles", "Particles", "particle_enabled")
	_add_presentation_toggle(box, "DebugPresentationCameraImpulse", "Camera Impulse", "camera_impulse_enabled")
	_add_presentation_toggle(box, "DebugPresentationSlowMotion", "Slow Motion", "slow_motion_enabled")
	_add_presentation_toggle(box, "DebugPresentationAudioCue", "Audio Cue", "audio_cue_enabled")

func _get_app() -> Node:
	return get_tree().root.get_node_or_null("App")

func _add_presentation_toggle(box: VBoxContainer, node_name: String, label: String, property_name: String) -> void:
	var app := _get_app()
	if app == null or app.game == null or app.game.presentation_config == null:
		return
	var toggle := CheckBox.new()
	toggle.name = node_name
	toggle.text = "Debug: %s" % label
	toggle.button_pressed = bool(app.game.presentation_config.get(property_name))
	toggle.toggled.connect(func(enabled: bool): app.game.presentation_config.set(property_name, enabled))
	box.add_child(toggle)

func _full_hp() -> void:
	var app := _get_app()
	if app == null:
		return
	if app.game.current_run:
		app.game.current_run.current_hp = app.game.current_run.max_hp

func _add_gold() -> void:
	var app := _get_app()
	if app == null:
		return
	if app.game.current_run:
		app.game.current_run.gold += 100

func _go_map() -> void:
	var app := _get_app()
	if app == null:
		return
	if app.game.current_run:
		app.game.router.go_to(SceneRouterScript.MAP)
