extends Node
## Autoload. Music per stage of the day, ambience per place, jingles and sound effects.
## Every file is a CC0 asset from the internet: assets/audio/CREDITS.md lists author and source.
## It listens to EventBus and to the UI, so gameplay scripts need no audio code; minigames and a
## few spots call play_sfx() / play_music() directly.

const MUSIC: Dictionary = {
	&"menu": preload("res://assets/audio/bgm/menu.ogg"),
	&"home": preload("res://assets/audio/bgm/home.ogg"),
	&"commute": preload("res://assets/audio/bgm/commute.ogg"),
	&"work": preload("res://assets/audio/bgm/work.ogg"),
	&"boss": preload("res://assets/audio/bgm/boss.ogg"),
	&"return": preload("res://assets/audio/bgm/return.ogg"),
	&"minigame": preload("res://assets/audio/bgm/minigame.ogg"),
	&"memory": preload("res://assets/audio/bgm/memory.ogg"),
	&"defeat": preload("res://assets/audio/bgm/defeat.ogg"),
}
const JINGLES: Dictionary = {
	&"day_start": preload("res://assets/audio/jingles/day_start.ogg"),
	&"level_clear": preload("res://assets/audio/jingles/level_clear.ogg"),
	&"victory": preload("res://assets/audio/jingles/victory.ogg"),
}
const AMBIENCE: Dictionary = {
	&"street": preload("res://assets/audio/ambience/street.ogg"),
	&"bus": preload("res://assets/audio/ambience/bus.ogg"),
	&"office": preload("res://assets/audio/ambience/office.mp3"),
	&"typing": preload("res://assets/audio/ambience/typing.ogg"),
}
const SFX: Dictionary = {
	&"hit": preload("res://assets/audio/sfx/hit.ogg"),
	&"crash": preload("res://assets/audio/sfx/crash.ogg"),
	&"honk": preload("res://assets/audio/sfx/honk.ogg"),
	&"pickup": preload("res://assets/audio/sfx/pickup.ogg"),
	&"coin": preload("res://assets/audio/sfx/coin.ogg"),
	&"ui_move": preload("res://assets/audio/sfx/ui_move.ogg"),
	&"ui_confirm": preload("res://assets/audio/sfx/ui_confirm.ogg"),
	&"ui_open": preload("res://assets/audio/sfx/ui_open.ogg"),
	&"notify": preload("res://assets/audio/sfx/notify.ogg"),
	&"fall": preload("res://assets/audio/sfx/fall.ogg"),
	&"jolt": preload("res://assets/audio/sfx/jolt.ogg"),
	&"countdown": preload("res://assets/audio/sfx/countdown.ogg"),
	&"go": preload("res://assets/audio/sfx/go.ogg"),
	&"tick": preload("res://assets/audio/sfx/tick.ogg"),
	&"interact": preload("res://assets/audio/sfx/interact.ogg"),
	&"buff": preload("res://assets/audio/sfx/buff.ogg"),
	&"nerf": preload("res://assets/audio/sfx/nerf.ogg"),
	&"decision_good": preload("res://assets/audio/sfx/decision_good.ogg"),
	&"decision_bad": preload("res://assets/audio/sfx/decision_bad.ogg"),
	&"alarm": preload("res://assets/audio/sfx/alarm.ogg"),
}
const PHONE_RING: AudioStream = preload("res://assets/audio/sfx/phone_ring.wav")
const STAGE_MUSIC: Dictionary = {
	DayStep.Stage.HOME: &"home",
	DayStep.Stage.COMMUTE: &"commute",
	DayStep.Stage.WORK: &"work",
	DayStep.Stage.RETURN: &"return",
}
## Ambience layers per BaseLevel.place.
const PLACE_AMBIENCE: Dictionary = {
	"street": [&"street"],
	"bus": [&"bus", &"street"],
	"office": [&"typing", &"office"],
}
## Loudness of each file (RMS dBFS, tools/measure_loudness.gd). The tracks come from different
## authors and differ by up to 15 dB; every track is brought to the same reference.
const LOUDNESS_DB: Dictionary = {
	&"menu": -27.2, &"home": -17.7, &"commute": -13.8, &"work": -12.7, &"boss": -13.5,
	&"return": -18.4, &"minigame": -22.2, &"memory": -18.0, &"defeat": -27.2,
	&"day_start": -17.7, &"level_clear": -21.9, &"victory": -25.2,
}
## Music plays at MUSIC_DB as if every track measured MUSIC_REFERENCE_DB.
const MUSIC_REFERENCE_DB: float = -14.0
const MUSIC_DB: float = -11.0
const JINGLE_REFERENCE_DB: float = -18.0
## Volume of each ambience layer, set by ear against the measured loudness: the street recording and
## the typing (sparse keystrokes, peaks near 0 dB) are quiet; the bus engine and the office hum are loud.
const AMBIENCE_VOLUME_DB: Dictionary = {
	&"street": -6.0, &"bus": -17.0, &"office": -21.0, &"typing": -7.0,
}
const SFX_DB: float = -5.0
const SILENT_DB: float = -60.0
const FADE_SECONDS: float = 0.6
const SFX_VOICES: int = 8
## Stat changes smaller than this (the per-frame flows of model 5) make no buff/nerf sound.
const MIN_AUDIBLE_CHANGE: float = 1.0
## Weight of money against energy and time when judging a decision good or bad (Excel, "Guía").
const MONEY_POINTS: float = 3.0
## El Marcador rings the alarm again when this few seconds are left.
const ALARM_SECONDS_LEFT: float = 10.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: Array[AudioStreamPlayer] = []
var _phone: AudioStreamPlayer
var _current_music: StringName = &""
## Music to return to after a temporary track (a minigame).
var _stage_music: StringName = &""
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Buff/nerf: the changes of one frame add up and make one sound at the end of the frame.
var _pending_change: float = 0.0
var _flush_queued: bool = false
## Frame in which something louder (a hit, a decision, an item) already sounded.
var _quiet_frame: int = -1
var _alarm_rung: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Music keeps playing in the pause menu.
	for stream: AudioStream in MUSIC.values() + AMBIENCE.values():
		stream.set("loop", true)  # AudioStreamOggVorbis and AudioStreamMP3 both have it.
	_music_a = _make_player(MUSIC_DB, Settings.MUSIC_BUS)
	_music_b = _make_player(SILENT_DB, Settings.MUSIC_BUS)
	for i: int in 2:
		_ambience.append(_make_player(SILENT_DB, Settings.SFX_BUS))
	_phone = _make_player(SFX_DB, Settings.SFX_BUS)
	_phone.stream = PHONE_RING
	_phone.finished.connect(_phone.play)  # Rings until stop_phone_ring().
	for i: int in SFX_VOICES:
		_sfx_players.append(_make_player(SFX_DB, Settings.SFX_BUS))

	EventBus.day_step_started.connect(_on_day_step_started)
	EventBus.level_completed.connect(play_jingle.bind(&"level_clear"))
	EventBus.challenge_started.connect(_on_challenge_started)
	EventBus.challenge_clock_changed.connect(_on_challenge_clock_changed)
	EventBus.day_finished.connect(_on_day_finished)
	EventBus.hostile_hit.connect(_on_hostile_hit)
	EventBus.item_used.connect(_on_item_used)
	EventBus.stat_changed.connect(_on_stat_changed)
	EventBus.player_interacted.connect(_on_player_interacted)
	EventBus.decision_requested.connect(play_sfx.bind(&"ui_open").unbind(1))
	EventBus.decision_resolved.connect(_on_decision_resolved)
	EventBus.notification_requested.connect(play_sfx.bind(&"notify").unbind(1))
	EventBus.toast_requested.connect(play_sfx.bind(&"notify").unbind(1))
	GameManager.state_changed.connect(_on_game_state_changed)
	get_viewport().gui_focus_changed.connect(play_sfx.bind(&"ui_move").unbind(1))
	get_tree().node_added.connect(_on_node_added)
	play_music(&"menu")  # The game boots in the main menu.


