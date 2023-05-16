#============================================================
#    Edit Grid
#============================================================
# - datetime: 2022-11-26 17:53:52
#============================================================
## 这里管理 Cell 单元格的数据内容
@tool
class_name EditGrid
extends MarginContainer


## 选中单元格
signal selected_cell(cell: InputCell)
## 取消选中单元格
signal deselected_cell(cell: InputCell)
## 双击单元格
signal double_click_cell(cell: InputCell)
## 单元格数据发生改变
signal cell_value_changed(cell: InputCell, coordinate: Vector2i, previous: String, value: String)
## 滚动条滚动
signal scroll_changed(coordinate: Vector2i)
## 行高发生改变
signal row_height_changed(value: int)
## 列宽发生改变
signal column_width_changed(value: int)


const UPDATE_CELL_LIST_TIME = 0.02


@onready 
var _table_container := %table_container as TableContainer
@onready 
var _edit_popup_box := %edit_box_window as EditPopupBox
@onready 
var _v_scroll_bar := %v_scroll_bar as VScrollBar
@onready 
var _h_scroll_bar := %h_scroll_bar as HScrollBar
@onready 
var _update_grid_data_timer := %update_grid_data_timer as Timer
@onready 
var _serial_number_container := %serial_number_container as SerialNumberContainer


var default_tile_size : Vector2i


# 表格中的数据
var _grid_data := {}
# 行对应的行高
var _row_to_height_map := {}
# 列对应的列宽
var _column_to_width_map := {}

# 是否允许发出取消选中 cell 的信号
var _enabled_emit_deselected_signal := true

# 原始坐标位置对应的单元格
var _origin_coordinate_to_cell_map := {}
# 单元格对应的原点坐标位置
var _cell_to_origin_coordinate_map := {}
# 当前选中的单元格
var _selected_cell : InputCell
# 上一次左上角的坐标位置 
var _latest_top_left := Vector2i()

# 正在按着 alt 键
var _pressing_alt := false
# 是否已经开始更新
var _updated : bool = false


#============================================================
#  SetGet
#============================================================
## 设置表格数据
func set_grid_data(data: Dictionary):
	_grid_data = data
	update_cell_list()
	scroll_to(Vector2i(0,0))

func get_grid_data() -> Dictionary:
	return _grid_data

## 获取当前滚动到的左上角位置
func get_scroll_top_left() -> Vector2i:
	return Vector2i( _h_scroll_bar.value, _v_scroll_bar.value ) 

## 获取滚动条最顶部 Y 的值
func get_scroll_top() -> int:
	return int(_v_scroll_bar.value)

## 获取滚动条最左边 X 的值
func get_scroll_left() -> int:
	return int(_h_scroll_bar.value)

## 获取这个 cell 的当前坐标位置
func get_cell_coordinate(cell: InputCell) -> Vector2i:
	return get_scroll_top_left() + _cell_to_origin_coordinate_map.get(cell, Vector2i(-1, -1))

## 获取这个坐标上的 cell
func get_cell(coordinate: Vector2i) -> InputCell:
	var origin_coordinate = coordinate - get_scroll_top_left()
	return _origin_coordinate_to_cell_map.get(origin_coordinate) as InputCell

## 获取这个行列坐标上的值
func get_value(coordinate: Vector2i) -> String:
	return _grid_data.get(coordinate, "")

## 获取列宽
func get_column_width(column: int, default_width: int = 0):
	return _column_to_width_map.get(column, default_width)

## 获取行高
func get_row_height(row: int, default_heigt : int = 0):
	return _row_to_height_map.get(row, default_heigt)

## 获取列宽数据，数据中的 key 为列值，对应列宽
func get_column_width_data() -> Dictionary:
	return _column_to_width_map

## 获取行高数据，数据中的 key 为行值，对应行宽
func get_row_height_data() -> Dictionary:
	return _row_to_height_map

## 获取编辑弹窗
func get_edit_dialog() -> EditPopupBox:
	return _edit_popup_box



