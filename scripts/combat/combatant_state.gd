class_name CombatantState
extends RefCounted

var id: String
var max_hp: int
var current_hp: int
var block := 0
var statuses := {}

func _init(combatant_id: String = "", hp: int = 1) -> void:
	id = combatant_id
	max_hp = hp
	current_hp = hp

func take_damage(amount: int) -> int:
	var prevented: int = min(block, amount)
	block -= prevented
	var remaining: int = amount - prevented
	current_hp = max(0, current_hp - remaining)
	return remaining

func gain_block(amount: int) -> void:
	block += amount

func is_defeated() -> bool:
	return current_hp <= 0
