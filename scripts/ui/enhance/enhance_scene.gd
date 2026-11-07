## 强化界面：在 Backpack 节点下构建卡片背包，点击实现主卡/副卡选择，确认后合成新卡。[br]
## 主卡位：EnhanceMainInterface/MainCard；副卡位：ConsumedCard / ConsumedCard2 / ConsumedCard3。[br]
## 不使用任何图片素材，全部复用游戏内 Card 场景与默认主题控件。
extends Node2D
class_name EnhanceScene

## 卡槽内卡片相对槽位原点的偏移，让 50×70 的卡片居中显示。
const SLOT_CARD_OFFSET := Vector2(-25, -35)
## 背包网格的列数。
const GRID_COLUMNS: int = 9

@onready var backpack_root: Node2D = $Backpack
@onready var main_slot: Node2D = $EnhanceMainInterface/MainCard
## 三个副卡槽，顺序对应 ConsumedCard / ConsumedCard2 / ConsumedCard3。
@onready var consumed_slots: Array[Node2D] = [
	$EnhanceMainInterface/ConsumedCard,
	$EnhanceMainInterface/ConsumedCard2,
	$EnhanceMainInterface/ConsumedCard3,
]
@onready var confirm_button: Button = $EnhanceMainInterface/ConfirmButton
@onready var leave_button: Button = $LeaveButton

## 当前操作的背包键。
var backpack_key: String = ""
## 主卡 uid；0 表示未选择。
var main_uid: int = 0
## 副卡 uid 列表，最多 CardEnhanceData.COMBINE_MATERIAL_COUNT 张。
var material_uids: Array[int] = []
## 当前可用的强化消耗品；为空表示本次不使用消耗品。
var consumables: Array[Dictionary] = []
## 本次选用的强化消耗品 id。
var selected_consumable_id: String = ""

## 背包卡片网格。
var _grid: GridContainer
## 主卡/副卡与消耗品信息。
var _info_label: Label
## 操作结果提示。
var _message_label: Label


