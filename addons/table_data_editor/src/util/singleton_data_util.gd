#============================================================
#    Single Data Util
#============================================================
# - author: zhangxuetu
# - datetime: 2023-05-17 12:34:33
# - version: 4.0
#============================================================
class_name SingletonDataUtil


const SINGLETON_DATA = "TableDataEditor_SingleData"
const LISTENE_OPEN_FILE_DATA = "TableDataEditor_listene_open_file_data"


#============================================================
#  功能
#============================================================

static func get_value_or_set(dict: Dictionary, key, callback: Callable = Callable()):
	if not dict.has(key) and callback.is_valid():
		dict[key] = callback.call()
	return dict.get(key)


## 读取字节数据
static func read_as_bytes(file_path: String):
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			return file.get_file_as_bytes(file_path)
	return null


## 读取字节数据，并转为原来的数据
static func read_as_bytes_to_var(file_path: String):
	var bytes = read_as_bytes(file_path)
	if bytes:
		return bytes_to_var_with_objects(bytes)
	return null


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


#============================================================
#  处理全局数据
#============================================================
static func singleton_data() -> Dictionary:
	if not Engine.has_meta(SINGLETON_DATA):
		Engine.set_meta(SINGLETON_DATA, {})
	return Engine.get_meta(SINGLETON_DATA)


static func register(object: Object, callback: Callable) -> bool:
	var script : Script = (object if object is Script else object.get_script())
	var data = singleton_data()
	data[script] = callback.call()
	return true


static func get_data(object: Object):
	var script : Script = (object if object is Script else object.get_script())
	return singleton_data().get(script)


static func update_data(object: Object, data):
	register(object, func(): return data)

static func listene_load_data(callback: Callable):
	var list = get_value_or_set(singleton_data(), LISTENE_OPEN_FILE_DATA, func(): return [])
	list.append(callback)

static func emit_load_data_signal(data = null):
	if data == null:
		data = get_data(TableDataEditor)
	var list = get_value_or_set(singleton_data(), LISTENE_OPEN_FILE_DATA, func(): return [])
	for callable in list:
		callable.call(data)

static func open_file(path: String):
	var data = read_as_bytes_to_var(path)
	if data == null:
		data = {}
	
	update_data(TableDataEditor, data)
	emit_load_data_signal()


