## 按背包内容生成植物候选页，同一植物可重复出现并分别占位；僵尸与僵王仍按目录生成。[br]
## 同一模板的多张候选卡只允许选中一张，选中后其余同类卡片临时禁用，取消后统一恢复。[br]
## 卡片数量超过单页容量时按页切分，由翻页按钮切换。
extends TextureRect
class_name CardSlotCandidate

## 普通备选页面的挂载节点。
@onready var all_card_page: Control = $AllCardPage
## 植物页面的占位布局模板。
@onready var grid_container_plant: GridContainer = $AllCardPage/GridContainerPlant
## 普通僵尸和僵王共用的占位布局模板。
@onready var grid_container_zombie: GridContainer = $AllCardPage/GridContainerZombie
## 全部候选容器，按生成顺序保存；同一植物重复出现时会有多个容器。
var candidate_containers: Array[CardCandidateContainer] = []
## 按完整选择键分组的候选容器；同键数组内是同一张卡的重复实例。
var candidates_by_key: Dictionary[Vector3i, Array] = {}
## 本局选卡读取的背包键；空字符串表示使用 Global 当前背包。
var backpack_key: String = ""
## 至少有一张已解锁卡的普通页面。
var all_show_page: Array[GridContainer] = []
## 普通页面的零起点页码。
var curr_page: int = 0
## 普通页面的页码标签。
@onready var label_page: Label = $LabelPage
## 模仿者选择弹层。
@onready var all_imitater_card: Control = %AllImitaterCard
## 模仿卡页面的挂载节点。
@onready var all_card_page_imitater: Control = $AllImitaterCard/Panel/AllCardPageImitater
## 模仿卡页面的占位布局模板。
@onready var grid_container_plant_imitater: GridContainer = $AllImitaterCard/Panel/AllCardPageImitater/GridContainerPlantImitater
## 独立模仿者入口，只负责打开弹层，不用于出战。
@onready var card_imitater: CardImitater = $ImitaterBG/CardImitater
## 至少有一张已解锁卡的模仿卡页面。
var all_show_page_imitater: Array[GridContainer] = []
## 模仿卡页面的零起点页码。
var curr_page_imitater: int = 0

## 根据背包内容与目录顺序生成候选页，仅展示包含已解锁内容的页面。
func _ready() -> void:
	_create_candidate_pages(ResourceCardReference.CardType.Plant, grid_container_plant, all_card_page)
	_create_candidate_pages(ResourceCardReference.CardType.Zombie, grid_container_zombie, all_card_page)
	_create_candidate_pages(ResourceCardReference.CardType.Plant, grid_container_plant_imitater, all_card_page_imitater, true)
	if not all_show_page.is_empty():
		all_show_page[0].visible = true
	if not all_show_page_imitater.is_empty():
		all_show_page_imitater[0].visible = true
	_update_page_label()
	card_imitater.signal_card_click.connect(imitater_card_slot_appear)

## 把一批引用复制到 [param grid_template] 生成的页里，并按容量切页。[br]
## [param imitate] 为 true 时为植物创建模仿修饰，不修改目录共享引用。[br]
## 普通僵尸页末尾追加僵王目录，各引用保留自身类别，不受关卡自动出场类型影响。
func _create_candidate_pages(card_type: int, grid_template: GridContainer, page_root: Control, imitate: bool = false) -> void:
	# 页面容量沿用场景占位，内容编号不再承担布局索引。
	var page_capacity: int = grid_template.get_child_count()
	if page_capacity <= 0:
		push_error("CardSlotCandidate：备选页面缺少卡片占位。")
		return
	page_root.remove_child(grid_template)
	# 本批生成的页，顺序与引用顺序一致。
	var pages: Array[GridContainer] = []
	# 有效出战卡的连续布局索引；重复卡片各占一格。
	var card_index: int = 0
	# 本批要展示的引用；植物来自背包且保留重复条目。
	var page_references := _collect_page_references(card_type, imitate)
	# 当前源引用只读使用，混合页面也保留真实内容类别。
	for catalog_reference: ResourceCardReference in page_references:
		if not AllCards.is_battle_card(catalog_reference):
			continue
		# 模仿修饰只写入新引用。
		var reference: ResourceCardReference = catalog_reference.copy_reference()
		if imitate:
			reference.is_imitater = true
		# 当前卡片所属的零起点页；浮点除法后显式向下取整，保留分页规则。
		var page_index: int = floori(float(card_index) / page_capacity)
		if page_index >= pages.size():
			# 新页保留模板中的栅格占位，首次生成时先隐藏。
			var new_page: GridContainer = grid_template.duplicate() as GridContainer
			new_page.visible = false
			page_root.add_child(new_page)
			pages.append(new_page)
		# 卡片与占位分别保存引用，选择时仍可返回原位。
		var new_card: Card = AllCards.create_card(reference, Card.CardContext.Selection)
		if new_card == null:
			continue
		# 每张卡片对应的背景与返回位置。
		var container: CardCandidateContainer = SceneRegistry.CARD_CANDIDATE_CONTAINER.instantiate()
		container.init_card_in_seed_chooser(new_card)
		pages[page_index].get_child(card_index % page_capacity).add_child(container)
		container.visible = _is_unlocked(reference)
		_register_candidate(reference, container)
		card_index += 1
	# 只将含可见卡片的页面加入翻页范围。
	for page: GridContainer in pages:
		# 本页是否存在可展示的已解锁内容。
		var has_visible_card: bool = false
		# 场景中的单卡占位节点。
		for placeholder: Node in page.get_children():
			if placeholder.get_child_count() > 0 and (placeholder.get_child(0) as Control).visible:
				has_visible_card = true
				break
		if has_visible_card:
			if imitate:
				all_show_page_imitater.append(page)
			else:
				all_show_page.append(page)
	grid_template.queue_free()

