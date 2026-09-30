extends Node
# QuestData — autoload singleton. Реестр всех квестов (ручные + автосгенерированные).
#
# Прогрессия (AGENTS.md §18.3, Q2):
#   - Карты 1-2 (light_valley, two_letter_forest) — НЕТ квестов (обучение).
#   - Карта N (N >= 3) — ровно max(1, N-2) квестов, типы чередуются.
#   - Карты 3-5 (dark_oaks, mossy_lowlands, rotten_swamps) — storyline из data/quests.json.
#   - Карты 6-33 — автогенерация из шаблонов (defeat/collect/buy/trade/talk).

var _manual_quests: Array = []   # загруженные из data/quests.json
var _generated_cache: Dictionary = {}  # map_id -> Array[Dictionary]

const QUEST_TYPES_CYCLE: Array[String] = ["defeat", "collect", "buy", "trade", "talk"]

func _ready() -> void:
	_load_manual_quests()
	# §I18N §2.0: quest pools depend on the current locale's alphabet —
	# invalidate the generated cache when the player switches language.
	if I18n != null:
		I18n.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	_generated_cache.clear()

func _load_manual_quests() -> void:
	var file: FileAccess = FileAccess.open("res://data/quests.json", FileAccess.READ)
	if file == null:
		push_warning("QuestData: data/quests.json not found, only auto-gen quests will be available")
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("QuestData: failed to parse data/quests.json")
		return
	var data: Dictionary = json.get_data()
	var arr: Variant = data.get("quests", [])
	if arr is Array:
		_manual_quests = arr

# Все квесты для карты map_id. Включает ручные + автосгенерированные.
func get_quests_for_map(map_id: String) -> Array:
	if _generated_cache.has(map_id):
		return _generated_cache[map_id]
	var result: Array = []
	# Сначала ручные
	for q: Dictionary in _manual_quests:
		if String(q.get("map_id", "")) == map_id:
			result.append(q)
	# Потом автосгенерированные (если карта имеет индекс >= 2 в цепочке)
	var chain_idx: int = BookwarConst.MAP_CHAIN.find(map_id)
	if chain_idx >= 2:
		var auto_count: int = maxi(1, chain_idx - 1) - result.size()
		if auto_count > 0:
			result.append_array(_generate_for_map(map_id, chain_idx, auto_count))
	_generated_cache[map_id] = result
	return result

# Авто-генерация N квестов для карты. Типы чередуются.
func _generate_for_map(map_id: String, chain_idx: int, count: int) -> Array:
	var result: Array = []
	var region_name: String = BookwarConst.get_map_name(map_id)
	# §I18N §2.0: pool in the CURRENT locale's letters; empty deep-map pools
	# fall back to the Light Valley starter pool of the same locale.
	var pool: Array = BookwarConst.get_map_letters_resolved(map_id)
	if pool.is_empty():
		pool = BookwarConst.get_map_letters_resolved(BookwarConst.MAP_LIGHT_VALLEY)
	# §I18N: NPC role names localized (npc.* keys)
	var npc_names: Array = [
		I18n.t("npc.wanderer", "Странник"),
		I18n.t("npc.sage", "Мудрец"),
		I18n.t("npc.elder", "Старейшина"),
		I18n.t("npc.hermit", "Отшельник"),
		I18n.t("npc.keeper", "Хранитель"),
	]
	for i: int in range(count):
		var qtype: String = QUEST_TYPES_CYCLE[i % QUEST_TYPES_CYCLE.size()]
		var quest_id: String = map_id + "_auto_" + str(i)
		var npc: String = String(npc_names[i % npc_names.size()])
		var give_letter: String = String(pool[randi() % pool.size()])
		var reward_letter: String = String(pool[randi() % pool.size()])
		var q: Dictionary = {
			"id": quest_id,
			"map_id": map_id,
			"npc_name": npc,
			"type": qtype,
			"auto": true,
		}
		match qtype:
			"defeat":
				q["description"] = I18n.t_fmt("quest.auto_defeat", [str(3 + (chain_idx / 3)), region_name], "Одолей %s врагов в регионе «%s».")
				q["requirement"] = {"count": 3 + (chain_idx / 3)}
				q["reward"] = {"type": "letter", "letter": reward_letter, "count": 1}
			"collect":
				q["description"] = I18n.t_fmt("quest.auto_collect", [str(2 + (i % 3)), give_letter, reward_letter], "Принеси %s букв «%s» — дам тебе «%s».")
				q["requirement"] = {"letter": give_letter, "count": 2 + (i % 3)}
				q["reward"] = {"type": "letter", "letter": reward_letter, "count": 1}
			"buy":
				var cost: int = 10 + chain_idx * 2
				q["description"] = I18n.t_fmt("quest.auto_buy", [reward_letter, str(cost)], "Купи букву «%s» за %s буквиц.")
				q["cost"] = {"resource": "dots", "amount": cost}
				q["reward"] = {"type": "letter", "letter": reward_letter, "count": 1}
			"trade":
				q["description"] = I18n.t_fmt("quest.auto_trade", [give_letter, reward_letter], "Обменяй «%s» на «%s».")
				q["give"] = {"letter": give_letter}
				q["receive"] = {"letter": reward_letter}
				q["reward"] = {"type": "letter", "letter": reward_letter, "count": 1}
			"talk":
				q["description"] = I18n.t_fmt("quest.auto_talk", [npc, region_name], "Поговори с %s в регионе «%s».")
				q["requirement"] = {"target_npc": npc}
				q["reward"] = {"type": "dots", "amount": 5 + chain_idx}
		result.append(q)
	return result

# Сколько квестов должно быть на карте (для UI прогресса).
func get_quest_count_for_map(map_id: String) -> int:
	return get_quests_for_map(map_id).size()

# Проверка выполнения квеста по его требованиям.
# Возвращает true если квест выполним прямо сейчас.
func can_complete(q: Dictionary) -> bool:
	var qtype: String = String(q.get("type", ""))
	match qtype:
		"defeat":
			# defeat tracking через GameState.quest_progress (как раньше)
			var target: int = int(q.get("requirement", {}).get("count", 1))
			return GameState.quest_progress_for(String(q.get("id", ""))) >= target
		"collect":
			var req: Dictionary = q.get("requirement", {})
			var letter: String = String(req.get("letter", ""))
			var count: int = int(req.get("count", 1))
			return InventoryManager.get_letter_level(letter) >= count
		"buy":
			var cost: int = int(q.get("cost", {}).get("amount", 9999))
			return InventoryManager.get_dots() >= cost
		"trade":
			var give_letter: String = String(q.get("give", {}).get("letter", ""))
			return InventoryManager.get_letter_level(give_letter) > 0
		"talk":
			# talk всегда выполним (просто поговорить)
			return true
	return false

# Выдать награду и пометить квест выполненным.
func complete_quest(q: Dictionary) -> void:
	var reward: Dictionary = q.get("reward", {})
	match String(reward.get("type", "")):
		"letter":
			InventoryManager.add_letter(String(reward.get("letter", "А")))
		"dots":
			InventoryManager.add_dots(int(reward.get("amount", 0)))
	GameState.mark_quest_completed(String(q.get("id", "")))
