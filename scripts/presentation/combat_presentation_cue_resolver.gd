class_name CombatPresentationCueResolver
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

const CAMERA_INTENSITY_PER_DAMAGE := 0.08
const CAMERA_INTENSITY_MIN := 0.4
const CAMERA_INTENSITY_MAX := 1.8

func resolve_card_play(
	card: CardDef,
	source_id: String,
	played_target_id: String,
	delta_events: Array
) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if card == null:
		return events
	if not card.presentation_cues.is_empty():
		for cue in card.presentation_cues:
			var typed_cue := cue as CardPresentationCueDef
			if typed_cue == null or typed_cue.event_type.is_empty():
				continue
			events.append(_event_from_cue(card, typed_cue, source_id, played_target_id))
		return events
	return _fallback_events(card, source_id, played_target_id, delta_events)

func _event_from_cue(
	card: CardDef,
	cue: CardPresentationCueDef,
	source_id: String,
	played_target_id: String
) -> CombatPresentationEvent:
	var event := CombatPresentationEvent.new(cue.event_type)
	event.card_id = card.id
	event.source_id = source_id
	event.target_id = _target_for_mode(cue.target_mode, source_id, played_target_id)
	event.amount = cue.amount
	event.intensity = cue.intensity
	event.tags = cue.tags.duplicate()
	event.payload = cue.payload.duplicate(true)
	if not cue.cue_id.is_empty():
		event.payload["cue_id"] = cue.cue_id
	return event

func _target_for_mode(target_mode: String, source_id: String, played_target_id: String) -> String:
	match target_mode:
		"played_target":
			return played_target_id
		"source":
			return source_id
		"player":
			return "player"
		"none":
			return ""
	return played_target_id

func _fallback_events(
	card: CardDef,
	source_id: String,
	played_target_id: String,
	delta_events: Array
) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if _should_emit_slash(card):
		var slash := CombatPresentationEvent.new("cinematic_slash")
		slash.card_id = card.id
		slash.source_id = source_id
		slash.target_id = played_target_id
		slash.intensity = 1.0
		slash.tags = ["cinematic"]
		events.append(slash)
	if _should_emit_particle(card):
		var particle := CombatPresentationEvent.new("particle_burst")
		particle.card_id = card.id
		particle.source_id = source_id
		particle.target_id = played_target_id if not played_target_id.is_empty() else "player"
		particle.intensity = 1.0
		events.append(particle)
	var max_damage := _max_damage_amount(delta_events)
	if max_damage > 0:
		var impulse := CombatPresentationEvent.new("camera_impulse")
		impulse.card_id = card.id
		impulse.source_id = source_id
		impulse.intensity = clampf(
			float(max_damage) * CAMERA_INTENSITY_PER_DAMAGE,
			CAMERA_INTENSITY_MIN,
			CAMERA_INTENSITY_MAX
		)
		events.append(impulse)
	return events

func _should_emit_slash(card: CardDef) -> bool:
	if card.character_id == "sword" and card.card_type == "attack":
		return true
	for effect in card.effects:
		var typed_effect := effect as EffectDef
		if typed_effect == null:
			continue
		if typed_effect.effect_type == "damage" and _targets_enemy(typed_effect.target):
			return true
	return false

func _should_emit_particle(card: CardDef) -> bool:
	if card.character_id == "alchemy":
		return true
	for effect in card.effects:
		var typed_effect := effect as EffectDef
		if typed_effect == null:
			continue
		if typed_effect.effect_type == "apply_status" and typed_effect.status_id == "poison":
			return true
	return false

func _targets_enemy(target: String) -> bool:
	var normalized := target.to_lower()
	return normalized == "enemy" or normalized == "target"

func _max_damage_amount(delta_events: Array) -> int:
	var max_damage := 0
	for event in delta_events:
		if event == null:
			continue
		if event.event_type == "damage_number":
			max_damage = max(max_damage, int(event.amount))
	return max_damage
