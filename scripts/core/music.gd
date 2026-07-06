extends Node
# Music autoload — two playlists:
#   • level playlist (res://MUSIC/*)   — loops from level 1 through the whole game
#   • legend playlist (res://MUSIC/LEGEND/*) — plays while the intro/legend is shown
# Persists across scenes (autoload). HTML5 audio needs a user gesture — the "New Game"
# click unlocks the AudioContext before the world (and Music.start) loads.
#
# On web build, MUSIC/ is excluded from the .pck (see MUSIC/.gdignore) — mp3 files
# are served as static /music/*.mp3 from the server. We hardcode the track list
# here so it works without scanning res://MUSIC at runtime.

var _player: AudioStreamPlayer = null
# Hardcoded track list (filenames only — Music.gd prepends "res://MUSIC/" on native,
# or "/music/" on web). Order matters — index 0 plays first.
const _LEVEL_FILES: Array[String] = [
	"1 (2).mp3", "1 (3).mp3", "1 (4).mp3", "1 (5).mp3", "1 (6).mp3",
	"1 (7).mp3", "1 (8).mp3", "1 (9).mp3", "1 (10).mp3"
]
const _LEGEND_FILES: Array[String] = [
	"a5554209-eba6-451f-a566-e59b66e932d0.mp3",
	"c00e42d5-9c8d-469c-99a5-fa7e941fe80d.mp3"
]
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
	# Build the track lists. On native, prepend res://MUSIC/ so ResourceLoader can
	# load them. On web, we never load via Godot (we use HTML5 <audio> streaming
	# against the static /music/ URL) — but we still keep res:// paths here for
	# consistency; _play_current_web rewrites them to URLs.
	for f: String in _LEVEL_FILES:
		_level_tracks.append("res://MUSIC/" + f)
	for f: String in _LEGEND_FILES:
		_legend_tracks.append("res://MUSIC/LEGEND/" + f)
	_push_debug()

func start() -> void:
	# Idempotent: starts the level playlist once (survives battle/map reloads).
	if _started:
		return
	if _level_tracks.size() == 0:
		return
	_started = true
	_mode = "level"
	_index = 0
	# On web, use HTML5 <audio> streaming (avoids AudioContext.createBuffer crash
	# on large mp3 — see errors.md БАГ-001). Native build uses Godot AudioStreamPlayer.
	if OS.has_feature("web"):
		_play_current_web()
	else:
		_play_current()

func play_legend() -> void:
	# Switch to the legend playlist (intro/legend overlay). Restarts from the start.
	if _legend_tracks.size() == 0:
		return
	_mode = "legend"
	_index = 0
	if OS.has_feature("web"):
		_play_current_web()
	else:
		_play_current()

func resume_level() -> void:
	# Back to the level playlist (only if it had been started).
	if not _started or _level_tracks.size() == 0:
		return
	_mode = "level"
	if OS.has_feature("web"):
		_play_current_web()
	else:
		_play_current()

func stop() -> void:
	_started = false
	if _player:
		_player.stop()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window._bookwarMusic) { window._bookwarMusic.pause(); }", true)

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
	if OS.has_feature("web"):
		_play_current_web()
	else:
		_play_current()

# HTML5 streaming playback — uses an <audio> element pointing at the static
# /music/ URL (files are uploaded to /var/www/bookwar/music/ on the server,
# NOT bundled in the .pck). This avoids both:
#   • AudioContext.createBuffer crash on mobile (БАГ-001) — the browser streams
#     mp3 natively instead of decoding the whole file into one buffer.
#   • Giant base64 strings via JSBridge.eval that hung the JS runtime.
# We register a global window._bookwarMusic <audio> element; _process polls its
# 'ended' event to drive playlist advancement.
func _play_current_web() -> void:
	var list: Array[String] = _current_list()
	if list.size() == 0:
		_push_debug()
		return
	var res_path: String = list[_index]
	# Map res://MUSIC/foo.mp3 → /music/foo.mp3 (same layout on the server).
	# mp3 files are NOT in the .pck (excluded via MUSIC/.gdignore) — they live as
	# static /music/*.mp3 served by nginx, so we never need ResourceLoader here.
	var web_url: String = "/music/" + res_path.substr("res://MUSIC/".length())
	# URL-encode spaces / parens in filenames like "1 (10).mp3".
	var filename: String = web_url.get_file()
	var dir_part: String = web_url.substr(0, web_url.length() - filename.length())
	var encoded_url: String = dir_part + filename.replace(" ", "%20").replace("(", "%28").replace(")", "%29")
	var display_name: String = res_path.get_file()
	var js: String = """
	(function(){
		var url = "%s";
		if (!window._bookwarMusic) {
			window._bookwarMusic = document.createElement('audio');
			window._bookwarMusic.loop = false;
			window._bookwarMusic.style.display = 'none';
			document.body.appendChild(window._bookwarMusic);
			window._bookwarMusic.addEventListener('ended', function(){
				window._bookwarMusicEnded = true;
			});
		}
		window._bookwarMusic.src = url;
		window._bookwarMusic.volume = 0.55;
		// Browsers block autoplay until a user gesture has occurred. We attempt
		// play(); if it rejects, the touchstart/mousedown handler in the HTML
		// shell will retry on the first user gesture.
		var p = window._bookwarMusic.play();
		if (p && p.catch) p.catch(function(e){ console.warn('Music play blocked (will retry on gesture):', e); });
		window._bookwarMusicUrl = url;
		window._bookwarMusicName = "%s";
		return true;
	})()
	""" % [encoded_url, display_name]
	JavaScriptBridge.eval(js, true)
	_push_debug()

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	# Drive playlist advancement by polling the <audio> 'ended' event.
	if JavaScriptBridge.eval("typeof window._bookwarMusicEnded !== 'undefined' && window._bookwarMusicEnded", true):
		JavaScriptBridge.eval("window._bookwarMusicEnded = false;", true)
		_on_finished()

func _push_debug() -> void:
	if OS.has_feature("web"):
		var now_playing: String = ""
		var list: Array[String] = _current_list()
		if list.size() > 0 and _index < list.size():
			now_playing = list[_index].get_file()
		JavaScriptBridge.eval("window.gameMusicDebug = {mode:'" + _mode + "', level:" + str(_level_tracks.size()) + ", legend:" + str(_legend_tracks.size()) + ", index:" + str(_index) + ", playing:" + str(_player != null and _player.playing).to_lower() + ", now:'" + now_playing + "'};")
