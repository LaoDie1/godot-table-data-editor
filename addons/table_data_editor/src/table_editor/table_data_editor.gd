#============================================================
#    Json Editor
#============================================================
# - datetime: 2022-11-27 01:31:14
#============================================================
## JSON 数据编辑器
@tool
class_name TableDataEditor
extends MarginContainer


## 文件扩展名
const CUSTOM_EXTENSION = "gdata"
## 上次编辑的数据内容
const CACHE_DATA_PATH = "res://.godot/json_editor/~json_edit_grid_cache_data.gdata"
## 上次操作的路径
const LAST_PATH_DATA = "res://.godot/json_editor/path_data.json"


## 修改时文件保存状态的颜色
const NOT_SAVED_COLOR = Color(1, 0.65, 0.275, 1)
const SAVED_COLOR = Color(1, 1, 1, 0.625)
## 最近打开的文件显示最大数量
const RECENTLY_SHOW_MAX_NUMBER = 10


## 文件弹窗文件过滤
const FILTERS = ["*.gdata; GData"]
## 菜单项数据
const MENU_ITEM : Dictionary = {
	"File": [
		"New", "Open", {"Recently Opened": ["/"]}, "-", 
		"Save", "Save As...", "-", 
		{"Export": ["JSON..."],},
	],
	"Edit": ["Undo", "Redo"],
	"Help": ["Operate"],
}
## 菜单快捷键
const MENU_SHORTCUT : Dictionary = {
	"/File/New": { "keycode": KEY_N, "ctrl": true },
	"/File/Open": { "keycode": KEY_O, "ctrl": true },
	"/File/Save": { "keycode": KEY_S, "ctrl": true },
	"/File/Save As...": { "keycode": KEY_S, "ctrl": true, "shift": true },
	"/Edit/Undo": {"keycode": KEY_Z, "ctrl": true},
	"/Edit/Redo": {"keycode": KEY_Z, "ctrl": true, "shift": true},
}


## 创建了新文件
signal created_file(path)
signal saved_file(path)


# 保存到的文件路径
var _saved_path : String = "" :
	set(v):
		_saved_path = v
		file_path_label.text = _saved_path
# 是否已保存
var _saved: bool = true:
	set(v):
		_saved = v
		if _saved_status_label == null:
			await ready
		if _saved:
			_saved_status_label.text = "(saved)"
			_saved_status_label.self_modulate = SAVED_COLOR
		else:
			_saved_status_label.text = "(unsaved)"
			_saved_status_label.self_modulate = NOT_SAVED_COLOR

# 行映射。记录哪些行有数据
var _has_value_row_map := {}
# 列映射。记录哪些列有数据
var _has_value_column_map := {}
# 撤销重做
var _undo_redo : UndoRedo = UndoRedo.new()

# 上次打开的文件路径
var _dialog_path : String = ""
# 不久前打开过的文件
var _recently_opend_path: Array = []
# 是否已加载完成
var _is_reloaded := false :
	set(v):
		if _is_reloaded == false:
			_is_reloaded = v


var __init_node = InjectUtil.auto_inject(self, "_")

# 编辑表格节点
var _table_edit : TableEdit
# 菜单列表
var _menu_list : MenuList
# 滚动条位置输入框
var _scroll_pos : LineEdit
# 切换页面（暂未完成）
var _pages : ItemList

var _export_preview_window : Window
var _save_as_dialog : FileDialog

var _open_file_dialog : FileDialog
var _confirm_dialog : ConfirmationDialog
var _tooltip_dialog : AcceptDialog

var _export_preview : ExportPreview

var _saved_status_label : Label
var file_path_label : Label



#============================================================
#  SetGet
#============================================================
## 获取项目数据
func get_project_data() -> TableDataEditor_JsonData:
	var json_data = TableDataEditor_JsonData.new()
	json_data.version = 1.2
	json_data.grid_data = _table_edit.get_grid_data()
	json_data.column_width = _table_edit.get_column_width_data()
	json_data.row_height = _table_edit.get_row_height_data()
	json_data.edit_dialog_size = _table_edit.get_edit_dialog().box_size
	return json_data

## 获取表格数据
func get_grid_data() -> Dictionary:
	return _table_edit.get_grid_data()

## 获取编辑表格对象
func get_edit_grid() -> TableEdit:
	return _table_edit

## 获取这一行有值的行。column 从 1 开始
func get_has_value_row_in_column(column: int) -> Array[int]:
	return Array(_has_value_column_map.get(column, {}).keys(), TYPE_INT, "", null)

## 获取这一列有值的列。row 从 1 开始
func get_has_value_column_in_row(row: int) -> Array[int]:
	return Array(_has_value_row_map.get(row, {}).keys(), TYPE_INT, "", null)

## 这一列是否有值
func column_has_value(column: int) -> bool:
	return _has_value_column_map.has(column)

## 这一行是否有值
func row_has_value(row: int) -> bool:
	return _has_value_row_map.has(row)

