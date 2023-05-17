#============================================================
#    Edit Grid Data Util
#============================================================
# - datetime: 2022-11-26 21:56:34
#============================================================
class_name TableEditUtil


#============================================================
#  自定义
#============================================================
static func read_data(path: String):
	if FileAccess.file_exists(path):
		var reader = FileAccess.open(path, FileAccess.READ)
		if reader:
			return reader.get_var()


static func save_data(path: String, data):
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	
	var writer = FileAccess.open(path, FileAccess.WRITE)
	if writer:
		writer.store_var(data)


static func save_as_string(path: String, text: String):
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var writer = FileAccess.open(path, FileAccess.WRITE)
	if writer:
		writer.store_string(text)


static func read_text(path: String) -> String:
	if FileAccess.file_exists(path):
		var reader = FileAccess.open(path, FileAccess.READ)
		if reader:
			return reader.get_as_text()
	return ""


## 获取编辑器接口
static func get_editor_interface() -> EditorInterface:
	if not Engine.is_editor_hint():
		return null
	const KEY = "TableEditUtil_get_editor_interface"
	if Engine.has_meta(KEY):
		return Engine.get_meta(KEY)
	else:
		var plugin = ClassDB.instantiate("EditorPlugin")
		Engine.set_meta(KEY, plugin.get_editor_interface())
		return plugin.get_editor_interface()


## 是否开启了插件
static func is_enabled() -> bool:
	if not Engine.is_editor_hint():
		return false
	if get_editor_interface() == null:
		return false
	return get_editor_interface().is_plugin_enabled("table_data_editor")


## 当前插件是否是打开的
static func is_main_node() -> bool:
	var node = get_editor_interface().get_editor_main_screen()
	for child in node.get_children():
		if child is Control and child.visible:
			# 显示的是当前插件的名称
			return child.name == 'table_data_editor'
	return false


