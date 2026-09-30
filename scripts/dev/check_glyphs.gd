# Headless glyph-coverage check: run before introducing ANY new special symbol
# in player-facing strings. A glyph must be present in RussoOne or Forum
# (covers ru/en/eu locales), plus the locale-specific Noto fonts. Keep the
# sanctioned set in sync with i18n.gd's "symbols" coverage sample:
#   sanctioned:  ‹ › « » … — – • × † ·
#   forbidden (no coverage, replaced 2026-09-30):
#     ← → ⟶ ★ ✓ ✕ 📜 📦 🛒 🛡 💀 💬
extends SceneTree

const FONTS := [
	"res://assets/fonts/RussoOne-Regular.ttf",
	"res://assets/fonts/Forum-Regular.ttf",
	"res://assets/fonts/NotoSansArmenian-Regular.ttf",
	"res://assets/fonts/NotoSansArabic-Regular.ttf",
	"res://assets/fonts/NotoSansSC-Regular.otf",
]

const SYMBOLS := "‹›«»…—–•×†·←→⟶⟵★✓✕📜📦🛒🛡💀💬"

func _init() -> void:
	var names := ["RussoOne", "Forum", "NotoArm", "NotoArab", "NotoSC"]
	print("SYMBOL\t" + "\t".join(names))
	for i: int in range(SYMBOLS.length()):
		var cp: int = SYMBOLS.unicode_at(i)
		var ch: String = SYMBOLS[i]
		var row: String = "%04X %s" % [cp, ch]
		for fp: String in FONTS:
			var f: FontFile = load(fp) as FontFile
			if f == null:
				row += "\tERR"
			else:
				row += "\t" + ("Y" if f.has_char(cp) else ".")
		print(row)
	quit(0)
