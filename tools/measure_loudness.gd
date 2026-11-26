extends SceneTree
## Prints the loudness (RMS and peak, dBFS, first 4 s) of every file in assets/audio/{bgm,ambience,jingles}.
## AudioManager.LOUDNESS_DB comes from here: run it again after changing a track.
## Run (needs a real audio device, not --headless): godot --path . -s res://tools/measure_loudness.gd
func _initialize() -> void:
	await process_frame
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "Measure")
	AudioServer.set_bus_mute(bus, false)
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 10.0
	AudioServer.add_bus_effect(bus, cap)
	AudioServer.set_bus_send(bus, "Master")
	AudioServer.set_bus_volume_db(0, -80.0)  # Silent speakers; the capture is before the master.
	var files := []
	for d in ["bgm", "ambience", "jingles"]:
		for f in DirAccess.get_files_at("res://assets/audio/" + d):
			if f.ends_with(".ogg") or f.ends_with(".mp3") or f.ends_with(".wav"):
				files.append("res://assets/audio/%s/%s" % [d, f])
	var player := AudioStreamPlayer.new()
	player.bus = "Measure"
	root.add_child(player)
	for path in files:
		player.stream = load(path)
		cap.clear_buffer()
		player.play()
		await create_timer(4.0).timeout
		player.stop()
		var frames := cap.get_buffer(cap.get_frames_available())
		var sum := 0.0
		var peak := 0.0
		for v in frames:
			var m: float = (v.x * v.x + v.y * v.y) * 0.5
			sum += m
			peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		var rms := sqrt(sum / maxf(frames.size(), 1))
		print("%-45s rms %6.1f dB  peak %6.1f dB  frames %d" % [path.get_file() + " (" + path.get_base_dir().get_file() + ")", linear_to_db(rms), linear_to_db(peak), frames.size()])
	quit()
