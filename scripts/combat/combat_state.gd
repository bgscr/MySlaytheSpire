class_name CombatState
extends RefCounted

const CombatantState := preload("res://scripts/combat/combatant_state.gd")

var turn := 1
var energy := 3
var player: CombatantState
var enemies: Array[CombatantState] = []
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhausted_pile: Array[String] = []
