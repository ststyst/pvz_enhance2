## 卡片强化服务：负责消耗校验、掷骰、修改星级/道具，并打开强化面板。[br]
## 入口 [method enter_enhance_system] 带背包键参数，决定操作哪个背包内的植物卡。[br]
## 规则参考《美食大战老鼠》：7 星以上失败降 1 星；保级符免降星；保险金提高成功率并保留副卡。
extends Node
class_name CardEnhanceService

## 一次强化结束（无论成败）后发出；[param result] 与 [method enhance] 的返回值一致。
signal enhance_finished(result: Dictionary)

## 与 Global 根下的运行态同级，用唯一名引用。
@onready var global_game_state: GlobalGameState = %GlobalGameState

## 强化掷骰使用的随机源；测试可设置 seed 复现结果。
var rng := RandomNumberGenerator.new()

## 待打开的强化界面背包键；由强化场景启动时取走并清空。
var pending_backpack_key: String = ""


func _ready() -> void:
	rng.randomize()


#region 界面入口
## 进入强化系统：记录 [param backpack_key] 后切换到强化场景。[br]
## 背包不存在时打日志并留在当前场景。
func enter_enhance_system(backpack_key: String) -> void:
	if not Global.backpack_service.has_backpack(backpack_key):
		push_error("CardEnhanceService：背包不存在：%s" % backpack_key)
		return
	pending_backpack_key = backpack_key
	get_tree().change_scene_to_file("res://scenes/enhance/enhance.tscn")


## 取走待打开的背包键并清空；没有记录时回退到当前背包或默认背包。
func take_pending_backpack_key() -> String:
	var key := pending_backpack_key
	pending_backpack_key = ""
	if key.is_empty() or not Global.backpack_service.has_backpack(key):
		key = Global.backpack_service.get_curr_backpack_key()
	if key.is_empty():
		key = GlobalGameState.DEFAULT_BACKPACK_KEY
	return key
#endregion