func _make_player(volume_db: float, bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.bus = bus  # Settings sets the volume of each bus.
	add_child(player)
	return player


## Crossfades to [param track] (a key of MUSIC). Does nothing if it is already playing.
func play_music(track: StringName) -> void:
	if track == _current_music:
		return
	_current_music = track
	var old: AudioStreamPlayer = _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = MUSIC[track]
	_music_a.volume_db = SILENT_DB
	_music_a.play()
	var target_db: float = MUSIC_DB + MUSIC_REFERENCE_DB - LOUDNESS_DB.get(track, MUSIC_REFERENCE_DB)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_music_a, "volume_db", target_db, FADE_SECONDS)
	tween.tween_property(_music_b, "volume_db", SILENT_DB, FADE_SECONDS)
	tween.chain().tween_callback(_music_b.stop)


## A temporary track (minigame); resume_stage_music() goes back to the stage one.
func play_temporary_music(track: StringName) -> void:
	_stage_music = _current_music
	play_music(track)


func resume_stage_music() -> void:
	if not _stage_music.is_empty():
		play_music(_stage_music)
		_stage_music = &""


func stop_music() -> void:
	_current_music = &""
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_music_a, "volume_db", SILENT_DB, FADE_SECONDS)
	tween.tween_property(_music_b, "volume_db", SILENT_DB, FADE_SECONDS)


