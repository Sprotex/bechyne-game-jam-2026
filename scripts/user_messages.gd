extends Node
## Delivers game-generated messages into a folder the player can open in Explorer.

signal browser_access_checked(success: bool, detail: String)
signal browser_write_failed(file_name: String)

const USER_MESSAGES_FOLDER := "user_messages"

var _browser_access_callback: JavaScriptObject
var _browser_write_callback: JavaScriptObject


func _ready() -> void:
	if OS.has_feature("web"):
		_browser_access_callback = JavaScriptBridge.create_callback(_on_browser_access_checked)
		_browser_write_callback = JavaScriptBridge.create_callback(_on_browser_write_failed)
		JavaScriptBridge.get_interface("window").set("godotFolderAccessResult", _browser_access_callback)
		JavaScriptBridge.get_interface("window").set("godotFolderWriteFailed", _browser_write_callback)
		JavaScriptBridge.eval(_browser_bridge_script())


func request_browser_folder_access() -> void:
	if not OS.has_feature("web"):
		browser_access_checked.emit(false, "Folder access is only available in a web build.")
		return
	JavaScriptBridge.eval("window.godotRequestFolderAccess()")


func _on_browser_access_checked(args: Array) -> void:
	var success := bool(args[0]) if not args.is_empty() else false
	var detail := str(args[1]) if args.size() > 1 else "Folder access was not granted."
	browser_access_checked.emit(success, detail)


func _on_browser_write_failed(args: Array) -> void:
	var file_name := str(args[0]) if not args.is_empty() else "A message"
	browser_write_failed.emit(file_name)


func _browser_bridge_script() -> String:
	return """
	window.godotRequestFolderAccess = async () => {
	  if (!window.showDirectoryPicker) {
		window.godotFolderAccessResult(false, "This browser cannot grant folder access. You can continue with downloads.");
	    return;
	  }
	  try {
		const handle = await window.showDirectoryPicker({mode: "readwrite"});
		let permission = await handle.queryPermission({mode: "readwrite"});
		if (permission !== "granted") permission = await handle.requestPermission({mode: "readwrite"});
		if (permission !== "granted") throw new Error("Write permission was not granted.");
	    window.godotMessagesFolder = handle;
		const file = await handle.getFileHandle("Field Communications access test.txt", {create: true});
	    const writer = await file.createWritable();
		await writer.write("Folder access test. You can delete this file.");
	    await writer.close();
		window.godotFolderAccessResult(true, "Folder access granted. A test file was saved.");
	  } catch (error) {
		window.godotFolderAccessResult(false, error.name === "AbortError" ? "Folder selection was cancelled." : error.message);
	  }
	};
	window.godotSaveMessage = async (name, base64) => {
	  try {
	    if (window.godotMessagesFolder) {
	      const file = await window.godotMessagesFolder.getFileHandle(name, {create: true});
	      const writer = await file.createWritable();
	      const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
	      await writer.write(bytes);
	      await writer.close();
	    } else {
	      const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
		  const link = document.createElement("a");
	      link.href = URL.createObjectURL(new Blob([bytes]));
	      link.download = name;
	      link.click();
	      URL.revokeObjectURL(link.href);
	    }
	  } catch (error) {
	    window.godotFolderWriteFailed(name);
	  }
	};
	"""


func use_browser_downloads() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.godotMessagesFolder = null")


func get_user_messages_folder() -> String:
	return OS.get_user_data_dir().path_join(USER_MESSAGES_FOLDER)


func deliver_user_message_text(message: String, file_name: String = "") -> Error:
	var target_name := file_name.get_file()
	if target_name.is_empty():
		target_name = "message.txt"
	elif target_name.get_extension().is_empty():
		target_name += ".txt"
	return _write_user_message(target_name, message.to_utf8_buffer())


func deliver_user_message_file(source_path: String, file_name: String = "") -> Error:
	if not FileAccess.file_exists(source_path):
		return ERR_FILE_NOT_FOUND

	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()

	var content := source.get_buffer(source.get_length())
	source.close()

	var target_name := file_name.get_file()
	if target_name.is_empty():
		target_name = source_path.get_file()
	if target_name.is_empty():
		return ERR_INVALID_PARAMETER

	return _write_user_message(target_name, content)


func deliver_user_picture(image: Image, file_name: String = "picture.png") -> Error:
	if image == null or image.is_empty():
		return ERR_INVALID_PARAMETER
	return _write_user_message(file_name, image.save_png_to_buffer())


func deliver_user_audio(audio: AudioStreamWAV, file_name: String = "audio.wav") -> Error:
	if audio == null or audio.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
		return ERR_INVALID_PARAMETER

	var bit_depth := 8 if audio.format == AudioStreamWAV.FORMAT_8_BITS else 16
	var channels := 2 if audio.stereo else 1
	var bytes_per_sample := int(bit_depth / 8)
	var pcm := audio.data
	var wav := _make_wav_header(pcm.size(), audio.mix_rate, channels, bit_depth)
	wav.append_array(pcm)
	return _write_user_message(file_name, wav)


func open_user_messages_folder() -> Error:
	var folder_path := get_user_messages_folder()
	var directory_error := DirAccess.make_dir_recursive_absolute(folder_path)
	if directory_error != OK:
		return directory_error
	return OS.shell_show_in_file_manager(folder_path)


func _write_user_message(file_name: String, content: PackedByteArray) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(get_user_messages_folder())
	if directory_error != OK:
		return directory_error

	var target_path := _get_available_message_path(file_name)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_buffer(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if OS.has_feature("web"):
		var safe_name := target_path.get_file()
		var base64 := Marshalls.raw_to_base64(content)
		var script := "window.godotSaveMessage(%s, %s)" % [JSON.stringify(safe_name), JSON.stringify(base64)]
		JavaScriptBridge.eval(script)
	return write_error


func _get_available_message_path(file_name: String) -> String:
	var safe_name := file_name.get_file()
	var base_name := safe_name.get_basename()
	var extension := safe_name.get_extension()
	var candidate := safe_name
	var suffix := 2

	while FileAccess.file_exists("user://%s/%s" % [USER_MESSAGES_FOLDER, candidate]):
		var numbered_name := "%s_%d" % [base_name, suffix]
		candidate = numbered_name
		if not extension.is_empty():
			candidate += "." + extension
		suffix += 1

	return "user://%s/%s" % [USER_MESSAGES_FOLDER, candidate]


func _make_wav_header(data_size: int, sample_rate: int, channels: int, bit_depth: int) -> PackedByteArray:
	var bytes_per_sample := int(bit_depth / 8)
	var header := "RIFF".to_ascii_buffer()
	header.resize(44)
	header.encode_u32(4, 36 + data_size)
	var wave_format := "WAVEfmt ".to_ascii_buffer()
	for index in wave_format.size():
		header[8 + index] = wave_format[index]
	header.encode_u32(16, 16)
	header.encode_u16(20, 1)
	header.encode_u16(22, channels)
	header.encode_u32(24, sample_rate)
	header.encode_u32(28, sample_rate * channels * bytes_per_sample)
	header.encode_u16(32, channels * bytes_per_sample)
	header.encode_u16(34, bit_depth)
	var data_tag := "data".to_ascii_buffer()
	for index in data_tag.size():
		header[36 + index] = data_tag[index]
	header.encode_u32(40, data_size)
	return header