#============================================================
#  内置
#============================================================
func _ready() -> void:
	if not (EditGridUtil.is_enabled()):
		return 
	
	# 滚动条
	_h_scroll_bar.scrolling.connect(func():
		_h_scroll_bar.max_value = _h_scroll_bar.value + 100
		update_cell_list()
	)
	_v_scroll_bar.scrolling.connect(func():
		_v_scroll_bar.max_value = _v_scroll_bar.value + 100
		update_cell_list()
	)
	
	# 编辑表格窗
	_edit_popup_box.popup_hide.connect(func(text):
		# 弹窗消失后才允许发送取消选中的信号
		_enabled_emit_deselected_signal = true
		# 更新选中的 cell
		if _selected_cell:
			_alter_cell_value( _selected_cell, text )
		print("[ EditGrid ] 文本发生改变")
	)
	
	# 必须要等空闲时间时调用，否则 _table_container 中的节点没有加载完成，则看不到节点的大小
	await get_tree().process_frame
	update_serial_num(Vector2i(0, 0))
	default_tile_size = _table_container.get_tile_size()
	
	# 切换窗口时取消 alt 
	while true:
		if get_window() == null:
			await Engine.get_main_loop().process_frame
		else:
			break
	_pressing_alt = false
	
	const KEY = "__EditGrid_window_focus_exited_callable"
	if Engine.get_main_loop().has_meta(KEY):
		var callable = Engine.get_main_loop().get_meta(KEY)
		for data in get_window().focus_exited.get_connections():
			var c = Callable(data["callable"])
			if not c.is_valid():
				get_window().focus_exited.disconnect(c)
	
	# 更新表格数据
	update_cell_list()


func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pressing_alt = false


func _unhandled_input(event):
	if event is InputEventKey:
		# 按下 alt 键
		if event.keycode == KEY_ALT:
#			if not _pressing_alt and event.is_pressed():
#				print("[ EditGrid ] 按下了 Alt 键")
			_pressing_alt = event.is_pressed()


#============================================================
#  自定义
#============================================================
## 修改单元格的数据
func _alter_cell_value(cell: InputCell, value: String):
	if _selected_cell:
		_selected_cell.set_value( value )
		var coordinate = get_cell_coordinate(cell)
		alter_value(coordinate, value)


## 修改单元格数据
##[br]
##[br][code]coordinate[/code]  修改的坐标位置
##[br][code]value[/code]  修改的值
##[br][code]emit_signal_state[/code]  是否发送信号
func alter_value(
	coordinate: Vector2i, 
	value: String, 
	emit_signal_state: bool = true
) -> void:
	var previous = _grid_data.get(coordinate, "")
	if value != "":
		if previous != value:
			_grid_data[coordinate] = value
			if emit_signal_state:
				var cell = get_cell(coordinate)
				self.cell_value_changed.emit(cell, coordinate, previous, value )
	else:
		if _grid_data.has(coordinate):
			_grid_data.erase(coordinate)
			if emit_signal_state:
				var cell = get_cell(coordinate)
				self.cell_value_changed.emit(cell, coordinate, previous, "")


# 真正实际执行的更新
func force_update_cell_list():
	# 更新数据
	var coordinate
	for cell in _cell_to_origin_coordinate_map:
		coordinate = get_cell_coordinate(cell)
		cell.show_value(_grid_data.get(coordinate))
	
	# 更新单元格的宽高
	var top_left = get_scroll_top_left()
	var grid_row_column_size = _table_container.get_grid_row_column_count_size()
	for column in range(top_left.x, top_left.x + grid_row_column_size.x):
		_alter_column_width(column, get_column_width(column, 0) )
	for row in range(top_left.y, top_left.y + grid_row_column_size.y):
		_alter_row_height(row, get_row_height(row, 0) )
	
	if _latest_top_left != top_left:
		_latest_top_left = top_left
		self.scroll_changed.emit( _latest_top_left )
		_edit_popup_box.showed = false
		_edit_popup_box.get_edit_box().visible = false


## 更新单元格信息（使用计时器缓冲更新，防止同一时间多次重复调用）
func update_cell_list():
	if _updated:
		return
	_updated = true
	await Engine.get_main_loop().process_frame
	_updated = false
	force_update_cell_list()


##  更新行列序号的值
##[br]
##[br][code]column_row_left_top[/code]  左上角行列值
func update_serial_num(column_row_left_top: Vector2i):
	_serial_number_container.update_column_width(column_row_left_top.x, default_tile_size.x)
	_serial_number_container.update_row_height(column_row_left_top.y, default_tile_size.y)


