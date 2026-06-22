extends Node
# Music autoload — plays the level playlist (res://MUSIC/*) on loop from the start
# of level 1 and throughout the whole game. Persists across scene changes.
# The intro/splash will use a different melody (handled separately later).

var _player: AudioStreamPlayer = null
var _tracks: Array[String] = []
var _index: int = 0
var _started: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.finished.connect(_on_finished)
	_scan_tracks()

func _scan_tracks() -> void:
	var dir: DirAccess = DirAccess.open("res://MUSIC")
	if dir == null:
		push_warning("Music: res://MUSIC folder not found")
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext: String = fname.get_extension().to_lower()
			if ext == "mp3" or ext == "ogg" or ext == "wav":
				_tracks.append("res://MUSIC/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_tracks.sort()

func start() -> void:
	# Idempotent: only starts once (survives battle/map reloads since this is an autoload).
	if _started:
		return
	if _tracks.size() == 0:
		return
	_started = true
	_index = 0
	_play_current()

func stop() -> void:
	_started = false
	if _player:
		_player.stop()

func is_playing() -> bool:
	return _started and _player != null and _player.playing

func _play_current() -> void:
	if _tracks.size() == 0 or _player == null:
		return
	var stream: AudioStream = load(_tracks[_index])
	if stream == null:
		# skip an unloadable track and try the next
		_index = (_index + 1) % _tracks.size()
		return
	_player.stream = stream
	_player.volume_db = -6.0
	_player.play()

func _on_finished() -> void:
	if not _started:
		return
	# Loop the whole playlist end-to-end, then restart from track 0.
	_index = (_index + 1) % _tracks.size()
	_play_current()
