extends Node
## Autoload. Music per stage of the day and sound effects (all original, tools/generate_audio.py).
## It listens to EventBus and to the UI, so gameplay scripts need no audio code; minigames and a
## few spots call play_sfx() / play_music() directly.

const MUSIC: Dictionary = {
	&"home": preload("res://assets/audio/bgm/home.wav"),
	&"commute": preload("res://assets/audio/bgm/commute.wav"),
	&"work": preload("res://assets/audio/bgm/work.wav"),
	&"boss": preload("res://assets/audio/bgm/boss.wav"),
	&"return": preload("res://assets/audio/bgm/return.wav"),
	&"minigame": preload("res://assets/audio/bgm/minigame.wav"),
}
const JINGLES: Dictionary = {
	&"victory": preload("res://assets/audio/bgm/victory.wav"),
	&"defeat": preload("res://assets/audio/bgm/defeat.wav"),
}
const SFX: Dictionary = {
	&"hit": preload("res://assets/audio/sfx/hit.wav"),
	&"crash": preload("res://assets/audio/sfx/crash.wav"),
	&"honk": preload("res://assets/audio/sfx/honk.wav"),
	&"pickup": preload("res://assets/audio/sfx/pickup.wav"),
	&"coin": preload("res://assets/audio/sfx/coin.wav"),
	&"ui_move": preload("res://assets/audio/sfx/ui_move.wav"),
	&"ui_confirm": preload("res://assets/audio/sfx/ui_confirm.wav"),
	&"ui_open": preload("res://assets/audio/sfx/ui_open.wav"),
	&"notify": preload("res://assets/audio/sfx/notify.wav"),
	&"fall": preload("res://assets/audio/sfx/fall.wav"),
	&"jolt": preload("res://assets/audio/sfx/jolt.wav"),
	&"countdown": preload("res://assets/audio/sfx/countdown.wav"),
	&"go": preload("res://assets/audio/sfx/go.wav"),
	&"tick": preload("res://assets/audio/sfx/tick.wav"),
}
const STAGE_MUSIC: Dictionary = {
	DayStep.Stage.HOME: &"home",
	DayStep.Stage.COMMUTE: &"commute",
	DayStep.Stage.WORK: &"work",
	DayStep.Stage.RETURN: &"return",
}
const MUSIC_DB: float = -11.0
const SFX_DB: float = -5.0
const SILENT_DB: float = -60.0
const FADE_SECONDS: float = 0.6
const SFX_VOICES: int = 8

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music: StringName = &""
## Music to return to after a temporary track (a minigame).
var _stage_music: StringName = &""
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Music keeps playing in the pause menu.
	for stream: AudioStreamWAV in MUSIC.values():
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music_a = _make_player(MUSIC_DB)
	_music_b = _make_player(SILENT_DB)
	for i: int in SFX_VOICES:
		_sfx_players.append(_make_player(SFX_DB))

	EventBus.day_step_started.connect(_on_day_step_started)
	EventBus.challenge_started.connect(play_music.bind(&"boss"))
	EventBus.day_finished.connect(_on_day_finished)
	EventBus.hostile_hit.connect(_on_hostile_hit)
	EventBus.item_used.connect(_on_item_used)
	EventBus.decision_requested.connect(play_sfx.bind(&"ui_open").unbind(1))
	EventBus.decision_resolved.connect(play_sfx.bind(&"ui_confirm").unbind(2))
	EventBus.notification_requested.connect(play_sfx.bind(&"notify").unbind(1))
	EventBus.toast_requested.connect(play_sfx.bind(&"notify").unbind(1))
	GameManager.state_changed.connect(_on_game_state_changed)
	get_viewport().gui_focus_changed.connect(play_sfx.bind(&"ui_move").unbind(1))
	get_tree().node_added.connect(_on_node_added)
	play_music(&"home")  # The game boots in the main menu.


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.volume_db = volume_db
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
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_music_a, "volume_db", MUSIC_DB, FADE_SECONDS)
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


func play_sfx(sound: StringName, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = SFX[sound]
	player.pitch_scale = pitch
	player.play()


func _on_day_step_started(step: DayStep) -> void:
	play_music(STAGE_MUSIC[step.stage])


func _on_day_finished(result: DayResult) -> void:
	stop_music()
	var player: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = JINGLES[&"victory" if result.is_victory else &"defeat"]
	player.pitch_scale = 1.0
	player.play()


func _on_hostile_hit(definition: HostileDefinition) -> void:
	if definition.drives_in_lane:
		play_sfx(&"crash")
		play_sfx(&"honk")
	else:
		play_sfx(&"hit", randf_range(0.9, 1.1))


func _on_item_used(item: ItemDefinition) -> void:
	play_sfx(&"coin" if item.money > 0.0 else &"pickup")


func _on_game_state_changed(new_state: GameState.Type, _previous_state: GameState.Type) -> void:
	if new_state == GameState.Type.MENU:
		play_music(&"home")


## Every button in the game clicks when pressed.
func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button != null:
		button.pressed.connect(play_sfx.bind(&"ui_confirm"))
