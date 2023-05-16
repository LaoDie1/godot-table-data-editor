#============================================================
#    Export Preview
#============================================================
# - datetime: 2022-11-27 17:45:09
#============================================================
# 导出预览
@tool
class_name ExportPreview
extends MarginContainer


## 导出 json 数据
signal exported(path: String, json: String)


## 导出方式
enum ExportMode {
	# 正常导出
	NORMAL,
	
	# 以头部作为 key
	HEAD_AS_KEY,
	
	# 按一行一行导出 [ {}, {}, ... ]
	BY_ROW,
	
}

const EXAMPLE_COUNT = 3


@export var json_editor : TableDataEditor


var __init_node = InjectUtil.auto_inject(self, "_")
var _text_box : TextEdit
var _head_as_key_panel : Control
var _head_line_box : SpinBox
var _save_dialog : FileDialog 
var _compact : CheckBox
var _select_items : Control
var _selected_item_param : Control


## 指定的 head 列数对应的值内容。_head_map[列数] = 值内容
var _head_map : Dictionary = {}

var button_group : ButtonGroup 


#============================================================
#  SetGet
#============================================================
## 获取对应的行的每个有值的列 对应的值映射。row 从第 1 行开始
func get_head_map(row: int) -> Dictionary:
	var columns = json_editor.get_has_value_column_in_row(row)
	# 头部字符串映射
	var head_map = {}
	var grid_data = json_editor.get_grid_data()
	var coords : Vector2i = Vector2i()
	for column in columns:
		coords = Vector2i(column, row)
		if grid_data.has(coords):
			var value = grid_data[coords]
			head_map[column] = value
	return head_map


## 获取普通的数据的 JSON
func get_normal_format_data() -> Dictionary:
	var data = {}
	var grid_data = json_editor.get_grid_data()
	var coords : Vector2i
	for row in json_editor.get_has_value_rows():
		var columns = json_editor.get_has_value_column_in_row(row)
		for column in columns:
			coords = Vector2i(column, row)
			if grid_data.has(coords):
				data[coords] = grid_data[coords]
	return data


## 获取以头部作为 key 的 json
func get_head_key_data() -> Array[Dictionary]:
	# 获取 _head_line_box.value 行中有值的列
	var grid_data = json_editor.get_grid_data()
	var key
	var value
	var data_list : Array[Dictionary] = []
	var data : Dictionary
	var has_value_rows = json_editor.get_has_value_rows() as Array
	for i in (int(_head_line_box.value) + 1):
		has_value_rows.erase(i)
	for row in has_value_rows:
		data = {}
		for column in _head_map:
			key = _head_map[column]
			value = grid_data.get(Vector2i(column, row), "")
			data[key] = value
		data_list.append(data)
	return data_list


## 将有值的行的数据进行保存
func get_data_by_row() -> Array:
	var data_list = []
	var grid_data = json_editor.get_grid_data()
	var coords : Vector2i
	for row in json_editor.get_has_value_rows():
		var data = {}
		var columns = json_editor.get_has_value_column_in_row(row)
		for column in columns:
			coords = Vector2i(column, row)
			if grid_data.has(coords):
				data[coords] = grid_data[coords]
		data_list.append(data)
	return data_list


func get_csv_data() -> Array:
	var data_set = json_editor._table_edit._data_set as TableDataEditor_TableDataSet
	
	var max_column : int = data_set.get_max_column()
	if max_column == 0:
		return []
	
	var csv_list : Array = []
	for row in range(1, data_set.get_max_column() + 1):
		var line : Array = []
		for column in range(1, max_column + 1):
			line.append(data_set.get_value(Vector2i(column, row)))
		csv_list.append(",".join(line))
	
	return csv_list



#============================================================
#  内置
#============================================================
func _ready() -> void:
	button_group = _select_items.get_child(0).button_group as ButtonGroup
	button_group.pressed.connect(func(button):
		for child in _selected_item_param.get_children():
			child.visible = false
		match button.name:
			"json": _head_as_key_panel.visible = true
		
		update_text_box_content()
	)



#============================================================
#  自定义
#============================================================
func _data_format(data) -> String:
	return JSON.stringify(data, "" if _compact.button_pressed else "\t")


func _update_normal():
	var example = {}
	var data = get_normal_format_data()
	for i in data:
		example[i] = data[i]
		if example.size() == EXAMPLE_COUNT:
			break
	
	_text_box.text = JSON.stringify(example, "\t")


func _update_head_as_key():
	# 头部字符串映射
	_head_map = get_head_map( int(_head_line_box.value) )
	
	var example_list = []
	for i in get_head_key_data():
		example_list.append(i)
		if example_list.size() == EXAMPLE_COUNT:
			break
	
	_text_box.text = JSON.stringify(example_list, "\t")


func _update_by_row():
	var data_list = []
	for i in get_csv_data():
		data_list.append(i)
		if data_list.size() == EXAMPLE_COUNT:
			break
	
	_text_box.text = JSON.stringify(data_list, "\t")


# 更新文本框的内容
func update_text_box_content():
	_text_box.text = ""
	match button_group.get_pressed_button().name:
		"json":
			_update_head_as_key()
		"csv":
			_update_by_row()


#============================================================
#  连接信号
#============================================================
func _on_head_line_box_value_changed(value: float) -> void:
	update_text_box_content()


func _on_export_pressed() -> void:
	_save_dialog.popup_centered_ratio(0.5)
#	_save_dialog.popup_centered( Vector2i(600, 400) )


func _on_save_dialog_file_selected(path: String) -> void:
	var data
	match button_group.get_pressed_button().name:
		"csv":
			data =  get_csv_data()
		"json":
			data = get_head_key_data()
		_:
			data = {}
	
	TableEditUtil.save_as_string( path, _data_format(data) )
	_save_dialog.current_path = path
	
	print(" >>> 保存json数据：", path)
	self.exported.emit(path, data)


