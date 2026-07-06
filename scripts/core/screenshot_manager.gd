extends Node
class_name ScreenshotManager

var _screenshot_dir: String = "user://screenshots/"
var _capture_on_demand: bool = false
var _auto_capture_interval: float = 5.0
var _timer: float = 0.0
var _is_recording: bool = false
var _frame_count: int = 0

signal screenshot_taken(path: String)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_screenshot_dir)

func _process(delta: float) -> void:
	if _is_recording:
		_timer += delta
		if _timer >= _auto_capture_interval:
			_timer = 0.0
			take_screenshot("auto_" + str(_frame_count))
			_frame_count += 1

func take_screenshot(name: String = "") -> String:
	if name == "":
		name = "screenshot_" + str(Time.get_ticks_msec())
	var filepath: String = _screenshot_dir + name + ".png"
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(filepath)
	screenshot_taken.emit(filepath)
	if OS.has_feature("web"):
		_push_screenshot_to_js(image, name)
	return filepath

func _push_screenshot_to_js(image: Image, name: String) -> void:
	var buffer: PackedByteArray = image.save_png_to_buffer()
	var base64: String = Marshalls.raw_to_base64(buffer)
	JavaScriptBridge.eval("window.lastScreenshot = {name: '" + name + "', data: 'data:image/png;base64," + base64 + "', time: Date.now()};")

func start_recording(interval: float = 2.0) -> void:
	_is_recording = true
	_auto_capture_interval = interval
	_frame_count = 0
	_timer = 0.0

func stop_recording() -> void:
	_is_recording = false

func get_last_screenshot_base64() -> String:
	var image: Image = get_viewport().get_texture().get_image()
	var buffer: PackedByteArray = image.save_png_to_buffer()
	return Marshalls.raw_to_base64(buffer)
