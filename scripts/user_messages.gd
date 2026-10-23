extends Node
## Delivers game-generated messages into a folder the player can open in Explorer.

const USER_MESSAGES_FOLDER := "user_messages"


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


func deliver_user_picture(source_path: String, file_name: String = "") -> Error:
	return deliver_user_message_file(source_path, file_name)


func deliver_user_audio(source_path: String, file_name: String = "") -> Error:
	return deliver_user_message_file(source_path, file_name)


func open_user_messages_folder() -> Error:
	var folder_path := get_user_messages_folder()
	var directory_error := DirAccess.make_dir_recursive_absolute(folder_path)
	if directory_error != OK:
		return directory_error
	return OS.shell_show_in_file_manager(folder_path)


func _write_user_message(file_name: String, content: PackedByteArray) -> Error:
	var directory_error := DirAccess.make_dir_recursive("user://" + USER_MESSAGES_FOLDER)
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
