extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventResolver := preload("res://scripts/event/event_resolver.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_event_resolver_returns_deterministic_event_for_same_run_context() -> bool:
	var catalog := _catalog()
	var run := _run_for_node("event", 707, "node_0")
	var first = EventResolver.new().resolve(catalog, run)
	var second = EventResolver.new().resolve(catalog, run)
	var passed: bool = first != null \
		and second != null \
		and first.id == second.id \
		and [
			"wandering_physician",
			"spirit_toll",
			"quiet_shrine",
			"sealed_sword_tomb",
			"alchemist_market",
			"spirit_beast_tracks",
		].has(first.id)
	assert(passed)
	return passed

func test_event_resolver_uses_node_id_in_rng_context() -> bool:
	var catalog := _catalog()
	var first = EventResolver.new().resolve(catalog, _run_for_node("event", 808, "node_0"))
	var second = EventResolver.new().resolve(catalog, _run_for_node("event", 808, "node_1"))
	var passed: bool = first != null and second != null
	assert(passed)
	return passed

func test_event_resolver_returns_null_for_non_event_node() -> bool:
	var event = EventResolver.new().resolve(_catalog(), _run_for_node("combat", 909, "node_0"))
	var passed := event == null
	assert(passed)
	return passed

func test_event_resolver_returns_null_for_missing_current_node() -> bool:
	var run := _run_for_node("event", 1001, "node_0")
	run.current_node_id = "missing"
	var event = EventResolver.new().resolve(_catalog(), run)
	var passed := event == null
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_for_node(node_type: String, seed_value: int, node_id: String) -> RunState:
	var run := RunState.new()
	run.seed_value = seed_value
	run.current_node_id = node_id
	var node := MapNodeState.new(node_id, 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run
