class_name EventOptionDef
extends Resource

@export var id: String = ""
@export var label_key: String = ""
@export var description_key: String = ""
@export var min_hp: int = 0
@export var min_gold: int = 0
@export var hp_delta: int = 0
@export var gold_delta: int = 0
@export var grant_card_ids: Array[String] = []
@export var grant_relic_ids: Array[String] = []
@export var remove_card_id: String = ""
@export var card_reward_count: int = 0
@export var relic_reward_tier: String = ""
@export var reward_context: String = ""
