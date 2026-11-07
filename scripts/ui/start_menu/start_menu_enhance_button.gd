## 开始菜单的卡片强化入口按钮。[br]
## 保留原本的鼠标悬停切换贴图逻辑，并在点击时打开卡片强化面板。[br]
## 面板操作当前背包；没有当前背包时回退到默认背包。
extends TextureButton

## 鼠标悬停时显示的贴图容器；按钮缺少该子节点时自动跳过。
@onready var mouse: TextureRect = get_node_or_null("mouse") as TextureRect
## 默认显示的贴图容器；按钮缺少该子节点时自动跳过。
@onready var default: TextureRect = get_node_or_null("default") as TextureRect


func _ready() -> void:
	## 与原有内嵌脚本一致：隐藏 texture_normal，由子节点负责显示。
	texture_normal = null
	_on_mouse_exited()
	# 悬停与点击都直接连接；场景里可能已有同名连接，先判断避免重复连接报错。
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


## 鼠标进入时显示悬停贴图。
func _on_mouse_entered() -> void:
	if mouse != null:
		mouse.visible = true
	if default != null:
		default.visible = false


## 鼠标离开时恢复默认贴图。
func _on_mouse_exited() -> void:
	if mouse != null:
		mouse.visible = false
	if default != null:
		default.visible = true


## 点击时打开卡片强化面板。
func _on_pressed() -> void:
	if Global.card_enhance_service == null:
		push_error("StartMenuEnhanceButton：强化服务未就绪，无法打开强化界面。")
		return
	# 当前背包键由选卡/背包系统维护；为空时回退默认背包。
	var backpack_key: String = Global.backpack_service.get_curr_backpack_key()
	if backpack_key.is_empty():
		backpack_key = GlobalGameState.DEFAULT_BACKPACK_KEY
	Global.card_enhance_service.enter_enhance_system(backpack_key)