#region 查询
## 返回背包内的植物卡列表，供面板展示；每项包含 uid、plant_type、name、star。
func get_backpack_cards(backpack_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# 显式标注背包卡片类型，避免跨单例调用时类型推断失败。
	var bag_cards: Array[ResourceCardReference] = Global.backpack_service.get_backpack(backpack_key)
	for card: ResourceCardReference in bag_cards:
		if card == null or card.card_type != ResourceCardReference.CardType.Plant:
			continue
		result.append({
			"uid": card.card_uid,
			"plant_type": card.content_id,
			"name": str(Global.character_registry.get_plant_info(card.content_id, CharacterRegistry.PlantInfoAttribute.PlantName)),
			"star": card.star_level,
		})
	return result


## 返回强化预览：成功率、副卡数量、金币消耗、是否可能降星等；不可强化时 valid=false。[br]
## [param use_insurance] 为 true 时把保险金的成功率加成计入预览。
func get_preview(backpack_key: String, target_uid: int, use_insurance: bool = false) -> Dictionary:
	var target: ResourceCardReference = Global.backpack_service.get_card_by_uid(backpack_key, target_uid)
	if target == null or target.card_type != ResourceCardReference.CardType.Plant:
		return {"valid": false, "reason": "目标卡片不存在或不是植物卡"}
	var star: int = target.star_level
	if CardEnhanceData.is_max_star(star):
		return {"valid": false, "reason": "已是最高星级，无法继续强化"}
	# 成功率：基础值 + 保险金加成，限制在 0~1。
	var rate: float = CardEnhanceData.get_success_rate(star)
	if use_insurance:
		rate += CardEnhanceData.INSURANCE_RATE_BONUS
	rate = clampf(rate, 0.0, 1.0)
	return {
		"valid": true,
		"star": star,
		"next_star": star + 1,
		"rate": rate,
		"material_count": CardEnhanceData.get_material_count(star),
		"coin_cost": CardEnhanceData.get_coin_cost(star),
		"coin_value": global_game_state.coin_value,
		"can_drop": CardEnhanceData.can_drop_star(star),
	}
#endregion

#region 强化执行
## 执行一次强化，返回结果字典。[br]
## [param material_uids] 为副卡唯一 id 列表，数量必须等于规则要求，且不能包含目标卡。[br]
## [param use_protect] 消耗保级符，失败时不降星；[param use_insurance] 消耗强化保险金，成功率和保留副卡。[br]
## 返回字段：success / old_star / new_star / rate / cost / consumed_materials / message 等。
func enhance(
	backpack_key: String,
	target_uid: int,
	material_uids: Array,
	use_protect: bool = false,
	use_insurance: bool = false
) -> Dictionary:
	var result := {"success": false, "message": "", "old_star": 0, "new_star": 0}
	var backpack: BackpackService = Global.backpack_service
	var target: ResourceCardReference = backpack.get_card_by_uid(backpack_key, target_uid)
	if target == null or target.card_type != ResourceCardReference.CardType.Plant:
		result["message"] = "目标卡片不存在或不是植物卡"
		return result
	var star: int = target.star_level
	if CardEnhanceData.is_max_star(star):
		result["message"] = "已是最高星级，无法继续强化"
		return result
	# 副卡数量校验。
	var material_count: int = CardEnhanceData.get_material_count(star)
	if material_uids.size() != material_count:
		result["message"] = "副卡数量不符：需要 %d 张，当前选择 %d 张" % [material_count, material_uids.size()]
		return result
	# 副卡内容校验：必须是背包内的植物卡，不能是目标卡本身，也不能重复。
	var materials: Array[ResourceCardReference] = []
	for raw_uid: Variant in material_uids:
		var uid: int = int(raw_uid)
		if uid == target_uid:
			result["message"] = "副卡不能包含目标卡"
			return result
		var card: ResourceCardReference = backpack.get_card_by_uid(backpack_key, uid)
		if card == null or card.card_type != ResourceCardReference.CardType.Plant:
			result["message"] = "副卡不存在或不是植物卡（ID %d）" % uid
			return result
		if materials.any(func(item: ResourceCardReference) -> bool: return item.card_uid == uid):
			result["message"] = "副卡存在重复（ID %d）" % uid
			return result
		materials.append(card)
	# 金币与道具校验。
	var coin_cost: int = CardEnhanceData.get_coin_cost(star)
	if global_game_state.coin_value < coin_cost:
		result["message"] = "金币不足：需要 %d，当前 %d" % [coin_cost, global_game_state.coin_value]
		return result
	if use_protect and get_item_count(CardEnhanceData.ITEM_PROTECT) <= 0:
		result["message"] = "保级符不足"
		return result
	if use_insurance and get_item_count(CardEnhanceData.ITEM_INSURANCE) <= 0:
		result["message"] = "强化保险金不足"
		return result
	# 本次成功率；保险金加成在此计入。
	var rate: float = clampf(
		CardEnhanceData.get_success_rate(star) + (CardEnhanceData.INSURANCE_RATE_BONUS if use_insurance else 0.0),
		0.0,
		1.0
	)
	# 道具与金币无论成败都消耗。
	if use_protect:
		add_item(CardEnhanceData.ITEM_PROTECT, -1)
	if use_insurance:
		add_item(CardEnhanceData.ITEM_INSURANCE, -1)
	global_game_state.coin_value -= coin_cost
	# 掷骰决定结果。
	var success: bool = rng.randf() < rate
	result["success"] = success
	result["rate"] = rate
	result["cost"] = coin_cost
	result["old_star"] = star
	result["consumed_materials"] = []
	result["protect_used"] = use_protect
	result["insurance_used"] = use_insurance
	if success:
		target.star_level = star + 1
		# 成功后副卡消失。
		for card: ResourceCardReference in materials:
			backpack.remove_card_by_uid(backpack_key, card.card_uid)
			(result["consumed_materials"] as Array).append(card.card_uid)
		result["message"] = "强化成功：%d 星 → %d 星" % [star, star + 1]
	elif use_insurance:
		# 保险金：失败也保留副卡。
		result["message"] = "强化失败，保险金使副卡保留，星级保持 %d 星" % star
	else:
		# 无保险：失败消耗副卡。
		for card: ResourceCardReference in materials:
			backpack.remove_card_by_uid(backpack_key, card.card_uid)
			(result["consumed_materials"] as Array).append(card.card_uid)
		if CardEnhanceData.can_drop_star(star) and not use_protect:
			target.star_level = star - 1
			result["message"] = "强化失败，星级下降：%d 星 → %d 星" % [star, star - 1]
		elif CardEnhanceData.can_drop_star(star) and use_protect:
			result["message"] = "强化失败，保级符生效，星级保持 %d 星" % star
		else:
			result["message"] = "强化失败，星级保持 %d 星" % star
	result["new_star"] = target.star_level
	# 星级与副卡变化需要广播并写档。
	backpack.mark_backpack_changed(backpack_key)
	_persist()
	enhance_finished.emit(result)
	return result
#endregion

#region 合成式强化
## 返回背包内可用的“强化消耗品”；每项为 {id, name, count}。[br]
## 物品系统尚未实现时返回空数组；未来接入物品标签后，在此按 [constant CardEnhanceData.CONSUMABLE_TAG] 过滤。
func get_enhance_consumables(_backpack_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	return result


## 合成式强化：消耗主卡与固定 3 张副卡，产出一张同类型、星级 +1 的新卡。[br]
## [param consumable_id] 为“强化消耗品”的物品 id，空字符串表示不使用；传入时必须在可选列表内。[br]
## 返回结果字典：success / message / old_star / new_star / new_uid / plant_type。
func combine_cards(backpack_key: String, main_uid: int, material_uids: Array, consumable_id: String = "") -> Dictionary:
	var result := {"success": false, "message": ""}
	var backpack: BackpackService = Global.backpack_service
	var main_card: ResourceCardReference = backpack.get_card_by_uid(backpack_key, main_uid)
	if main_card == null or main_card.card_type != ResourceCardReference.CardType.Plant:
		result["message"] = "主卡不存在或不是植物卡"
		return result
	if material_uids.size() < 1 or material_uids.size() > CardEnhanceData.COMBINE_MATERIAL_COUNT:
		result["message"] = "副卡数量需为 1~%d 张，当前选择 %d 张" % [CardEnhanceData.COMBINE_MATERIAL_COUNT, material_uids.size()]
		return result
	var star: int = main_card.star_level
	if CardEnhanceData.is_max_star(star):
		result["message"] = "主卡已是最高星级，无法继续强化"
		return result
	# 副卡校验：必须是背包内的植物卡，不能是主卡，也不能重复。
	var materials: Array[ResourceCardReference] = []
	for raw_uid: Variant in material_uids:
		var uid: int = int(raw_uid)
		if uid == main_uid:
			result["message"] = "副卡不能包含主卡"
			return result
		var card: ResourceCardReference = backpack.get_card_by_uid(backpack_key, uid)
		if card == null or card.card_type != ResourceCardReference.CardType.Plant:
			result["message"] = "副卡不存在或不是植物卡（ID %d）" % uid
			return result
		if materials.any(func(item: ResourceCardReference) -> bool: return item.card_uid == uid):
			result["message"] = "副卡存在重复（ID %d）" % uid
			return result
		materials.append(card)
	# 消耗品只有在“背包内存在且属于强化消耗品”时才允许使用。
	if not consumable_id.is_empty():
		var usable := false
		for entry: Dictionary in get_enhance_consumables(backpack_key):
			if str(entry.get("id", "")) == consumable_id:
				usable = true
				break
		if not usable:
			result["message"] = "强化消耗品不可用：%s" % consumable_id
			return result
	# 记录主卡类型后再消耗，保证新卡与主卡同类型。
	var plant_type: int = main_card.content_id
	# 一次性收集需要消耗的 uid，主卡在前。
	var consume_uids: Array = [main_uid]
	for material: ResourceCardReference in materials:
		consume_uids.append(material.card_uid)
	for raw_uid: Variant in consume_uids:
		backpack.remove_card_by_uid(backpack_key, int(raw_uid))
	if not consumable_id.is_empty():
		add_item(consumable_id, -1)
	# 记录消耗后的 uid 集合，用于定位新生成的卡片。
	var before_uids: Dictionary = {}
	for card: ResourceCardReference in backpack.get_backpack(backpack_key):
		before_uids[card.card_uid] = true
	# 产出同植物类型、星级 +1 的新卡（由背包服务分配新唯一 id 并写档）。
	backpack.add_plant_card(backpack_key, plant_type, 1, star + 1)
	var new_uid := 0
	for card: ResourceCardReference in backpack.get_backpack(backpack_key):
		if not before_uids.has(card.card_uid):
			new_uid = card.card_uid
	result["success"] = true
	result["plant_type"] = plant_type
	result["old_star"] = star
	result["new_star"] = star + 1
	result["new_uid"] = new_uid
	result["message"] = "强化成功：%s ★%d → ★%d" % [
		str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)),
		star,
		star + 1,
	]
	enhance_finished.emit(result)
	return result
#endregion

#region 强化道具
## 返回 [param item_id] 的持有数量。
func get_item_count(item_id: String) -> int:
	return int(global_game_state.enhance_items.get(item_id, 0))


## 增加/减少 [param item_id] 的数量；数量不会降到 0 以下。
func add_item(item_id: String, delta: int) -> void:
	var current := get_item_count(item_id)
	global_game_state.enhance_items[item_id] = maxi(0, current + delta)
	_persist()


## 返回全部强化道具的持有数量，便于界面展示。
func get_item_counts() -> Dictionary:
	var counts := {}
	for item_id: String in CardEnhanceData.ITEM_NAMES.keys():
		counts[item_id] = get_item_count(item_id)
	return counts
#endregion


## 立即写回全局存档；未登录或服务不可用时安全跳过。
func _persist() -> void:
	if Global == null or Global.save_service == null:
		return
	Global.save_service.save_now()
