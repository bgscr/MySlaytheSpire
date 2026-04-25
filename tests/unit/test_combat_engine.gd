extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatEngine := preload("res://scripts/combat/combat_engine.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func test_damage_card_reduces_enemy_hp() -> bool:
	var damage := EffectDef.new()
	damage.effect_type = "damage"
	damage.amount = 6
	var card := CardDef.new()
	card.id = "sword.strike"
	card.cost = 1
	card.effects = [damage]
	var player := CombatantState.new("player", 50)
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	var passed := enemy.current_hp == 14
	assert(passed)
	return passed

func test_block_prevents_damage() -> bool:
	var player := CombatantState.new("player", 50)
	player.block = 4
	player.take_damage(6)
	var passed := player.current_hp == 48 and player.block == 0
	assert(passed)
	return passed
