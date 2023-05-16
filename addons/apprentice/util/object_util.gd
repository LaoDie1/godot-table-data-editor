#============================================================
#    Object Util
#============================================================
# - datetime: 2023-02-05 22:00:57
#============================================================
class_name ObjectUtil


## 引用对象，防止 RefCount 没有引用后被删除
class RefObject:
	extends Object
	
	var value
	
	func _init(value: Object) -> void:
		self.value = value



#============================================================
#  自定义
#============================================================
## 引用目标对象，防止引用丢失而消失。用在 [RefCounted] 类型的对象
##[br]
##[br][code]object[/code] 要引用的对象
##[br][code]depend[/code] 指定的依赖象。如果这个对象消失，则指定的引用对象也随之消失
static func ref_target(object: RefCounted, depend: Object = null):
	if depend == null:
		depend = RefObject.new(object)
	const key = "__ObjectUtil_ref_target_data"
	if depend.has_meta(key):
		var list = depend.get_meta(key) as Array
		list.append(object)
	else:
		var list = [object]
		depend.set_meta(key, list)


## 删除对象
static func queue_free(object: Object) -> void:
	if is_instance_valid(object):
		if object is Node:
			object.queue_free()
		else:
			Engine.get_main_loop().queue_delete(object)


##  对象是否是这个类
##[br]
##[br][code]object[/code]  判断的对象
##[br][code]class_type[/code]  类
static func object_equals_class(object: Object, class_type) -> bool:
	return object != null and is_instance_of(ScriptUtil.get_object_class(object), class_type)


##  设置对象的属性
##[br]
##[br][code]object[/code]  对象的属性
##[br][code]prop_data[/code]  属性数据
##[br][code]setter_callable[/code]  设置属性的方法回调，默认直接对象进行赋值，这个方法需要有
##2 个参数，分别于接收设置的属性和设置的值，默认方法回调为：
##[codeblock]
##func(property, value):
##    if property in object:
##        object[property] = value
##[/codeblock]
static func set_object_property(
	object: Object, 
	prop_data: Dictionary, 
	setter_callable : Callable = Callable()
) -> void:
	if not setter_callable.is_valid():
		setter_callable = func(property, value):
			if property in object:
				object[property] = value
	
	for prop in prop_data:
		setter_callable.call(prop, prop_data[prop])


##  实例化类场景
##[br]
##[br][code]_class[/code]  这个脚本下的相同脚本名称的场景
##[br][code]return[/code]  返回实例化后的场景
##[br]
##[br][b]注意：这个脚本名和场景名必须相同！[/b]
static func instance_class_scene(_class: Script) -> Node:
	var data = DataUtil.get_meta_dict_data("ObjectUtil_instance_scene_script_scene_map")
	var scene = DataUtil.get_value_or_set(data, _class, func():
		var path = ScriptUtil.get_object_script_path(_class).get_basename() + ".tscn"
		if FileAccess.file_exists(path):
			return load(path)
		push_error("没有 ", _class, " 类的场景")
		return null
	) as PackedScene
	if scene:
		return scene.instantiate()
	return null


## 对象是 null
static func is_null(object: Object) -> bool:
	return object == null

## 对象不是 null
static func non_null(object: Object) -> bool:
	return object != null

## 这个数据是否为空
static func is_empty(data) -> bool:
	if data == null:
		return true
	elif data is Array or data is String or data is Dictionary or data is Image:
		return data.is_empty()
	elif data is int or data is float:
		return data == 0
	elif data is Texture2D:
		return data.get_image() == null or data.get_image().is_empty()
	elif data is Callable:
		return data.is_null()
	elif data is Vector2 or data is Vector2i:
		return Vector2(data) == Vector2.ZERO
	elif data is Rect2 or data is Rect2i:
		return Rect2(data).size == Vector2.ZERO
	else:
		if data:
			return false
		else:
			return true

