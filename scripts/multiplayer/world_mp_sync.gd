extends Node2D
class_name WorldMpSync

# Spawns/updates/removes sprites for other connected players.
# Add as child of WorldMap (above player layer so they render behind UI).

var _remote_players: Dictionary = {} # id -> {sprite: Node2D, label: Label, name: String}
var _send_position_timer: float = 0.0
const SEND_POSITION_INTERVAL: float = 0.1  # 10 Hz
const SPRITE_SIZE: float = 28.0

func _ready() -> void:
	set_process(true)
	if not NetworkManager.is_connected_to_server():
		# Still spawn layer, but invisible. Game works offline.
		return
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.player_moved.connect(_on_player_moved)
	# Register existing players
	for pid in NetworkManager.get_players():
		var p = NetworkManager.get_players()[pid]
		_spawn_remote(pid, p.name, p.x, p.y)

func _process(delta: float) -> void:
	if not NetworkManager.is_connected_to_server():
		return
	_send_position_timer += delta
	if _send_position_timer >= SEND_POSITION_INTERVAL:
		_send_position_timer = 0.0
		var local_player: Node2D = get_parent().get_node_or_null("Player")
		if local_player:
			NetworkManager.send_position(local_player.global_position.x, local_player.global_position.y)

func _spawn_remote(pid: String, pname: String, x: float, y: float) -> void:
	if _remote_players.has(pid):
		return
	var root := Node2D.new()
	root.name = "remote_" + pid
	root.position = Vector2(x, y)
	# Body (cyan circle to distinguish from main hero)
	var body := ColorRect.new()
	body.color = Color(0.3, 0.7, 1.0, 0.95)
	body.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	body.position = Vector2(-SPRITE_SIZE / 2.0, -SPRITE_SIZE / 2.0)
	body.z_index = 5
	root.add_child(body)
	# Outline
	var outline := ColorRect.new()
	outline.color = Color(0.1, 0.2, 0.4, 1.0)
	outline.size = Vector2(SPRITE_SIZE + 4, SPRITE_SIZE + 4)
	outline.position = Vector2(-SPRITE_SIZE / 2.0 - 2, -SPRITE_SIZE / 2.0 - 2)
	outline.z_index = 4
	root.add_child(outline)
	# Name label above
	var label := Label.new()
	label.text = pname
	label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-50, -SPRITE_SIZE / 2.0 - 22)
	label.size = Vector2(100, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 10
	root.add_child(label)
	add_child(root)
	_remote_players[pid] = {sprite = root, label = label, name = pname}

func _despawn_remote(pid: String) -> void:
	if not _remote_players.has(pid):
		return
	var entry = _remote_players[pid]
	if is_instance_valid(entry.sprite):
		entry.sprite.queue_free()
	_remote_players.erase(pid)

func _on_player_joined(pid: String, pname: String, x: float, y: float) -> void:
	_spawn_remote(pid, pname, x, y)

func _on_player_left(pid: String) -> void:
	_despawn_remote(pid)

func _on_player_moved(pid: String, x: float, y: float) -> void:
	if not _remote_players.has(pid):
		# Late spawn
		var players = NetworkManager.get_players()
		if players.has(pid):
			_spawn_remote(pid, players[pid].name, x, y)
		return
	var entry = _remote_players[pid]
	if is_instance_valid(entry.sprite):
		# Smooth interpolation
		var tween := create_tween()
		tween.tween_property(entry.sprite, "position", Vector2(x, y), 0.12)
		tween.play()