## 获取所有含有值的列
func get_has_value_columns() -> Array:
	return _has_value_column_map.keys()

## 获取所有含有值的行
func get_has_value_rows() -> Array:
	return _has_value_row_map.keys()


#============================================================
#  内置
#============================================================
func _ready() -> void:
	_saved_path = ""
	
	_init_dialog()
	_init_menu()
	
	_load_last_data()
	
	_is_reloaded = true


func _exit_tree():
	_update_path_data()



#============================================================
#  私有方法
#============================================================
# 新建文件
func _new_file() -> void:
	load_data({})
	_saved_path = ""


# 初始化菜单列表
func _init_menu():
	# TODO: 最近打开的文件替换增加数据
	_menu_list.init_menu(MENU_ITEM)
	# 设置快捷键
	_menu_list.init_shortcut(MENU_SHORTCUT)
	
	_menu_list.set_menu_disabled("/Edit/Undo", true)
	_menu_list.set_menu_disabled("/Edit/Redo", true)


# 初始化弹窗
func _init_dialog():
	
	# 数据导出预览
	_export_preview_window.close_requested.connect( func(): _export_preview_window.visible = false )
	_export_preview.json_editor = self
	
	# 添加文件类型var FILTERS = ["*.gdata; GData"]
	_open_file_dialog.filters = FILTERS
	_save_as_dialog.filters = FILTERS
	
	# 打开窗口的路径位置
	var callable = func(dialog: FileDialog):
		if dialog.current_dir != _dialog_path:
			_dialog_path = dialog.current_dir
			_update_path_data()
	_open_file_dialog.visibility_changed.connect(callable.bind(_open_file_dialog))
	_save_as_dialog.visibility_changed.connect(callable.bind(_save_as_dialog))
	


# 加载上次缓存的数据
func _load_last_data():
	if FileAccess.file_exists(LAST_PATH_DATA):
		var json = FileUtil.read_as_text(LAST_PATH_DATA, true)
		var path_data = JsonUtil.json_to_object(json, TableDataEditor_PathData) as TableDataEditor_PathData
		
		# 上次关闭时正在打开的文件
		if FileAccess.file_exists(path_data.last_open_file):
			load_grid_data_by_path(path_data.last_open_file)
		
		# 窗口路径
		if DirAccess.dir_exists_absolute(path_data.dialog_path):
			_dialog_path = path_data.dialog_path
			_open_file_dialog.current_dir = path_data.dialog_path
			_open_file_dialog.current_file = path_data.dialog_path
			_save_as_dialog.current_dir = path_data.dialog_path
			_save_as_dialog.current_file = path_data.dialog_path
		
		# 最近打开的文件
		if path_data.recently_opend_path:
			const RECENTLY_OPEND_MENU = "/File/Recently Opened"
			_menu_list.remove_menu(RECENTLY_OPEND_MENU + "//") # 移除默认的 “/” 名称菜单
			# 添加打开过的路径
			_recently_opend_path = path_data.recently_opend_path
			if _recently_opend_path.size() > RECENTLY_SHOW_MAX_NUMBER:
				_recently_opend_path = _recently_opend_path.slice(_recently_opend_path.size() - RECENTLY_SHOW_MAX_NUMBER)
			for path in _recently_opend_path:
				_menu_list.add_menu(path, RECENTLY_OPEND_MENU)


# 更新路径信息
func _update_path_data():
	if TableEditUtil.is_enabled() and _is_reloaded:
		var data = TableDataEditor_PathData.new()
		data.last_open_file = _saved_path
		data.dialog_path = _dialog_path
		data.recently_opend_path = _recently_opend_path
		FileUtil.write_as_text(LAST_PATH_DATA, JsonUtil.object_to_json(data) )



#============================================================
#  自定义
#============================================================
##  加载路径的数据
##[br]
##[br][code]path[/code]  加载这个路径的数据
func load_grid_data_by_path(path: String):
	if not FileAccess.file_exists(path):
		push_error("<", path, "> 文件不存在")
		return
	
	print("[ TableDataEditor ] 加载数据：", path)
	var data = TableEditUtil.read_data(path)
	load_data(data)
	
	_saved_path = path
	if not _recently_opend_path.has(path):
		_recently_opend_path.push_back(path)
		_update_path_data()


## 加载数据
func load_data(data: Dictionary):
	var json_data := JsonUtil.dict_to_object(data, TableDataEditor_JsonData) as TableDataEditor_JsonData
	
	# 设置数据
	_table_edit._column_to_width_map = json_data.column_width as Dictionary
	_table_edit._row_to_height_map = json_data.row_height as Dictionary
	# 加载数据到表格中
	_table_edit.set_grid_data( json_data.grid_data )
	_table_edit.update_cell_list()
	if json_data.edit_dialog_size:
		_table_edit.get_edit_dialog().box_size = json_data.edit_dialog_size
	
	# 记录存在有值的行和列
	for coord in _table_edit.get_grid_data():
		if not _has_value_row_map.has(coord.y):
			_has_value_row_map[coord.y] = {}
		_has_value_row_map[coord.y][coord.x] = null
		if not _has_value_column_map.has(coord.x):
			_has_value_column_map[coord.x] = {}
		_has_value_column_map[coord.x][coord.y] = null
	
	_saved = true
	_undo_redo.clear_history()


