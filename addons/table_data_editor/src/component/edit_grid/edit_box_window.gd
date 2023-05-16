#============================================================
#    Edit Box Window
#============================================================
# - author: zhangxuetu
# - datetime: 2023-03-19 11:48:30
# - version: 4.0
#============================================================
@tool
class_name EditPopupBox
extends Control


signal popup_hide(text: String)


@export
var text : String = "" :
	set(v):
		text = v
		if not is_inside_tree(): await ready
		if _edit_box.text != text:
			_edit_box.text = text
@export
var showed : bool = true:
	set(v):
		showed = v
		if not is_inside_tree(): await ready
		_edit_box.visible = showed
	get:
		if _edit_box:
			return _edit_box.visible
		return true
@export
var box_size: Vector2 :
	set(v):
		box_size = v
		if not is_inside_tree(): await ready
		_edit_box.size = box_size
	get:
		if _edit_box:
			return _edit_box.size
		return Vector2(0, 0)


@onready var _edit_box := %edit_box as TextEdit
@onready var _scale_rect := %scale_rect as Control


var _resize_pressed : bool = false
var _pressed_size : Vector2 = Vector2(0,0)
var _pressed_pos : Vector2 = Vector2(0,0)


#============================================================
#  SetGet
#============================================================
func get_edit_box() -> TextEdit:
	return _edit_box

func get_text() -> String:
	return _edit_box.text


#============================================================
#   内置
#============================================================
func _ready():
	_edit_box.visible = false
	_edit_box.position = Vector2(0,0)
	
	_scale_rect.gui_input.connect(func(event):
		if event is InputEventMouseMotion:
			if _resize_pressed:
				var diff_v = get_global_mouse_position() - _pressed_pos
				_edit_box.size = _pressed_size + diff_v
			
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_resize_pressed = event.pressed
				if _resize_pressed:
					_pressed_size = _edit_box.size
					_pressed_pos = get_global_mouse_position()
	)
	


#============================================================
#  自定义
#============================================================
func popup(rect: Rect2 = Rect2()):
	if _edit_box == null: await ready
	
	if rect.position != Vector2():
		_edit_box.global_position = rect.position
	if rect.size != Vector2():
		_edit_box.size = rect.size
	
	# 聚焦编辑
	_edit_box.visible = true
	_edit_box.set_caret_line( _edit_box.get_line_count() )
	_edit_box.set_caret_column( _edit_box.text.length() )
	self.showed = true
	
#	print("[ EditPopupBox ] 弹出窗口")
	
	# 取消焦点时隐藏
	var t = _edit_box.text
	_edit_box.grab_focus()
	_edit_box.focus_exited.connect(func(): 
		if t != _edit_box.text:
			self.popup_hide.emit(_edit_box.text)
		_edit_box.visible = false
#		print("[ EditPopupBox ] 弹窗隐藏")
	, Object.CONNECT_ONE_SHOT)

