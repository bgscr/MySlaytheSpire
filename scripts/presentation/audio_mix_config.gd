class_name AudioMixConfig
extends RefCounted

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const QUIET_DB := -80.0

var _volumes := {
	BUS_MASTER: 1.0,
	BUS_MUSIC: 1.0,
	BUS_SFX: 1.0,
	BUS_UI: 1.0,
}

func required_buses() -> Array[String]:
	return [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI]

func ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_MASTER) == -1:
		return
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_UI)
	apply_all()

func set_bus_volume(bus_name: String, normalized: float) -> void:
	if not _volumes.has(bus_name):
		return
	_volumes[bus_name] = clampf(normalized, 0.0, 1.0)
	_apply_bus_volume(bus_name)

func get_bus_volume(bus_name: String) -> float:
	return float(_volumes.get(bus_name, 1.0))

func apply_all() -> void:
	for bus_name in required_buses():
		_apply_bus_volume(bus_name)

func volume_to_db(normalized: float) -> float:
	var clamped := clampf(normalized, 0.0, 1.0)
	if is_zero_approx(clamped):
		return QUIET_DB
	return linear_to_db(clamped)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus(AudioServer.bus_count)
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, BUS_MASTER)

func _apply_bus_volume(bus_name: String) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, volume_to_db(get_bus_volume(bus_name)))
