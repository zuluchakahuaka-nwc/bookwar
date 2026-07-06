extends Node
# I18n — internationalization autoload.
# Loads one JSON file per locale from res://data/i18n/<locale>.json.
# UI calls I18n.t("menu.new_game") to get the translated string for the
# current locale. Locale choice persists (localStorage on web, user:// on native).
#
# Why a custom loader instead of Godot's CSV TranslationServer?
# CSV import is finicky in headless HTML5 export (the .translation resources
# must be pre-generated & registered). A plain JSON read is 100% reliable on
# web, needs no import step, and lets us grow coverage by editing JSON only.
#
# Fonts: RussoOne covers Latin+Cyrillic. Arabic & Chinese need Noto fallbacks.
# apply_theme_font() wires the right fallback chain per locale and toggles RTL.

signal locale_changed(locale: String)

const DEFAULT_LOCALE: String = "ru"
const FALLBACK_LOCALE: String = "en"
const SAVE_KEY: String = "bookwar_locale"
const I18N_DIR: String = "res://data/i18n/"

# Supported locales (BCP-47-ish codes). Order = menu order.
const LOCALES: Array = ["ru", "en", "zh", "es", "fr", "de", "pt", "ar"]

# Native self-names shown in the language selector (each in its own script).
const LOCALE_NATIVE_NAMES: Dictionary = {
	"ru": "Русский",
	"en": "English",
	"zh": "中文",
	"es": "Español",
	"fr": "Français",
	"de": "Deutsch",
	"pt": "Português",
	"ar": "العربية",
}

const RTL_LOCALES: Array = ["ar"]
const CJK_LOCALES: Array = ["zh"]

var _current_locale: String = DEFAULT_LOCALE
# key -> string, for the current locale.
var _strings: Dictionary = {}
# Fallback (English) strings, used when a key is missing in the current locale.
var _fallback_strings: Dictionary = {}

func _ready() -> void:
	_fallback_strings = _load_locale(FALLBACK_LOCALE)
	var saved: String = _load_saved_locale()
	if saved != "" and LOCALES.has(saved):
		_current_locale = saved
	else:
		_current_locale = _detect_locale()
	if not LOCALES.has(_current_locale):
		_current_locale = DEFAULT_LOCALE
	_strings = _load_locale(_current_locale)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLocale = '" + _current_locale + "';", true)
		JavaScriptBridge.eval(
			"window.gameSetLocale = function(loc){ window._godotSetLocale = loc; };",
			true)
	# Apply the font chain for the current script (must run after root exists).
	call_deferred("apply_theme_font")

# --- Public API ---

func t(key: String, fallback: String = "") -> String:
	# Returns the translated string for the current locale.
	# Falls back to English, then to `fallback`, then to the key itself.
	if _strings.has(key):
		return String(_strings[key])
	if _fallback_strings.has(key):
		return String(_fallback_strings[key])
	if fallback != "":
		return fallback
	return key

func t_fmt(key: String, args: Array, fallback: String = "") -> String:
	# Like t(), then substitutes %s placeholders (in order) with args.
	var template: String = t(key, fallback)
	# Godot has no vararg printf; replace %s sequentially.
	var out: String = ""
	var ai: int = 0
	var i: int = 0
	while i < template.length():
		if i + 1 < template.length() and template[i] == "%" and template[i + 1] == "s":
			if ai < args.size():
				out += str(args[ai])
				ai += 1
			else:
				out += "?"
			i += 2
		else:
			out += template[i]
			i += 1
	return out

func get_locale() -> String:
	return _current_locale

func get_locales() -> Array:
	return LOCALES

func get_native_name(locale: String) -> String:
	return String(LOCALE_NATIVE_NAMES.get(locale, locale))

func is_rtl() -> bool:
	return RTL_LOCALES.has(_current_locale)

func is_cjk() -> bool:
	return CJK_LOCALES.has(_current_locale)

func set_locale(locale: String) -> void:
	if not LOCALES.has(locale):
		return
	if locale == _current_locale:
		return
	_current_locale = locale
	_strings = _load_locale(locale)
	_save_locale(locale)
	apply_theme_font()
	locale_changed.emit(locale)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameLocale = '" + locale + "';", true)

# --- Font / theme ---

