#============================================================
#    Table Data Set
#============================================================
# - author: zhangxuetu
# - datetime: 2023-05-16 23:22:41
# - version: 4.0
#============================================================
## 专门存储管理表单的数据
class_name TableDataEditor_TableDataSet


enum {
	COLUMN,
	ROW,
}


var grid_data : Dictionary = {}
var _column_set : Dictionary = {}


func get_origin_data() -> Dictionary:
	return grid_data


func has_value(coords: Vector2i) -> bool:
	return (grid_data.has(coords[ROW]) 
		and grid_data[coords[ROW]].has(coords[COLUMN])
	)


func get_value(coords: Vector2i):
	if has_value(coords):
		var row : int = coords[ROW]
		var column : int = coords[COLUMN]
		return grid_data[row][column]
	return ""


func set_value(coords: Vector2i, value) -> void:
	var row : int = coords[ROW]
	var column : int = coords[COLUMN]
	
	if not grid_data.has(row):
		grid_data[row] = {}
	grid_data[row][column] = value
	
	if not _column_set.has(column):
		_column_set[column] = 0
	_column_set[column] += 1


func remove_value(coords: Vector2i) -> bool:
	if has_value(coords):
		var row : int = coords[ROW]
		var column : int = coords[COLUMN]
		grid_data[row].erase(column)
		grid_data[column] -= 1
		# 没有数据时，进行移除
		if Dictionary(grid_data[row]).is_empty():
			grid_data.erase(row)
		if grid_data[column] == 0:
			grid_data.erase(column)
		return true
	return false


func get_max_column() -> int:
	if _column_set.is_empty():
		return 0
	return _column_set.keys().max()

