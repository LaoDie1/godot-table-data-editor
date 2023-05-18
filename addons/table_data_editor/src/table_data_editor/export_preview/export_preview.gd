#============================================================
#    Export Preview
#============================================================
# - author: zhangxuetu
# - datetime: 2022-11-27 17:45:09
# - version: 4.0
#============================================================
#============================================================
#    Export Preview
#============================================================
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


@export var table_data_editor : TableDataEditor


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
## 将有值的行的数据进行保存
func get_data_by_row() -> Array:
	var result : Array = []
	var head_row_number : int = _head_line_box.value
	var data_set = table_data_editor.get_table_edit().get_data_set()
	var head_row_data : Dictionary = data_set.grid_data.get(head_row_number, {})
	head_row_number += 1
	for row in range(head_row_number, min(data_set.grid_data.size(), head_row_number + EXAMPLE_COUNT)):
		var data = {}
		var row_data = data_set.grid_data[row]
		for column in head_row_data:
			data[head_row_data[column]] = row_data.get(column, "")
		result.append(data)
	return result


func get_csv_data() -> Array[String]:
	var data_set = table_data_editor.get_table_edit().data_set as TableDataEditor_TableDataSet
	var max_column : int = data_set.get_max_column()
	if max_column == 0:
		return []
	
	var csv_list : Array[String] = []
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


func _update_by_row():
	var data_list = get_data_by_row()
	var examples = []
	for i in range(min(data_list.size(), EXAMPLE_COUNT)):
		examples.append(data_list[i])
	_text_box.text = JSON.stringify(data_list, "\t")


func _update_by_csv():
	var data_list = get_csv_data()
	var examples = []
	for i in range(min(data_list.size(), EXAMPLE_COUNT)):
		examples.append(data_list[i])
	_text_box.text = JSON.stringify(data_list, "\t")


# 更新文本框的内容
func update_text_box_content():
	_text_box.text = ""
	match button_group.get_pressed_button().name:
		"json":
			_update_by_row()
		"csv":
			_update_by_csv()


#============================================================
#  连接信号
#============================================================
func _on_head_line_box_value_changed(value: float) -> void:
	update_text_box_content()


func _on_export_pressed() -> void:
	_save_dialog.current_file = "new_file." + str(button_group.get_pressed_button().name)
	_save_dialog.popup_centered_ratio(0.5)
	
#	_save_dialog.popup_centered( Vector2i(600, 400) )


func _on_save_dialog_file_selected(path: String) -> void:
	var data
	match button_group.get_pressed_button().name:
		"csv":
			data = "\n".join(get_csv_data())
			TableDataUtil.Files.save_as_string( path, data )
		"json":
			data = get_data_by_row()
			TableDataUtil.Files.save_as_string( path, _data_format(data) )
	
	_save_dialog.current_path = path
	
	print(" >>> 保存json数据：", path)
	self.exported.emit(path, data)


func _on_cancel_pressed():
	get_parent().hide()
