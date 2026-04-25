extends RefCounted

const RngService := preload("res://scripts/core/rng_service.gd")

func test_same_seed_produces_same_sequence() -> void:
	var a := RngService.new(12345)
	var b := RngService.new(12345)
	assert(a.next_int(1, 100) == b.next_int(1, 100))
	assert(a.next_int(1, 100) == b.next_int(1, 100))
	assert(a.pick(["a", "b", "c"]) == b.pick(["a", "b", "c"]))

func test_fork_is_deterministic_by_label() -> void:
	var root_a := RngService.new(777)
	var root_b := RngService.new(777)
	var map_a = root_a.fork("map")
	var map_b = root_b.fork("map")
	assert(map_a.next_int(0, 999) == map_b.next_int(0, 999))
