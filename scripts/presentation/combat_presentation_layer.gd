class_name CombatPresentationLayer
extends Control

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatPresentationAssetCatalog := preload("res://scripts/presentation/combat_presentation_asset_catalog.gd")
const CombatPresentationQueue := preload("res://scripts/presentation/combat_presentation_queue.gd")

const FLOAT_DURATION := 0.55
const FLASH_COLOR := Color(1.0, 0.92, 0.72)
const HIGHLIGHT_COLOR := Color(1.0, 0.82, 0.35)
const PULSE_COLOR := Color(0.58, 0.86, 0.82)
const SLASH_DURATION := 0.32
const PARTICLE_DURATION := 0.42
const CAMERA_IMPULSE_DURATION := 0.18
const SLOW_MOTION_DURATION := 0.35

var queue: CombatPresentationQueue
var asset_catalog := CombatPresentationAssetCatalog.new()
var targets := {}
var status_targets := {}
var _card_base_positions := {}
var _float_index := 0
var active_slow_motion_scale: float = 1.0
var last_audio_cue_id: String = ""
var audio_cue_count: int = 0
var _slash_index := 0
var _particle_burst_index := 0
var _camera_base_position := Vector2.ZERO
var _slow_motion_wash_index := 0
var _audio_player: AudioStreamPlayer

func bind_target(target_id: String, node: Control) -> void:
	if target_id.is_empty() or node == null:
		return
	targets[target_id] = node

func bind_status_target(target_id: String, node: Control) -> void:
	if target_id.is_empty() or node == null:
		return
	status_targets[target_id] = node

func clear_bindings() -> void:
	targets.clear()
	status_targets.clear()
	_card_base_positions.clear()

func process_queue() -> void:
	if queue == null:
		return
	for event in queue.drain():
		play_event(event)

func play_event(event: CombatPresentationEvent) -> void:
	if event == null:
		return
	match event.event_type:
		"damage_number":
			_show_float_text(event, "-%s" % event.amount, Color(0.86, 0.28, 0.24))
		"block_number":
			_show_float_text(event, "+%s Block" % event.amount, Color(0.36, 0.62, 0.92))
		"status_number":
			_show_float_text(event, _status_text(event), Color(0.42, 0.72, 0.48))
		"combatant_flash":
			_flash_target(event.target_id)
		"status_badge_pulse":
			_pulse_status(event.target_id)
		"target_highlighted":
			_set_highlight(event.target_id, true)
		"target_unhighlighted":
			_set_highlight(event.target_id, false)
		"card_hovered", "card_drag_started":
			_set_card_lift(event.target_id, true)
		"card_unhovered", "card_drag_released":
			_set_card_lift(event.target_id, false)
		"cinematic_slash":
			_show_cinematic_slash(event)
		"particle_burst":
			_show_particle_burst(event)
		"camera_impulse":
			_play_camera_impulse(event)
		"slow_motion":
			_record_slow_motion(event)
		"audio_cue":
			_record_audio_cue(event)

func _show_float_text(event: CombatPresentationEvent, text: String, color: Color) -> void:
	if not targets.has(event.target_id):
		return
	var label := Label.new()
	label.name = "FloatText_%s" % _float_index
	_float_index += 1
	label.text = text
	label.modulate = color
	label.position = _target_position(event.target_id) + Vector2(0.0, -24.0)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, FLOAT_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION)
	tween.finished.connect(label.queue_free)

func _flash_target(target_id: String) -> void:
	var target := targets.get(target_id) as Control
	if target == null:
		return
	var original_modulate := target.modulate
	target.modulate = FLASH_COLOR
	var tween := create_tween()
	tween.tween_property(target, "modulate", original_modulate, FLOAT_DURATION)

func _pulse_status(target_id: String) -> void:
	var target := status_targets.get(target_id, targets.get(target_id)) as Control
	if target == null:
		return
	var original_modulate := target.modulate
	target.modulate = PULSE_COLOR
	var tween := create_tween()
	tween.tween_property(target, "modulate", original_modulate, FLOAT_DURATION)

func _set_highlight(target_id: String, enabled: bool) -> void:
	var target := targets.get(target_id) as Control
	if target == null:
		return
	if enabled:
		target.add_theme_color_override("font_color", HIGHLIGHT_COLOR)
	else:
		target.remove_theme_color_override("font_color")

func _set_card_lift(target_id: String, enabled: bool) -> void:
	var target := targets.get(target_id) as Control
	if target == null:
		return
	if enabled:
		if not _card_base_positions.has(target_id):
			_card_base_positions[target_id] = target.position
		var base_position := _card_base_positions[target_id] as Vector2
		target.position = base_position + Vector2(0.0, -8.0)
	elif _card_base_positions.has(target_id):
		target.position = _card_base_positions[target_id]
		_card_base_positions.erase(target_id)

func _target_position(target_id: String) -> Vector2:
	var target := targets.get(target_id) as Control
	if target == null:
		return Vector2.ZERO
	if target.is_inside_tree() and is_inside_tree():
		return target.global_position - global_position
	return target.position