## 收集本批展示的引用：植物取背包内容（允许重复），僵尸页追加僵王目录。
func _collect_page_references(card_type: int, imitate: bool) -> Array[ResourceCardReference]:
	if card_type == ResourceCardReference.CardType.Plant:
		# 模仿页复用同一批植物，只额外打上模仿修饰。
		var plant_references: Array[ResourceCardReference] = []
		for reference: ResourceCardReference in _get_bag_plant_references():
			var copy: ResourceCardReference = reference.copy_reference()
			if imitate:
				copy.is_imitater = true
			plant_references.append(copy)
		return plant_references
	# 僵尸与僵王仍使用目录顺序，不受背包影响。
	var references: Array[ResourceCardReference] = AllCards.get_references(card_type)
	if card_type == ResourceCardReference.CardType.Zombie:
		references.append_array(AllCards.get_references(ResourceCardReference.CardType.ZombieBoss))
	return references

## 返回本次选卡背包内的植物引用；背包里有几张就返回几个，重复条目不会被合并。[br]
## 背包服务不可用时回退到旧的可用植物列表，避免场景单独运行时没有候选卡。
func _get_bag_plant_references() -> Array[ResourceCardReference]:
	var result: Array[ResourceCardReference] = []
	var service: BackpackService = Global.backpack_service
	if service == null:
		for reference: ResourceCardReference in AllCards.get_references(ResourceCardReference.CardType.Plant):
			if Global.global_game_state.curr_plant.has(reference.content_id):
				result.append(reference)
		return result
	var key := service.get_selection_backpack_key(backpack_key)
	if key.is_empty():
		return result
	for reference: ResourceCardReference in service.get_backpack(key):
		if reference == null or not reference.is_valid():
			continue
		if reference.card_type != ResourceCardReference.CardType.Plant:
			continue
		# 独立模仿者入口单独占位，不在普通植物页重复出现。
		if reference.content_id == CharacterRegistry.PlantType.P999Imitater:
			continue
		result.append(reference)
	return result

## 登记一个候选容器；同一选择键可能存在多个重复实例，因此两类索引都保留全部条目。
func _register_candidate(reference: ResourceCardReference, container: CardCandidateContainer) -> void:
	candidate_containers.append(container)
	var key := reference.get_selection_key()
	if not candidates_by_key.has(key):
		candidates_by_key[key] = []
	candidates_by_key[key].append(container)

## 返回 [param reference] 是否存在于对应类别的当前可用角色列表。[br]
## 植物由背包内容决定：只有本次选卡读取的背包内存在该植物时才可上场。
func _is_unlocked(reference: ResourceCardReference) -> bool:
	match reference.card_type:
		ResourceCardReference.CardType.Plant:
			return _is_plant_in_backpack(reference)
		ResourceCardReference.CardType.Zombie:
			return Global.global_game_state.curr_zombie.has(reference.content_id)
		ResourceCardReference.CardType.ZombieBoss:
			return Global.global_game_state.curr_zombie_boss.has(reference.content_id)
	return false


