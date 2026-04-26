extends RefCounted

const RngService := preload("res://scripts/core/rng_service.gd")

func test_same_seed_produces_same_sequence() -> bool:
	var a := RngService.new(12345)
	var b := RngService.new(12345)
	var first_matches := a.next_int(1, 100) == b.next_int(1, 100)
	var second_matches := a.next_int(1, 100) == b.next_int(1, 100)
	var pick_matches: bool = a.pick(["a", "b", "c"]) == b.pick(["a", "b", "c"])
	assert(first_matches)
	assert(second_matches)
	assert(pick_matches)
	return first_matches and second_matches and pick_matches

func test_fork_is_deterministic_by_label() -> bool:
	var root_a := RngService.new(777)
	var root_b := RngService.new(777)
	var map_a = root_a.fork("map")
	var map_b = root_b.fork("map")
	var fork_matches: bool = map_a.next_int(0, 999) == map_b.next_int(0, 999)
	assert(fork_matches)
	return fork_matches
