class_name EventResolver
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RngService := preload("res://scripts/core/rng_service.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func resolve(catalog: ContentCatalog, run: RunState) -> EventDef:
	if catalog == null or run == null:
		return null
	var node := _current_node(run)
	if node == null or node.node_type != "event":
		return null
	var events := catalog.get_events()
	if events.is_empty():
		return null
	var rng := RngService.new(run.seed_value).fork("event:%s" % node.id)
	return _pick_weighted_event(rng, events)

func _pick_weighted_event(rng: RngService, events: Array[EventDef]) -> EventDef:
	var total := 0
	for event in events:
		total += max(0, event.event_weight)
	if total <= 0:
		return events[0]
	var roll := rng.next_int(1, total)
	var cumulative := 0
	for event in events:
		cumulative += max(0, event.event_weight)
		if roll <= cumulative:
			return event
	return events[0]

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
