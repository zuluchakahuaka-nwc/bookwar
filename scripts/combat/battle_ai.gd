extends Node
class_name BattleAI

func choose_card(available_letters: Array[String], enemy_hp: int, player_hp: int) -> String:
	if available_letters.size() == 0:
		return "Я"
	if enemy_hp < 20:
		var vowels: Array[String] = []
		for letter: String in available_letters:
			var data: Dictionary = AlphabetData.get_letter(letter)
			if data.get("type", "") == "vowel":
				vowels.append(letter)
		if vowels.size() > 0:
			return vowels[randi() % vowels.size()]
	if player_hp < 30:
		var consonants: Array[String] = []
		for letter: String in available_letters:
			var data: Dictionary = AlphabetData.get_letter(letter)
			if data.get("type", "") == "consonant":
				consonants.append(letter)
		if consonants.size() > 0:
			return consonants[randi() % consonants.size()]
	return available_letters[randi() % available_letters.size()]