func _load_texture(asset: Dictionary) -> Texture2D:
	var path := String(asset.get("texture_path", ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D

func _status_text(event: CombatPresentationEvent) -> String:
	if not event.text.is_empty():
		return event.text
	var prefix := "+" if event.amount > 0 else ""
	if event.status_id.is_empty():
		return "%s%s Status" % [prefix, event.amount]
	return "%s%s %s" % [prefix, event.amount, event.status_id]

func _show_cinematic_slash(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var asset := asset_catalog.resolve(event)
	var texture := _load_texture(asset)
	if texture == null:
		return
	var slash := TextureRect.new()
	slash.name = "CinematicSlash_%s" % _slash_index
	_slash_index += 1
	slash.texture = texture
	slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slash.stretch_mode = TextureRect.STRETCH_SCALE
	slash.size = asset.get("size", Vector2(104.0, 34.0))
	slash.pivot_offset = slash.size * 0.5
	slash.rotation = float(asset.get("rotation", -0.55))
	slash.modulate = asset.get("color", Color.WHITE)
	slash.position = _target_position(event.target_id) + Vector2(-24.0, -22.0)
	add_child(slash)

	var duration := float(asset.get("duration", SLASH_DURATION))
	var travel := asset.get("travel", Vector2(28.0, -2.0)) as Vector2
	var scale_to := asset.get("scale_to", Vector2(1.12, 1.0)) as Vector2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "position", slash.position + travel, duration)
	tween.tween_property(slash, "scale", scale_to, duration)
	tween.tween_property(slash, "modulate:a", 0.0, duration)
	tween.finished.connect(slash.queue_free)

func _show_particle_burst(event: CombatPresentationEvent) -> void:
	if not targets.has(event.target_id):
		return
	var asset := asset_catalog.resolve(event)
	var texture := _load_texture(asset)
	if texture == null:
		return
	var burst_index := _particle_burst_index
	_particle_burst_index += 1
	var origin := _target_position(event.target_id) + Vector2(12.0, -10.0)
	var particle_count := maxi(1, int(asset.get("particle_count", 6)))
	var particle_size := asset.get("size", Vector2(18.0, 18.0)) as Vector2
	var radius := float(asset.get("radius", 26.0))
	var duration := float(asset.get("duration", PARTICLE_DURATION))
	var color := asset.get("color", Color.WHITE) as Color
	for particle_index in range(particle_count):
		var particle := TextureRect.new()
		particle.name = "ParticleBurst_%s_%s" % [burst_index, particle_index]
		particle.texture = texture
		particle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		particle.stretch_mode = TextureRect.STRETCH_SCALE
		particle.size = particle_size
		particle.pivot_offset = particle.size * 0.5
		particle.modulate = color
		particle.position = origin
		add_child(particle)
		var angle := TAU * float(particle_index) / float(particle_count)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", origin + offset, duration)
		tween.tween_property(particle, "scale", Vector2(0.6, 0.6), duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.finished.connect(particle.queue_free)

func _show_slow_motion_wash(asset: Dictionary, duration: float) -> void:
	var texture := _load_texture(asset)
	if texture == null:
		return
	var wash := TextureRect.new()
	wash.name = "SlowMotionWash_%s" % _slow_motion_wash_index
	_slow_motion_wash_index += 1
	wash.texture = texture
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.size = asset.get("size", Vector2(120.0, 120.0))
	wash.pivot_offset = wash.size * 0.5
	wash.modulate = asset.get("color", Color(0.72, 0.92, 1.0, 0.2))
	wash.position = _slow_motion_wash_position(wash.size)
	add_child(wash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wash, "scale", Vector2(1.18, 1.18), duration)
	tween.tween_property(wash, "modulate:a", 0.0, duration)
	tween.finished.connect(wash.queue_free)

func _slow_motion_wash_position(wash_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return Vector2.ZERO
	return viewport_size * 0.5 - global_position - wash_size * 0.5

func _play_camera_impulse(event: CombatPresentationEvent) -> void:
	var asset := asset_catalog.resolve(event)
	_camera_base_position = position
	var strength := float(asset.get("strength", 4.0)) * maxf(0.25, event.intensity)
	var direction := asset.get("direction", Vector2(1.0, -0.5)) as Vector2
	position = _camera_base_position + direction * strength
	var tween := create_tween()
	tween.tween_property(
		self,
		"position",
		_camera_base_position,
		float(asset.get("duration", CAMERA_IMPULSE_DURATION))
	)

func _record_slow_motion(event: CombatPresentationEvent) -> void:
	var asset := asset_catalog.resolve(event)
	active_slow_motion_scale = clampf(float(asset.get("scale", event.intensity)), 0.1, 1.0)
	var duration := float(asset.get("duration", SLOW_MOTION_DURATION))
	_show_slow_motion_wash(asset, duration)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func(): active_slow_motion_scale = 1.0)

func _record_audio_cue(event: CombatPresentationEvent) -> void:
	last_audio_cue_id = String(event.payload.get("cue_id", event.text))
	audio_cue_count += 1
	var asset := asset_catalog.resolve(event)
	var path := String(asset.get("audio_path", ""))
	if path.is_empty():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := _presentation_audio_player()
	player.stream = stream
	player.volume_db = float(asset.get("volume_db", -8.0))
	player.play()

func _presentation_audio_player() -> AudioStreamPlayer:
	if _audio_player != null and is_instance_valid(_audio_player):
		return _audio_player
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "PresentationAudioPlayer"
	add_child(_audio_player)
	return _audio_player
