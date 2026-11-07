## 卡片强化规则常量表。[br]
## 数值按“当前星级”读取，索引 0~16；索引 16 为满星占位，不可继续强化。[br]
## 规则参考《美食大战老鼠》：7 星以上强化失败会降 1 星，保级符可免疫降星，[br]
## 强化保险金提高成功率并保留副卡；消耗任意植物卡作为副卡，不限种类。
extends RefCounted
class_name CardEnhanceData

## 可强化到的最高星级。
const MAX_STAR: int = 16
## 失败降星的起始星级（含）。
const DROP_STAR_THRESHOLD: int = 7

## 当前星级 → 强化到下一星的基础成功率（17 项，索引 = 当前星级）。
const SUCCESS_RATES: Array[float] = [
	1.0, 1.0, 1.0, 0.95, 0.90, 0.85, 0.80, 0.70, 0.60,
	0.50, 0.42, 0.35, 0.28, 0.22, 0.16, 0.10, 0.0,
]
## 当前星级 → 每次强化需要的副卡数量（17 项）。
const MATERIAL_COUNT: Array[int] = [
	1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 0,
]
## 当前星级 → 每次强化消耗的金币（17 项）。
const COIN_COST: Array[int] = [
	100, 200, 300, 500, 800, 1200, 1800, 2600, 3600, 5000,
	7000, 9000, 12000, 16000, 22000, 30000, 0,
]

## 强化保险金提供的成功率加成；保级符不提升成功率。
const INSURANCE_RATE_BONUS: float = 0.15

## 合成式强化固定的副卡数量：主卡 1 张 + 副卡 3 张 → 新卡（同类型、星级 +1）。
const COMBINE_MATERIAL_COUNT: int = 3
## 未来“强化消耗品”物品使用的标签；背包内带该标签的物品才可作为强化消耗品。
const CONSUMABLE_TAG: String = "强化消耗品"

## 强化道具在存档中的键名。
const ITEM_PROTECT: String = "protect_talisman"
const ITEM_INSURANCE: String = "insurance"

## 强化道具的中文名，供面板显示。
const ITEM_NAMES: Dictionary = {
	ITEM_PROTECT: "保级符",
	ITEM_INSURANCE: "强化保险金",
}


## 返回从 [param star] 强化到下一星的基础成功率；满星或越界返回 0。
static func get_success_rate(star: int) -> float:
	if star < 0 or star >= SUCCESS_RATES.size():
		return 0.0
	return SUCCESS_RATES[star]


## 返回从 [param star] 强化需要的副卡数量；满星或越界返回 0。
static func get_material_count(star: int) -> int:
	if star < 0 or star >= MATERIAL_COUNT.size():
		return 0
	return MATERIAL_COUNT[star]


## 返回从 [param star] 强化消耗的金币；满星或越界返回 0。
static func get_coin_cost(star: int) -> int:
	if star < 0 or star >= COIN_COST.size():
		return 0
	return COIN_COST[star]


## 返回 [param star] 是否已经是最高星级。
static func is_max_star(star: int) -> bool:
	return star >= MAX_STAR


## 返回 [param star] 强化失败时是否可能降星。
static func can_drop_star(star: int) -> bool:
	return star >= DROP_STAR_THRESHOLD and star > 0


## 返回 [param item_id] 的中文名；未知道具返回自身。
static func get_item_name(item_id: String) -> String:
	return str(ITEM_NAMES.get(item_id, item_id))
