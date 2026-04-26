class_name RngService
extends RefCounted

var seed_value: int
var _rng := RandomNumberGenerator.new()

func _init(initial_seed: int = 1) -> void:
	seed_value = initial_seed
	_rng.seed = initial_seed

func next_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func next_float() -> float:
	return _rng.randf()

func pick(items: Array):
	assert(items.size() > 0, "Cannot pick from an empty array.")
	return items[next_int(0, items.size() - 1)]

func shuffle_copy(items: Array) -> Array:
	var copy := items.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := next_int(0, i)
		var tmp = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy

func fork(label: String) -> RngService:
	var context := "%s:%s" % [seed_value, label]
	return get_script().new(hash(context)) as RngService
