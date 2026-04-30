extends PanelContainer

const SceneRouterScript := preload("res://scripts/app/scene_router.gd")
const CombatPresentationConfig := preload("res://scripts/presentation/combat_presentation_config.gd")

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

	var dev_tools := Button.new()
	dev_tools.name = "DebugDevTools"
	dev_tools.text = "Debug: Dev Tools"
	dev_tools.pressed.connect(_go_dev_tools)
	box.add_child(dev_tools)

	_add_presentation_toggle(box, "DebugPresentationEnabled", "Presentation", "enabled")
	_add_reduced_motion_toggle(box)
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

func _add_reduced_motion_toggle(box: VBoxContainer) -> void:
	var app := _get_app()
	if app == null or app.game == null or app.game.presentation_config == null:
		return
	var toggle := CheckBox.new()
	toggle.name = "DebugPresentationReducedMotion"
	toggle.text = "Debug: Reduced Motion"
	toggle.button_pressed = app.game.presentation_config.is_reduced_motion()
	toggle.toggled.connect(func(enabled: bool):
		var profile := CombatPresentationConfig.MOTION_PROFILE_REDUCED if enabled else CombatPresentationConfig.MOTION_PROFILE_FULL
		app.game.presentation_config.set_motion_profile(profile)
	)
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

func _go_dev_tools() -> void:
	var app := _get_app()
	if app == null:
		return
	app.game.router.go_to(SceneRouterScript.DEV_TOOLS)