## 保存数据到这个路径中
func save_data_to(path: String):
	var has = FileAccess.file_exists(path)
	
	# 保存这次缓存数据
	var data = JsonUtil.object_to_json(get_project_data())
	TableEditUtil.save_data(path, data)
	print("[ TableDataEditor ] 已保存 TableDataEditor 数据")
	print("[ TableDataEditor ] 保存到路径：", path)
	
	self._update_path_data()
	self._saved = true
	self._saved_path = path
	if has:
		self.saved_file.emit(path)
	else:
		self.created_file.emit(path)


## 保存为 JSON
func save_as_json(path: String):
	var has = FileAccess.file_exists(path)
	
	var data = get_grid_data()
	TableEditUtil.save_as_string( path, JSON.stringify(data) )
	print("[ TableDataEditor ] 已保存 TableDataEditor 数据")
	print("[ TableDataEditor ] 保存到路径：", path)
	
	self._saved = true
	if has:
		self.saved_file.emit(path)
	else:
		self.created_file.emit(path)


## 显示保存 Dialog
func show_save_dialog(default_file_name: String = ""):
	if default_file_name != "":
		_save_as_dialog.current_file = default_file_name
#	_save_as_dialog.popup_centered(Vector2i(600, 400))
	_save_as_dialog.popup_centered_ratio(0.5)


#============================================================
#  连接信号
#============================================================
func _on_table_edit_cell_value_changed(cell: InputCell, coordinate: Vector2i, previous: String, value: String):
	_saved = false
	
#	print("[ TableDataEditor ] 单元格发生改变")
	
	# 记录存在有数据的行列
	_undo_redo.create_action("修改单元格的值")
	_undo_redo.add_do_method( _table_edit.alter_value.bind(coordinate, value, false) )
	_undo_redo.add_do_method( _table_edit.update_cell_list )
	_undo_redo.add_undo_method( _table_edit.alter_value.bind(coordinate, previous, false) )
	_undo_redo.add_undo_method( _table_edit.update_cell_list )
	_undo_redo.commit_action()
	
	# 撤销可用性
	_menu_list.set_menu_disabled("/Edit/Undo", false)


func _on_table_edit_scroll_changed(coordinate: Vector2i):
	_scroll_pos.text = str(coordinate)


func _on_scroll_pos_text_submitted(new_text):
	var pos = str_to_var("Vector2i" + new_text)
	if pos is Vector2i:
		_table_edit.scroll_to(pos)
		print("[ TableDataEditor ] 跳转到位置：", pos)


func _on_menu_list_menu_pressed(idx, menu_path: String):
	print_debug("[ TableDataEditor ] 点击菜单 ", menu_path)
	
	match menu_path:
		"/File/New":
			if not _saved:
				_confirm_dialog.dialog_text = "当前还没有保存，是否要继续创建？"
				_confirm_dialog.popup_centered()
			else:
				_new_file()
		
		"/File/Open":
			_open_file_dialog.popup_centered_ratio(0.5)
		
		"/File/Save":
			if _saved_path == "":
				show_save_dialog()
			else:
				save_data_to(_saved_path)
		
		"/File/Save As...":
			show_save_dialog("new_file." + CUSTOM_EXTENSION)
		
		"/Edit/Undo":
			_undo_redo.undo()
			_menu_list.set_menu_disabled("/Edit/Undo", not _undo_redo.has_undo())
			_menu_list.set_menu_disabled("/Edit/Redo", false)
		
		"/Edit/Redo":
			_undo_redo.redo()
			_menu_list.set_menu_disabled("/Edit/Redo", not _undo_redo.has_redo())
			_menu_list.set_menu_disabled("/Edit/Undo", false)
		
		"/Export/JSON...":
#			show_save_dialog("new_file.json")
			_export_preview_window.popup_centered_ratio(0.5)
			_export_preview.update_example_content()
		
		"/Help/Operate":
			_tooltip_dialog.popup_centered()
		
		_:
			if menu_path.contains("/File/Recently Opened"):
				var file_path = menu_path.trim_prefix("/File/Recently Opened/")
				if FileAccess.file_exists(file_path):
					load_grid_data_by_path(file_path)


func _on_save_as_dialog_file_selected(path):
	_saved_path = path
	match _saved_path.get_extension():
		CUSTOM_EXTENSION:
			save_data_to( _saved_path )
		"json":
			save_as_json( _saved_path )
		_:
			printerr("[ TableDataEditor ] <未知的文件扩展名> ", _saved_path.get_extension())


func _on_export_preview_exported(path, data) -> void:
	_export_preview_window.visible = false
	self.created_file.emit(path)


func _on_open_file_dialog_file_selected(path):
	load_grid_data_by_path(path)

