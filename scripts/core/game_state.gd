extends Node

var current_region: String = BookwarConst.DEFAULT_REGION
var current_map_id: String = BookwarConst.MAP_LIGHT_VALLEY
var player_hp: int = BookwarConst.PLAYER_MAX_HP
var player_max_hp: int = BookwarConst.PLAYER_MAX_HP
var story_flags: Dictionary = {}
var is_in_combat: bool = false
var is_in_dialogue: bool = false
var is_paused: bool = false
var player_hidden: bool = false
var combat_cooldown: float = 0.0
var dialogue_text: String = ""
var dialogue_start_time: float = 0.0
# --- Quest system ---
# Active quest on current map: {type, target, count, progress, reward_letter, description}
# (legacy — сейчас только defeat-квесты используют этот слот)
var active_quest: Dictionary = {}
var completed_quests: Array[String] = []  # map_ids where quest is done
# Multi-type quest tracking (Q1-Q2, 2026-07-07):
#   active_quests — все квесты текущей карты (Array[Dictionary])
#   completed_quest_ids — ID выполненных квестов (не map_ids)
#   quest_defeat_progress — {quest_id → kill_count} для defeat-квестов
var active_quests: Array = []
var completed_quest_ids: Array[String] = []
var quest_defeat_progress: Dictionary = {}  # quest_id -> int

var recruits: Array[Dictionary] = []
var selected_hero: Dictionary = {}  # chosen hero from character select screen
var saved_player_position: Vector2 = Vector2(-1.0, -1.0)
# Persisted monster state across battle scene reloads: key (monster_id@x,y) -> {allegiance, alive}
var monster_overrides: Dictionary = {}
# Persisted collected items across battle scene reloads: key (map:index) -> true
var collected_items: Dictionary = {}
var recruit_force_result: int = -1  # -1 random, 0 force fail, 1 force success (test hook)

# Where to go after the intro/legend finishes. Set by callers, consumed by intro._finish.
# "menu"        — back to main_menu (first-launch autolegend)
# "char_select" — to character_select (after "New Game" tap)
# "world"       — straight into the world (default if unset)
var intro_return_to: String = "world"

# Combat transition state — set by request_combat, consumed by battle scene
var pending_combat_monster_id: String = ""
var pending_combat_monster_name: String = ""
var pending_combat_monster_hp: int = 0
var pending_combat_monster_letters: Array = []
# Post-combat cleanup: spawn_id of the monster the player just fought, and
# whether they won. world_map reads these on reload to kill the monster if
# needed (manual combat — unlike auto-recruit combat — doesn't kill the
# monster in-place, so we finish the job on scene return).
var last_combat_monster_spawn_id: String = ""
var last_combat_won: bool = false

signal hp_changed(current: int, maximum: int)
signal region_changed(region_id: String)
signal combat_started
signal combat_ended(player_won: bool)
signal dialogue_started
signal dialogue_ended
signal dialogue_text_set(text: String)
signal dialogue_advance
signal recruit_message(text: String)
signal toast_requested(text: String)
signal combat_requested(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array)
signal recruit_added(recruit: Dictionary)
signal recruit_removed(index: int)

func _ready() -> void:
	# Font/theme is now owned by the I18n autoload (per-locale font chain so
	# Arabic & Chinese render via Noto fallbacks). I18n loads before GameState.
	if I18n:
		I18n.apply_theme_font()

func set_region(region_id: String) -> void:
	if current_region != region_id:
		current_region = region_id
		region_changed.emit(region_id)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = max(0, player_hp - amount)
	hp_changed.emit(player_hp, player_max_hp)