func apply_theme_font() -> void:
	# Build a font chain that covers the current script:
	#   Latin/Cyrillic locales -> RussoOne (+ Forum fallback for missing glyphs)
	#   zh                      -> RussoOne + NotoSansSC fallback
	#   ar                      -> RussoOne + NotoSansArabic fallback (+ RTL)
	var primary_path: String = "res://assets/fonts/RussoOne-Regular.ttf"
	var primary: FontFile = _load_font(primary_path)
	if primary == null:
		return
	var fallbacks: Array[Font] = []
	match _current_locale:
		"zh":
			var sc: FontFile = _load_font("res://assets/fonts/NotoSansSC-Regular.otf")
			if sc:
				fallbacks.append(sc)
			var forum: FontFile = _load_font("res://assets/fonts/Forum-Regular.ttf")
			if forum:
				fallbacks.append(forum)
		"ar":
			var ar: FontFile = _load_font("res://assets/fonts/NotoSansArabic-Regular.ttf")
			if ar:
				fallbacks.append(ar)
			var forum: FontFile = _load_font("res://assets/fonts/Forum-Regular.ttf")
			if forum:
				fallbacks.append(forum)
		_:
			var forum: FontFile = _load_font("res://assets/fonts/Forum-Regular.ttf")
			if forum:
				fallbacks.append(forum)
	primary.fallbacks = fallbacks
	var theme: Theme = Theme.new()
	theme.set_font("font", "Label", primary)
	theme.set_font("font", "Button", primary)
	theme.set_font("font", "LineEdit", primary)
	theme.set_font("font", "RichTextLabel", primary)
	theme.set_font("font", "CheckBox", primary)
	theme.set_font("font", "OptionButton", primary)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 18)
	get_tree().root.set("theme", theme)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameFontApplied = true; window.gameLocale = '" + _current_locale + "';", true)
		_expose_font_coverage(primary)

func _expose_font_coverage(primary: FontFile) -> void:
	# Deterministic glyph-coverage report (no Vision needed): for sample strings
	# in each script, report whether primary OR any fallback font has every glyph.
	# Proves Arabic/Chinese will actually render, not show as tofu boxes.
	var samples: Dictionary = {
		"latin": "BOOKWAR",
		"cyrillic": "Война за алфавит",
		"cjk": "字母之战新游戏",
		"arabic": "حرب الأبجدية"
	}
	var report: Dictionary = {}
	for name: String in samples.keys():
		var s: String = samples[name]
		var ok: bool = true
		for i: int in range(s.length()):
			var code: int = s.unicode_at(i)
			if primary.has_char(code):
				continue
			var found: bool = false
			for fb: Font in primary.fallbacks:
				if fb.has_char(code):
					found = true
					break
			if not found:
				ok = false
				break
		report[name] = ok
	var json_text: String = JSON.stringify(report)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameFontCoverage = " + json_text + ";", true)

# --- Internals ---

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var loc: String = str(JavaScriptBridge.eval("typeof window._godotSetLocale !== 'undefined' ? window._godotSetLocale : ''", true))
	if loc != "":
		JavaScriptBridge.eval("window._godotSetLocale = '';", true)
		set_locale(loc)

func _load_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as FontFile

func _load_locale(locale: String) -> Dictionary:
	var path: String = I18N_DIR + locale + ".json"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		if locale != DEFAULT_LOCALE:
			push_warning("I18n: missing locale file " + path)
		return {}
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("I18n: parse error in " + path + ": " + json.get_error_message())
		return {}
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return {}
	return data

func _detect_locale() -> String:
	# OS.get_locale() returns things like "ru_RU", "en_US", "zh_CN", "ar_SA".
	var loc: String = OS.get_locale().to_lower()
	var base: String = loc.split("_")[0]
	if LOCALES.has(base):
		return base
	return DEFAULT_LOCALE

func _load_saved_locale() -> String:
	if OS.has_feature("web"):
		var v: String = str(JavaScriptBridge.eval("(function(){ try { return localStorage.getItem('" + SAVE_KEY + "') || ''; } catch(e) { return ''; } }());", true))
		return v
	var f: FileAccess = FileAccess.open("user://locale.txt", FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text().strip_edges()
	f.close()
	return s

func _save_locale(locale: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){ try { localStorage.setItem('" + SAVE_KEY + "', '" + locale + "'); } catch(e) {} }());", true)
	else:
		var f: FileAccess = FileAccess.open("user://locale.txt", FileAccess.WRITE)
		if f:
			f.store_string(locale)
			f.close()