## 返回 [param reference] 的植物是否在本次选卡读取的背包内；模仿修饰不参与判断。[br]
## 背包服务不可用（例如场景单独测试）时回退到旧的可用植物列表，避免出现无卡可选。
func _is_plant_in_backpack(reference: ResourceCardReference) -> bool:
	var service: BackpackService = Global.backpack_service
	if service == null:
		return Global.global_game_state.curr_plant.has(reference.content_id)
	var key := service.get_selection_backpack_key(backpack_key)
	if key.is_empty():
		return Global.global_game_state.curr_plant.has(reference.content_id)
	return service.has_card(key, reference)


## 设置选卡读取的背包键；必须在候选页构建前写入才能影响本次可用卡片。
func set_backpack_key(key: String) -> void:
	backpack_key = key

## 查询 [param reference] 对应的候选容器：重复卡片时优先返回仍可选中且可见的一张。[br]
## 全部同类卡片都被禁用时返回首个容器，调用方的点击处理会因禁用状态拒绝这次选择。
func get_candidate(reference: ResourceCardReference) -> CardCandidateContainer:
	if reference == null:
		return null
	var candidates: Array = candidates_by_key.get(reference.get_selection_key(), [])
	for container: CardCandidateContainer in candidates:
		if not is_instance_valid(container):
			continue
		if container.visible and not container.card.is_selection_blocked:
			return container
	return candidates[0] if not candidates.is_empty() else null

## 返回与 [param reference] 同模板的全部候选容器；普通卡与模仿卡共享模板，一并返回。
func get_candidates_by_template(reference: ResourceCardReference) -> Array[CardCandidateContainer]:
	var result: Array[CardCandidateContainer] = []
	if reference == null:
		return result
	var template_key := reference.get_template_key()
	for container: CardCandidateContainer in candidate_containers:
		if not is_instance_valid(container):
			continue
		if container.card == null or container.card.card_reference == null:
			continue
		if container.card.card_reference.get_template_key() == template_key:
			result.append(container)
	return result

## 按植物模板统一设置候选卡的可选状态。[br]
## 选中一张后禁用其余同类卡片；取消选择时恢复全部同类卡片，已进入出战槽的卡片不受影响。
func set_template_blocked(reference: ResourceCardReference, blocked: bool) -> void:
	for container: CardCandidateContainer in get_candidates_by_template(reference):
		var card: Card = container.card
		if card == null or card.is_choosed_pre_card:
			continue
		card.set_selection_blocked(blocked)

## 刷新普通页面页码文本；没有可用页面时显示 0/0。
func _update_page_label() -> void:
	label_page.text = (str(curr_page + 1) + "/" + str(all_show_page.size())) if not all_show_page.is_empty() else "0/0"

## 显示普通备选卡的上一页。
func _on_last_page_button_pressed() -> void:
	change_page(-1)

## 显示普通备选卡的下一页。
func _on_next_page_button_pressed() -> void:
	change_page(1)

## 按 [param change_num] 循环切换普通页面；空集合不执行切换。[br]
## 翻页只改变可见页，不改变已选中卡片和同类卡片的禁用状态。
func change_page(change_num: int = 1) -> void:
	if all_show_page.is_empty():
		return
	all_show_page[curr_page].visible = false
	curr_page = posmod(curr_page + change_num, all_show_page.size())
	all_show_page[curr_page].visible = true
	_update_page_label()

## [param _card] 是入口点击信号携带的卡片；仅打开模仿卡弹层。
func imitater_card_slot_appear(_card: Card) -> void:
	all_imitater_card.visible = true

## 关闭模仿卡弹层。
func imitater_card_slot_disappear() -> void:
	all_imitater_card.visible = false

## 真实模仿卡选中后关闭弹层并锁定独立入口。
func imitater_be_choosed() -> void:
	imitater_card_slot_disappear()
	card_imitater.imitater_card_be_choosed()

## 取消真实模仿卡后恢复独立入口。
func imitater_be_choosed_cancel() -> void:
	card_imitater.imitater_card_be_choosed_cancal()

## 显示模仿卡的上一页。
func _on_imitater_last_page_button_pressed() -> void:
	change_page_imitater(-1)

## 显示模仿卡的下一页。
func _on_imitater_next_page_button_pressed() -> void:
	change_page_imitater(1)

## 按 [param change_num] 循环切换模仿卡页面；没有解锁内容时不切换。
func change_page_imitater(change_num: int = 1) -> void:
	if all_show_page_imitater.is_empty():
		return
	all_show_page_imitater[curr_page_imitater].visible = false
	curr_page_imitater = posmod(curr_page_imitater + change_num, all_show_page_imitater.size())
	all_show_page_imitater[curr_page_imitater].visible = true