func heal(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = min(player_max_hp, player_hp + amount)
	hp_changed.emit(player_hp, player_max_hp)

func set_story_flag(flag: String, value: Variant = true) -> void:
	story_flags[flag] = value

func has_story_flag(flag: String) -> bool:
	return story_flags.get(flag, false)

func request_combat(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	# Emit a request — world_map listens and transitions to battle scene
	if is_in_combat:
		return
	combat_requested.emit(monster_id, monster_name, enemy_hp, enemy_letters)

func set_pending_combat(monster_id: String, monster_name: String, enemy_hp: int, enemy_letters: Array) -> void:
	pending_combat_monster_id = monster_id
	pending_combat_monster_name = monster_name
	pending_combat_monster_hp = enemy_hp
	pending_combat_monster_letters = enemy_letters.duplicate()

func clear_pending_combat() -> void:
	pending_combat_monster_id = ""
	pending_combat_monster_name = ""
	pending_combat_monster_hp = 0
	pending_combat_monster_letters.clear()

func start_combat() -> void:
	is_in_combat = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = true;")
	combat_started.emit()

func end_combat(player_won: bool = false) -> void:
	is_in_combat = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false;")
	combat_ended.emit(player_won)

func start_dialogue() -> void:
	is_in_dialogue = true
	dialogue_start_time = Time.get_ticks_msec() / 1000.0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = true;")
	dialogue_started.emit()

func end_dialogue() -> void:
	is_in_dialogue = false
	dialogue_text = ""
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDialogueActive = false;")
	dialogue_ended.emit()

func set_dialogue_text(text: String) -> void:
	dialogue_text = text
	if OS.has_feature("web"):
		var escaped: String = text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
		JavaScriptBridge.eval("window.gameDialogueText = '" + escaped + "';")
	dialogue_text_set.emit(text)

func is_player_alive() -> bool:
	return player_hp > 0

func add_recruit(recruit_name: String, letters: Array, recruit_hp: int) -> void:
	var recruit: Dictionary = {
		"name": recruit_name,
		"letters": letters.duplicate(),
		"hp": recruit_hp,
		"max_hp": recruit_hp
	}
	recruits.append(recruit)
	recruit_added.emit(recruit)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")

func remove_recruit(index: int) -> void:
	if index >= 0 and index < recruits.size():
		recruits.remove_at(index)
		recruit_removed.emit(index)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")

func has_recruits() -> bool:
	return recruits.size() > 0

func get_recruit_count() -> int:
	return recruits.size()

func get_strongest_recruit() -> Dictionary:
	if recruits.is_empty():
		return {}
	var best: Dictionary = recruits[0]
	var best_power: int = 0
	for r: Dictionary in recruits:
		var power: int = 0
		for l: String in r.get("letters", []):
			power += AlphabetData.get_base_power(l)
		if power > best_power:
			best_power = power
			best = r
	return best

func remove_strongest_recruit() -> String:
	if recruits.is_empty():
		return ""
	var best_idx: int = 0
	var best_power: int = -1
	for i: int in range(recruits.size()):
		var power: int = 0
		for l: String in recruits[i].get("letters", []):
			power += AlphabetData.get_base_power(l)
		if power > best_power:
			best_power = power
			best_idx = i
	var name: String = recruits[best_idx].get("name", "")
	recruits.remove_at(best_idx)
	recruit_removed.emit(best_idx)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")
	return name

func remove_weakest_recruit() -> String:
	# War attrition: the weakest ally falls. Returns their name, or "" if none.
	if recruits.is_empty():
		return ""
	var worst_idx: int = 0
	var worst_power: int = 999999
	for i: int in range(recruits.size()):
		var power: int = 0
		for l: String in recruits[i].get("letters", []):
			power += AlphabetData.get_base_power(l)
		if power < worst_power:
			worst_power = power
			worst_idx = i
	var wname: String = recruits[worst_idx].get("name", "")
	recruits.remove_at(worst_idx)
	recruit_removed.emit(worst_idx)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameRecruitCount = " + str(recruits.size()) + ";")
	return wname

func reset() -> void:
	current_region = BookwarConst.DEFAULT_REGION
	current_map_id = BookwarConst.MAP_LIGHT_VALLEY
	player_hp = player_max_hp
	story_flags.clear()
	is_in_combat = false
	is_in_dialogue = false
	recruits.clear()
	monster_overrides.clear()
	collected_items.clear()
	clear_pending_combat()
	# Keep selected_hero across resets (so restart uses same hero)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameInCombat = false; window.gameDialogueActive = false; window.gameRecruitCount = 0;")

# --- Monster state persistence across battle scene reloads ---
func save_monster_override(key: String, allegiance: int, alive: bool) -> void:
	monster_overrides[key] = {"allegiance": allegiance, "alive": alive}

func get_monster_override(key: String) -> Dictionary:
	return monster_overrides.get(key, {})

# --- Collected-item persistence across battle scene reloads ---
func mark_item_collected(key: String) -> void:
	collected_items[key] = true

func is_item_collected(key: String) -> bool:
	return collected_items.has(key)

# --- Quest system ---

# Инициализация квестов при входе на карту. Вызывается из world_map._ready.
# Карты 1-2 — без квестов (обучение).
# Карта N (N>=3) — N-2 квеста разных типов (через QuestData).
func start_quest_for_map(map_id: String) -> void:
	var chain_idx: int = BookwarConst.MAP_CHAIN.find(map_id)
	# Старый single-quest API для backwards compat (используется на карте 1 в HUD)
	active_quest = {}
	if chain_idx < 2:
		# Карты 1, 2 — без квестов
		active_quests = []
		_sync_quest_js_bridge()
		return
	active_quests = QuestData.get_quests_for_map(map_id)
	# Убираем уже выполненные
	var filtered: Array = []
	for q: Dictionary in active_quests:
		var qid: String = String(q.get("id", ""))
		if not completed_quest_ids.has(qid):
			filtered.append(q)
	active_quests = filtered
	# Для legacy HUD — показываем первый невыполненный как active_quest
	if not active_quests.is_empty():
		active_quest = active_quests[0]
	_sync_quest_js_bridge()
	# Toast: показать квесты карты
	if not active_quests.is_empty():
		var msg: String = "📜 Квестов на карте: " + str(active_quests.size())
		toast_requested.emit(msg)

func quest_progress_defeat() -> void:
	# Инкремент прогресса ВСЕХ активных defeat-квестов (один убитый враг засчитывается всем)
	var any_progressed: bool = false
	for q: Dictionary in active_quests:
		if String(q.get("type", "")) != "defeat":
			continue
		var qid: String = String(q.get("id", ""))
		quest_defeat_progress[qid] = int(quest_defeat_progress.get(qid, 0)) + 1
		any_progressed = true
	if not any_progressed and not active_quest.is_empty():
		# Legacy: старый single-quest API
		active_quest["progress"] = int(active_quest["progress"]) + 1
		if int(active_quest["progress"]) >= int(active_quest["target"]):
			_quest_complete_legacy()
	_sync_quest_js_bridge()

# Прогресс defeat-квеста по его ID (для QuestData.can_complete)
func quest_progress_for(quest_id: String) -> int:
	return int(quest_defeat_progress.get(quest_id, 0))

# Проверить и засчитать выполнимые квесты (вызывается при диалоге с NPC).
# Возвращает число выполненных.
func try_complete_quest(quest: Dictionary) -> bool:
	var qid: String = String(quest.get("id", ""))
	if completed_quest_ids.has(qid):
		return false
	if not QuestData.can_complete(quest):
		return false
	QuestData.complete_quest(quest)
	completed_quest_ids.append(qid)
	active_quests.erase(quest)
	if active_quest == quest:
		active_quest = {}
	toast_requested.emit("★ Квест выполнен: " + String(quest.get("description", "")).substr(0, 40))
	_sync_quest_js_bridge()
	return true

func mark_quest_completed(qid: String) -> void:
	if not completed_quest_ids.has(qid):
		completed_quest_ids.append(qid)

func is_quest_complete(map_id: String) -> bool:
	# Legacy — хотя бы один квест карты выполнен
	var quests: Array = QuestData.get_quests_for_map(map_id)
	for q: Dictionary in quests:
		if completed_quest_ids.has(String(q.get("id", ""))):
			return true
	return false

func _quest_complete_legacy() -> void:
	if active_quest.is_empty():
		return
	var reward: String = String(active_quest.get("reward_letter", "А"))
	InventoryManager.add_letter(reward)
	var map_id: String = current_map_id
	completed_quests.append(map_id)
	var msg: String = "Quest complete! Reward: letter " + reward
	recruit_message.emit(msg)
	toast_requested.emit("★ Квест выполнен! Получена буква: " + reward)
	active_quest = {}
	_sync_quest_js_bridge()

# Снимок квестов для JS bridge (Puppeteer/UI).
func _sync_quest_js_bridge() -> void:
	if not OS.has_feature("web"):
		return
	var snapshot: Dictionary = {
		"active": [],
		"completed_count": completed_quest_ids.size(),
	}
	for q: Dictionary in active_quests:
		var qid: String = String(q.get("id", ""))
		var qcopy: Dictionary = q.duplicate()
		if String(q.get("type", "")) == "defeat":
			qcopy["progress"] = int(quest_defeat_progress.get(qid, 0))
		snapshot["active"].append(qcopy)
	var json_str: String = JSON.stringify(snapshot)
	# Escape single quotes для JS
	json_str = json_str.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.gameQuests = '" + json_str + "';")
	# Legacy: window.gameQuest для HUD
	if not active_quest.is_empty():
		var q: Dictionary = active_quest
		var desc: String = String(q.get("description", ""))
		desc = desc.replace("\\", "\\\\").replace("'", "\\'")
		var target: int = int(q.get("requirement", {}).get("count", 0))
		var prog: int = int(quest_defeat_progress.get(String(q.get("id", "")), 0))
		JavaScriptBridge.eval("window.gameQuest = {target:" + str(target) + ", progress:" + str(prog) + ", desc:'" + desc + "'};")
	else:
		JavaScriptBridge.eval("window.gameQuest = null;")