## 修改列宽
##[br]
##[br][code]column[/code]  所在的列，从 1 开始
##[br][code]width[/code]  设置的列宽
func alter_column_width(column: int, width: int):
	_column_to_width_map[column] = width
	_alter_column_width(column, width)


# 真正进行修改单元格宽度，但数据不会缓存到数据中
func _alter_column_width(column: int, width: int):
	width = max(width, default_tile_size.x)
	for cell in _table_container.get_column_cells( column - get_scroll_left() ):
		cell.custom_minimum_size.x = width
	_serial_number_container.update_column_width(column - get_scroll_left(), width)


## 修改行高
##[br]
##[br][code]row[/code]  所在的行，从 1 开始
##[br][code]height[/code]  设置的行高
func alter_row_height(row: int, height: int):
	_row_to_height_map[row] = height
	_alter_row_height(row, height)


# 真正进行修改行高，但数据不会缓存到数据中
func _alter_row_height(row: int, height: int):
	height = max(height, default_tile_size.y)
	for cell in _table_container.get_row_cells(row - get_scroll_top()):
		cell.custom_minimum_size.y = height
	_serial_number_container.update_row_height(row - get_scroll_top(), height)


## 滚动到指定位置
func scroll_to(pos: Vector2i):
	_h_scroll_bar.value = pos.x
	_v_scroll_bar.value = pos.y
	_h_scroll_bar.scrolling.emit()
	_v_scroll_bar.scrolling.emit()



#============================================================
#  连接信号
#============================================================
# 添加新的单元格时
func _newly_added_cell(coordinate: Vector2i, new_cell: InputCell):
	# 滑轮滚动
	new_cell.gui_input.connect(func(event):
		# 单元格 Input
		if event is InputEventMouseButton and event.is_pressed():
			var scroll_bar : ScrollBar
			if _pressing_alt:
				scroll_bar = _h_scroll_bar
			else:
				scroll_bar = _v_scroll_bar
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_bar.value += scroll_bar.step
				scroll_bar.scrolling.emit()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_bar.value -= scroll_bar.step
				scroll_bar.scrolling.emit()
	)
	
	# 单元格行列坐标映射
	_cell_to_origin_coordinate_map[new_cell] = coordinate
	_origin_coordinate_to_cell_map[coordinate] = new_cell
	
	if _edit_popup_box:
		update_cell_list()
	
	# 选中单元格
	new_cell.focus_entered.connect(func():
		_selected_cell = new_cell
		if _edit_popup_box.showed:
			_edit_popup_box.showed = false
			if _selected_cell:
				# 取消上次选中的单元格
				self.deselected_cell.emit(_selected_cell)
				_selected_cell = null
		
		# 当前 cell
		self.selected_cell.emit(new_cell) 
		_edit_popup_box.showed = false
	)
	
	# 取消选中单元格
	new_cell.focus_exited.connect(func(): 
		if _enabled_emit_deselected_signal:
			_selected_cell = null
			self.deselected_cell.emit(new_cell)
	)
	
	# 双击编辑
	new_cell.double_click.connect(func(): 
		self.double_click_cell.emit(new_cell)
		_enabled_emit_deselected_signal = false
		
		# 设置选中的 cell
		_selected_cell = new_cell
		# 弹窗编辑
		var cell_coordinate = get_cell_coordinate(new_cell) # 这个表格的位置
		_edit_popup_box.text = get_value(cell_coordinate)
		_edit_popup_box.popup(Rect2(new_cell.global_position, Vector2(0,0)))
		
	)
	
	# 水平拖拽移动
	new_cell.h_dragged.connect(func(distance: float, pressed_node_size: Vector2i):
		# 表格当前坐标位置
		var current_coordinate = get_cell_coordinate(new_cell)
		var width = pressed_node_size.x + int(distance) 
		alter_column_width(current_coordinate.x, width)
		
		# 记录改变的列宽
		_column_to_width_map[current_coordinate.x] = width
		self.column_width_changed.emit(width)
	)
	
	# 垂直拖拽移动
	new_cell.v_dragged.connect(func(distance: float, pressed_node_size: Vector2i):
		
		# 表格当前坐标位置
		var current_coordinate = get_cell_coordinate(new_cell)
		var height = pressed_node_size.y + int(distance)
		alter_row_height(current_coordinate.y, height)
		
		# 记录改变的行高
		_row_to_height_map[current_coordinate.y] = height
		self.row_height_changed.emit(height)
		
	)