func _ready() -> void:
	# 背包键由强化服务在切换场景前写入；没有时回退到当前/默认背包。
	backpack_key = str(Global.card_enhance_service.take_pending_backpack_key())
	confirm_button.pressed.connect(_on_confirm_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	_build_backpack_ui()
	_refresh_consumables()
	_refresh_all()


## 在 Backpack 节点下创建滚动网格与信息标签。
func _build_backpack_ui() -> void:
	var title := Label.new()
	title.text = "背包"
	title.position = Vector2(0, 0)
	backpack_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.position = Vector2(0, 30)
	scroll.size = Vector2(556, 540)
	backpack_root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	_info_label = Label.new()
	_info_label.position = Vector2(8, 445)
	_info_label.size = Vector2(420, 80)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$EnhanceMainInterface.add_child(_info_label)

	_message_label = Label.new()
	_message_label.position = Vector2(230, 371)
	_message_label.size = Vector2(250, 70)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$EnhanceMainInterface.add_child(_message_label)


## 读取当前背包可用的“强化消耗品”；目前物品系统未实现，通常为空。
func _refresh_consumables() -> void:
	var raw: Variant = Global.card_enhance_service.get_enhance_consumables(backpack_key)
	consumables.clear()
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary:
				consumables.append(entry)
	selected_consumable_id = "" if consumables.is_empty() else str(consumables[0].get("id", ""))


## 刷新背包、卡槽与信息文本。
func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_slots()
	_update_info()


## 重建背包网格；每张卡绑定自己的 uid，点击时交给选择逻辑。
func _refresh_inventory() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var bag_cards: Array[ResourceCardReference] = Global.backpack_service.get_backpack(backpack_key)
	for reference: ResourceCardReference in bag_cards:
		if reference == null or reference.card_type != ResourceCardReference.CardType.Plant:
			continue
		# 已放入主卡/副卡槽的卡片从背包中隐藏，取消选择后重新出现。
		if reference.card_uid == main_uid or material_uids.has(reference.card_uid):
			continue
		var card: Card = AllCards.create_card(reference, Card.CardContext.Selection)
		if card == null:
			continue
		card.signal_card_click.connect(_on_inventory_card_clicked.bind(reference.card_uid))
		_grid.add_child(card)


## 点击背包卡片：[param uid] 对应卡片唯一 id。[br]
## 已选中的卡会取消选择；主卡为空时选为主卡，否则作为副卡（最多三张）。
func _on_inventory_card_clicked(_card: Card, uid: int) -> void:
	if uid == main_uid:
		main_uid = 0
	elif material_uids.has(uid):
		material_uids.erase(uid)
	elif main_uid == 0:
		main_uid = uid
	elif material_uids.size() < CardEnhanceData.COMBINE_MATERIAL_COUNT:
		material_uids.append(uid)
	else:
		_message_label.text = "副卡已满（最多 %d 张），请先取消一张" % CardEnhanceData.COMBINE_MATERIAL_COUNT
		return
	_message_label.text = ""
	_refresh_all()


## 重建四个卡槽的显示。
func _refresh_slots() -> void:
	_clear_slot(main_slot)
	for slot: Node2D in consumed_slots:
		_clear_slot(slot)
	if main_uid != 0:
		_place_slot_card(main_slot, main_uid, 0)
	for index: int in material_uids.size():
		_place_slot_card(consumed_slots[index], material_uids[index], index + 1)


## 清空一个卡槽内的显示卡片。
func _clear_slot(slot: Node2D) -> void:
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()


## 在卡槽里放置一张可点击取消的卡片；[param slot_index] 0 为主卡，1~3 为副卡下标 +1。
func _place_slot_card(slot: Node2D, uid: int, slot_index: int) -> void:
	var reference: ResourceCardReference = Global.backpack_service.get_card_by_uid(backpack_key, uid)
	if reference == null:
		return
	var card: Card = AllCards.create_card(reference, Card.CardContext.Selection)
	if card == null:
		return
	card.position = SLOT_CARD_OFFSET
	card.signal_card_click.connect(_on_slot_card_clicked.bind(slot_index))
	slot.add_child(card)


## 点击卡槽里的卡片时取消对应选择。
func _on_slot_card_clicked(_card: Card, slot_index: int) -> void:
	if slot_index == 0:
		main_uid = 0
	else:
		var material_index: int = slot_index - 1
		if material_index < material_uids.size():
			material_uids.remove_at(material_index)
	_message_label.text = ""
	_refresh_all()


## 刷新主卡/副卡/消耗品文本。
func _update_info() -> void:
	var text := ""
	if main_uid == 0:
		text = "主卡：未选择（点击背包卡片选择主卡）"
	else:
		var main_card: ResourceCardReference = Global.backpack_service.get_card_by_uid(backpack_key, main_uid)
		if main_card == null:
			text = "主卡：已失效"
		else:
			var plant_name := str(Global.character_registry.get_plant_info(
				main_card.content_id,
				CharacterRegistry.PlantInfoAttribute.PlantName
			))
			text = "主卡：%s ★%d → ★%d" % [plant_name, main_card.star_level, main_card.star_level + 1]
	text += "\n副卡：%d / %d" % [material_uids.size(), CardEnhanceData.COMBINE_MATERIAL_COUNT]
	if not selected_consumable_id.is_empty():
		text += "\n强化消耗品：%s" % selected_consumable_id
	_info_label.text = text


## 确认强化：校验主卡与三张副卡，调用合成式强化并刷新界面。
func _on_confirm_pressed() -> void:
	if main_uid == 0:
		_message_label.text = "请先选择主卡"
		return
	if material_uids.size() < 1:
		_message_label.text = "至少需要 1 张副卡"
		return
	var result: Dictionary = Global.card_enhance_service.combine_cards(
		backpack_key,
		main_uid,
		material_uids,
		selected_consumable_id
	)
	_message_label.text = str(result.get("message", ""))
	if bool(result.get("success", false)):
		main_uid = 0
		material_uids.clear()
		_refresh_consumables()
		_refresh_all()


## 返回开始菜单。
func _on_leave_pressed() -> void:
	get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu]
	)
