extends Node

const MASTER_BUS := "Master"

func _ready() -> void:
	_init_audio_buses()

func play_sfx(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	# Phase 0 placeholder. Real playback routing belongs to later audio work.
	pass

func set_master_volume_db(volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(MASTER_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)

func _init_audio_buses() -> void:
	if AudioServer.get_bus_index(MASTER_BUS) < 0:
		push_warning("AudioManager could not find the Master audio bus.")