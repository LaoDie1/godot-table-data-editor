#============================================================
#    Plugin
#============================================================
# - datetime: 2022-11-27 22:27:12
#============================================================
@tool
extends EditorPlugin


const MAIN = preload("src/json_editor/json_editor.tscn")

var main := MAIN.instantiate() as TableDataEditor
# 第一次显示出来
var first_show := false


func _enter_tree():
	main.visible = false
	get_editor_interface().get_editor_main_screen().add_child(main)
	main.call_deferred("set_anchors_preset", Control.PRESET_FULL_RECT)
	main.set_deferred("size", main.get_parent().size)
	main.get_child(0).set_deferred("size", main.size)
	main.created_file.connect(func(path):
		get_editor_interface() \
			.get_resource_filesystem() \
			.call_deferred("scan")
	)


func _exit_tree() -> void:
	main.queue_free()

func _has_main_screen():
	return true

func _make_visible(visible):
	main.visible = visible

func _get_plugin_name():
	return "TableDataEditor"

func _get_plugin_icon():
	var icon = get_editor_interface() \
		.get_base_control() \
		.get_theme_icon("GridContainer", "EditorIcons") as Texture2D
	
	icon = icon.duplicate(true)
	var image = icon.get_image() as Image
	var image_size = image.get_size()
	var color : Color
	for x in image_size.x:
		for y in image_size.y:
			color = image.get_pixel(x, y)
			if color.a != 0:
				color.r = 0.8
				color.g = 1
				color.b = 0.8
				image.set_pixel(x, y, color)
	var texture = ImageTexture.create_from_image(image)
	return texture