## Loops the ambience of [param place] (a BaseLevel.place); an unknown place is silence.
func play_ambience(place: String) -> void:
	var layers: Array = PLACE_AMBIENCE.get(place, [])
	for i: int in _ambience.size():
		var player: AudioStreamPlayer = _ambience[i]
		if i >= layers.size():
			player.stop()
			continue
		var stream: AudioStream = AMBIENCE[layers[i]]
		player.volume_db = AMBIENCE_VOLUME_DB[layers[i]]
		if player.stream != stream or not player.playing:
			player.stream = stream
			player.play()


func ring_phone(is_ringing: bool) -> void:
	if is_ringing:
		_phone.play()
	else:
		_phone.stop()


func play_sfx(sound: StringName, pitch: float = 1.0) -> void:
	_play_stream(SFX[sound], pitch, SFX_DB)


func play_jingle(jingle: StringName) -> void:
	_play_stream(JINGLES[jingle], 1.0, SFX_DB + JINGLE_REFERENCE_DB - LOUDNESS_DB[jingle])


func _play_stream(stream: AudioStream, pitch: float, volume_db: float) -> void:
	var player: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func _on_day_step_started(step: DayStep) -> void:
	if step.stage == DayStep.Stage.HOME and step.number_in_stage == 1:
		play_jingle(&"day_start")
	play_music(STAGE_MUSIC[step.stage])
	var level: BaseLevel = get_tree().current_scene as BaseLevel
	play_ambience(level.place if level != null else "")


func _on_challenge_started() -> void:
	_alarm_rung = false
	play_music(&"boss")
	play_sfx(&"alarm")


func _on_challenge_clock_changed(seconds_left: float) -> void:
	if not _alarm_rung and seconds_left <= ALARM_SECONDS_LEFT:
		_alarm_rung = true
		play_sfx(&"alarm")


func _on_day_finished(result: DayResult) -> void:
	play_ambience("")
	ring_phone(false)
	if result.is_victory:
		stop_music()
		for player: AudioStreamPlayer in _sfx_players:
			player.stop()  # The level_clear jingle of the last level.
		play_jingle(&"victory")
	else:
		play_music(&"defeat")


func _on_hostile_hit(definition: HostileDefinition) -> void:
	_quiet_frame = Engine.get_process_frames()
	if definition.drives_in_lane:
		play_sfx(&"crash")
		play_sfx(&"honk")
	else:
		play_sfx(&"hit", randf_range(0.9, 1.1))


func _on_item_used(item: ItemDefinition) -> void:
	_quiet_frame = Engine.get_process_frames()
	play_sfx(&"coin" if item.money > 0.0 else &"pickup")


## A decision sounds good or bad by its weighted total (money counts MONEY_POINTS times).
func _on_decision_resolved(_decision: DecisionDefinition, chosen: DecisionOption) -> void:
	_quiet_frame = Engine.get_process_frames()
	var total: float = chosen.money * MONEY_POINTS + chosen.energy + chosen.time
	play_sfx(&"decision_good" if total >= 0.0 else &"decision_bad")


## Buff/nerf: events, risks and minigame results. The flows of model 5 are too small to sound.
func _on_stat_changed(type: StatDefinition.Type, _new_value: float, change: float) -> void:
	if absf(change) < MIN_AUDIBLE_CHANGE:
		return
	_pending_change += change * (MONEY_POINTS if type == StatDefinition.Type.MONEY else 1.0)
	if not _flush_queued:
		_flush_queued = true
		_flush_stat_sound.call_deferred()


func _flush_stat_sound() -> void:
	_flush_queued = false
	var change: float = _pending_change
	_pending_change = 0.0
	if _quiet_frame == Engine.get_process_frames() or is_zero_approx(change):
		return
	play_sfx(&"buff" if change > 0.0 else &"nerf")


## Objects that are not people or pickups (the phone, the furniture of the house) click.
func _on_player_interacted(target: Node) -> void:
	if not (target is Npc or target is ItemPickup):
		play_sfx(&"interact")


func _on_game_state_changed(new_state: GameState.Type, _previous_state: GameState.Type) -> void:
	if new_state == GameState.Type.MENU:
		play_ambience("")
		ring_phone(false)
		play_music(&"menu")


## Every button in the game clicks when pressed.
func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button != null:
		button.pressed.connect(play_sfx.bind(&"ui_confirm"))
