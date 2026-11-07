## 强化面板：纯 Label / Button / ItemList 搭建，不使用任何图片素材，方便后续替换皮肤。[br]
## 通过 CardEnhanceService.enter_enhance_system(backpack_key) 打开，背包键决定操作哪个背包的卡。
extends Control
class_name CardEnhancePanel

## 当前操作的背包键；由服务在加入场景树前写入。
var backpack_key: String = ""

## 左侧：背包卡片（单选）。
var _target_list: ItemList
## 右侧：副卡（多选）。
var _material_list: ItemList
## 目标卡信息与消耗说明。
var _info_label: Label
var _cost_label: Label
## 操作结果提示。
var _result_label: Label
## 保级符 / 保险金开关。
var _protect_check: CheckBox
var _insurance_check: CheckBox
var _enhance_button: Button
## 最近一次读取的卡片快照，避免每次刷新都重新查背包。
var _cards: Array[Dictionary] = []


func _ready() -> void:
	# 铺满屏幕并拦截点击，避免误触底层界面。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_cards()


## 构建全部控件；所有外观使用默认主题，不加载图片。
func _build_ui() -> void:
	# 半透明遮罩背景，避免与底层界面混淆。
	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08, 0.88)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# 外边距容器，统一留白。
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var title := Label.new()
	title.text = "卡片强化 —— 背包：%s" % backpack_key
	title.add_theme_font_size_override("font_size", 28)
	root_box.add_child(title)

	# 三栏：目标卡 / 信息 / 副卡。
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root_box.add_child(columns)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_column)
	var target_title := Label.new()
	target_title.text = "背包卡片（选择一张要强化的卡）"
	left_column.add_child(target_title)
	_target_list = ItemList.new()
	_target_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target_list.item_selected.connect(_on_target_selected)
	left_column.add_child(_target_list)

	var mid_column := VBoxContainer.new()
	mid_column.custom_minimum_size = Vector2(300, 0)
	columns.add_child(mid_column)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid_column.add_child(_info_label)
	_cost_label = Label.new()
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid_column.add_child(_cost_label)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_column)
	var material_title := Label.new()
	material_title.text = "副卡（可多选，任意植物卡）"
	right_column.add_child(material_title)
	_material_list = ItemList.new()
	_material_list.select_mode = ItemList.SELECT_MULTI
	_material_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_material_list.item_selected.connect(_on_material_selected)
	right_column.add_child(_material_list)

	# 底部：开关与按钮。
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root_box.add_child(bottom)
	_protect_check = CheckBox.new()
	_protect_check.text = "使用保级符（失败不降星）"
	_protect_check.toggled.connect(_on_option_toggled)
	bottom.add_child(_protect_check)
	_insurance_check = CheckBox.new()
	_insurance_check.text = "使用强化保险金（+15% 成功率，失败保留副卡）"
	_insurance_check.toggled.connect(_on_option_toggled)
	bottom.add_child(_insurance_check)
	_enhance_button = Button.new()
	_enhance_button.text = "强化"
	_enhance_button.pressed.connect(_on_enhance_pressed)
	bottom.add_child(_enhance_button)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_pressed)
	bottom.add_child(close_button)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_result_label)


## 重新读取背包卡片并刷新两列表格；[param keep_uid] 非 0 时尝试保持该卡选中。
func _refresh_cards(keep_uid: int = 0) -> void:
	_cards = Global.card_enhance_service.get_backpack_cards(backpack_key)
	_target_list.clear()
	for entry: Dictionary in _cards:
		var index := _target_list.add_item("%s ★%d（ID %d）" % [entry["name"], entry["star"], entry["uid"]])
		_target_list.set_item_metadata(index, entry["uid"])
	if keep_uid != 0:
		for index: int in _target_list.item_count:
			if int(_target_list.get_item_metadata(index)) == keep_uid:
				_target_list.select(index)
				break
	_update_material_list()
	_update_info()


## 返回当前选中的目标卡 uid；未选择时返回 0。
func _selected_target_uid() -> int:
	var selected := _target_list.get_selected_items()
	if selected.is_empty():
		return 0
	return int(_target_list.get_item_metadata(selected[0]))


## 重建副卡列表，排除目标卡并保留原有选择。
func _update_material_list() -> void:
	var target_uid := _selected_target_uid()
	var selected_before: Dictionary = {}
	for index: int in _material_list.get_selected_items():
		selected_before[int(_material_list.get_item_metadata(index))] = true
	_material_list.clear()
	for entry: Dictionary in _cards:
		if int(entry["uid"]) == target_uid:
			continue
		var index := _material_list.add_item("%s ★%d（ID %d）" % [entry["name"], entry["star"], entry["uid"]])
		_material_list.set_item_metadata(index, entry["uid"])
		if selected_before.has(int(entry["uid"])):
			_material_list.select(index, false)
	_update_info()


## 目标卡选择变化时刷新副卡与信息。
func _on_target_selected(_index: int) -> void:
	_update_material_list()


## 副卡选择变化时刷新消耗说明。
func _on_material_selected(_index: int) -> void:
	_update_info()


## 保级符 / 保险金开关变化时刷新成功率预览。
func _on_option_toggled(_pressed: bool) -> void:
	_update_info()


## 刷新目标卡信息、成功率与消耗；未选择或不可强化时给出原因。
func _update_info() -> void:
	var target_uid := _selected_target_uid()
	if target_uid == 0:
		_info_label.text = "请选择一张要强化的卡片"
		_cost_label.text = ""
		_enhance_button.disabled = true
		return
	var preview: Dictionary = Global.card_enhance_service.get_preview(backpack_key, target_uid, _insurance_check.button_pressed)
	if not preview.get("valid", false):
		_info_label.text = str(preview.get("reason", "不可强化"))
		_cost_label.text = ""
		_enhance_button.disabled = true
		return
	_enhance_button.disabled = false
	_info_label.text = "当前 %d 星 → %d 星\n成功率 %.1f%%\n失败可能降星：%s" % [
		int(preview["star"]),
		int(preview["next_star"]),
		float(preview["rate"]) * 100.0,
		"是" if bool(preview["can_drop"]) else "否",
	]
	_cost_label.text = "消耗：%d 金币 + %d 张副卡\n当前金币：%d\n保级符：%d　强化保险金：%d" % [
		int(preview["coin_cost"]),
		int(preview["material_count"]),
		int(preview["coin_value"]),
		Global.card_enhance_service.get_item_count(CardEnhanceData.ITEM_PROTECT),
		Global.card_enhance_service.get_item_count(CardEnhanceData.ITEM_INSURANCE),
	]


## 执行强化：读取目标与副卡 uid，调用服务并刷新列表。
func _on_enhance_pressed() -> void:
	var target_uid := _selected_target_uid()
	if target_uid == 0:
		_result_label.text = "请先选择要强化的卡片"
		return
	var material_uids: Array = []
	for index: int in _material_list.get_selected_items():
		material_uids.append(int(_material_list.get_item_metadata(index)))
	var result: Dictionary = Global.card_enhance_service.enhance(
		backpack_key,
		target_uid,
		material_uids,
		_protect_check.button_pressed,
		_insurance_check.button_pressed
	)
	_result_label.text = str(result.get("message", ""))
	_refresh_cards(target_uid)


## 关闭面板：释放承载它的 CanvasLayer。
func _on_close_pressed() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()
