extends Node
# Music autoload — two playlists:
#   • level playlist (res://MUSIC/*)   — loops from level 1 through the whole game
#   • legend playlist (res://MUSIC/LEGEND/*) — plays while the intro/legend is shown
# Persists across scenes (autoload). HTML5 audio needs a user gesture — the "New Game"
# click unlocks the AudioContext before the world (and Music.start) loads.

var _player: AudioStreamPlayer = null
var _level_tracks: Array[String] = []
var _legend_tracks: Array[String] = []
var _index: int = 0
var _mode: String = "level"   # "level" | "legend"
var _started: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.finished.connect(_on_finished)
	_scan_tracks("res://MUSIC", _level_tracks, false)
	_scan_tracks("res://MUSIC/LEGEND", _legend_tracks, true)
	_push_debug()

func _scan_tracks(dir_path: String, into: Array[String], recurse: bool) -> void:
	# Robust discovery: in exported HTML5 builds DirAccess lists remapped entries
	# (e.g. "1 (2).mp3.remap" / ".import" / ".uid"), so we strip those suffixes and
	# probe with ResourceLoader.exists() before adding. A hardcoded fallback covers
	# the known files in case DirAccess itself returns nothing in the PCK.
	_scan_via_diraccess(dir_path, into)
	_scan_via_fallback(dir_path, into)
	# dedupe + sort
	var seen: Dictionary = {}
	var deduped: Array[String] = []
	for p: String in into:
		if not seen.has(p):
			seen[p] = true
			deduped.append(p)
	into.clear()
	for p: String in deduped:
		into.append(p)
	into.sort()

func _scan_via_diraccess(dir_path: String, into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var base: String = fname
			var low: String = fname.to_lower()
			for suf: String in [".import", ".remap", ".uid", ".import"]:
				if low.ends_with(suf):
					base = base.get_basename()
					low = base.to_lower()
			if low.ends_with(".mp3") or low.ends_with(".ogg") or low.ends_with(".wav"):
				var full: String = dir_path + "/" + base
				if ResourceLoader.exists(full):
					into.append(full)
		fname = dir.get_next()
	dir.list_dir_end()

# Known bundled tracks (fallback if DirAccess listing fails in the PCK).
const _FALLBACK_LEVEL: Array[String] = [
	"res://MUSIC/1 (2).mp3", "res://MUSIC/1 (3).mp3", "res://MUSIC/1 (4).mp3",
	"res://MUSIC/1 (5).mp3", "res://MUSIC/1 (6).mp3", "res://MUSIC/1 (7).mp3",
	"res://MUSIC/1 (8).mp3", "res://MUSIC/1 (9).mp3", "res://MUSIC/1 (10).mp3"
]
const _FALLBACK_LEGEND: Array[String] = [
	"res://MUSIC/LEGEND/a5554209-eba6-451f-a566-e59b66e932d0.mp3",
	"res://MUSIC/LEGEND/c00e42d5-9c8d-469c-99a5-fa7e941fe80d.mp3"
]

func _scan_via_fallback(dir_path: String, into: Array[String]) -> void:
	var list: Array[String] = _FALLBACK_LEGEND if dir_path == "res://MUSIC/LEGEND" else _FALLBACK_LEVEL
	for p: String in list:
		if ResourceLoader.exists(p):
			into.append(p)

func start() -> void:
	# Idempotent: starts the level playlist once (survives battle/map reloads).
	if _started:
		return
	if _level_tracks.size() == 0:
		return
	_started = true
	_mode = "level"
	_index = 0
	_play_current()

func play_legend() -> void:
	# Switch to the legend playlist (intro/legend overlay). Restarts from the start.
	if _legend_tracks.size() == 0:
		return
	_mode = "legend"
	_index = 0
	_play_current()

func resume_level() -> void:
	# Back to the level playlist (only if it had been started).
	if not _started or _level_tracks.size() == 0:
		return
	_mode = "level"
	_play_current()

func stop() -> void:
	_started = false
	if _player:
		_player.stop()

func is_playing() -> bool:
	return _player != null and _player.playing

func _current_list() -> Array[String]:
	return _legend_tracks if _mode == "legend" else _level_tracks

func _play_current() -> void:
	var list: Array[String] = _current_list()
	if list.size() == 0 or _player == null:
		_push_debug()
		return
	var stream: AudioStream = load(list[_index])
	if stream == null:
		# skip an unloadable track and try the next
		_index = (_index + 1) % list.size()
		_push_debug()
		return
	# Ensure the track does NOT self-loop (we drive the playlist via `finished`).
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_player.stream = stream
	_player.volume_db = 0.0   # full volume — was -6, some users found it inaudible
	_player.play()
	_push_debug()

func _on_finished() -> void:
	var list: Array[String] = _current_list()
	if list.size() == 0:
		return
	if not _started and _mode == "level":
		return
	_index = (_index + 1) % list.size()
	_play_current()

func _push_debug() -> void:
	if OS.has_feature("web"):
		var now_playing: String = ""
		var list: Array[String] = _current_list()
		if list.size() > 0 and _index < list.size():
			now_playing = list[_index].get_file()
		JavaScriptBridge.eval("window.gameMusicDebug = {mode:'" + _mode + "', level:" + str(_level_tracks.size()) + ", legend:" + str(_legend_tracks.size()) + ", index:" + str(_index) + ", playing:" + str(_player != null and _player.playing).to_lower() + ", now:'" + now_playing + "'};")
