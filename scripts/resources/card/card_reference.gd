## 卡牌身份与植物模仿修饰；模板和关卡中的引用按只读使用，不保存费用或运行状态。
@tool
extends Resource
class_name ResourceCardReference

## 卡牌内容类别；编号用于选卡记录，新增类别时保持已有编号不变。
enum CardType {
	Null = 0, ## 编辑器中尚未配置的引用，不参与注册。
	Plant = 1, ## 植物卡牌。
	Zombie = 2, ## 普通僵尸卡牌。
	ZombieBoss = 3, ## 僵王卡牌，用于图鉴展示、普通卡槽和临时卡召唤。
}

## 内容类别；切换类别时清空角色编号，要求重新选择该类别的角色。
@export var card_type: CardType = CardType.Null:
	set(value):
		if card_type == value:
			return
		card_type = value
		content_id = 0
		if card_type != CardType.Plant:
			is_imitater = false
		notify_property_list_changed()
## 所选类别的角色枚举编号；0 表示未配置，不能用于生成卡牌。
@export var content_id: int = 0
## 植物模仿修饰；编号仍指向被模仿植物，不另注册模板。
@export var is_imitater: bool = false
## 植物卡牌星级；0 表示无星级（僵尸类或未配置），1~16 对应图形素材的帧号。
@export_range(0, 16, 1) var star_level: int = 0
## 背包内卡片的唯一标识；0 表示未分配。模板与关卡引用不参与分配，只有加入背包时才赋值。
var card_uid: int = 0


## 创建一份独立引用；[param type] 为卡牌类别，[param id] 为角色编号。[br]
## [param imitater] 仅适用于具体植物；[param star] 为植物星级，0 表示无星级。[br]
## 非法组合可由 [method is_valid] 检出。
static func create(type: int, id: int, imitater: bool = false, star: int = 0) -> ResourceCardReference:
	# 新引用不与模板或关卡共享可写属性。
	var card_ref := ResourceCardReference.new()
	# 类别可能来自存档整数，赋值时显式转换为卡牌枚举，合法性仍由 is_valid 判断。
	card_ref.card_type = type as CardType
	card_ref.content_id = id
	card_ref.is_imitater = imitater
	card_ref.star_level = star
	return card_ref


## 返回独立身份副本；显式构造确保类别先于角色编号赋值，不依赖 Resource 属性复制顺序。[br]
## 副本保留星级，但唯一 id 归零：加入背包时由背包服务重新分配，避免复制出重复 id。
func copy_reference() -> ResourceCardReference:
	return create(card_type, content_id, is_imitater, star_level)


## 返回是否为已定义的非空角色，模仿修饰不能用于其他类别或模仿者选择入口。[br]
## 星级不参与合法性校验：越界星级仍是一张有效卡，只在显示层隐藏星级图标。
func is_valid() -> bool:
	if content_id <= 0:
		return false
	if is_imitater and (card_type != CardType.Plant or content_id == CharacterRegistry.PlantType.P999Imitater):
		return false
	match card_type:
		CardType.Plant:
			return CharacterRegistry.PlantType.values().has(content_id)
		CardType.Zombie:
			return CharacterRegistry.ZombieType.values().has(content_id)
		CardType.ZombieBoss:
			return CharacterRegistry.ZombieBossType.values().has(content_id)
	return false


## 返回星级是否处于可显示区间：必须为植物且落在 1~16。[br]
## 越界星级、未配置星级和其它类别都返回 false，调用方据此隐藏星级图标。
func has_displayable_star() -> bool:
	return card_type == CardType.Plant and star_level >= 1 and star_level <= 16


## 返回模板身份的值键；普通卡和模仿卡共用目标植物模板。
func get_template_key() -> Vector2i:
	return Vector2i(card_type, content_id)


## 返回包含模仿修饰与星级的选卡值键，用于区分同一植物的不同星级和模仿版本。
func get_selection_key() -> Vector4i:
	return Vector4i(card_type, content_id, int(is_imitater), star_level)


## 返回可直接写入 JSON 的选卡数据，不将 Resource 对象交给 JSON 编码器。[br]
## 星级与唯一 id 一并写入，供背包按 id 精确删除。
func to_dict() -> Dictionary:
	return {
		"card_type": card_type,
		"content_id": content_id,
		"is_imitater": is_imitater,
		"star_level": star_level,
		"card_uid": card_uid,
	}


## 从当前格式还原引用；旧存档缺少星级或唯一 id 时套用默认值，非法值返回 null。[br]
## 植物缺少星级按 1 星补齐，唯一 id 缺失保持 0，由存档迁移统一补发。
static func from_dict(data: Dictionary) -> ResourceCardReference:
	# 逐个检查类别和角色编号字段；JSON 数字只接受有限整数，避免截断错误编号。
	for field: String in ["card_type", "content_id"]:
		# 当前字段的原始 JSON 值。
		var value: Variant = data.get(field)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return null
		if typeof(value) == TYPE_FLOAT and (not is_finite(value) or value != floor(value)):
			return null
	if typeof(data.get("is_imitater")) != TYPE_BOOL:
		return null
	# 已通过字段类型检查的新引用。
	var card_ref := create(int(data["card_type"]), int(data["content_id"]), data["is_imitater"])
	# 星级是新增字段：旧档缺失时植物按 1 星补齐；越界值原样保留，由显示层隐藏图标。
	var raw_star: Variant = data.get("star_level")
	if typeof(raw_star) == TYPE_INT or typeof(raw_star) == TYPE_FLOAT:
		card_ref.star_level = int(raw_star)
	elif card_ref.card_type == CardType.Plant:
		card_ref.star_level = 1
	# 唯一 id 同为新增字段，缺失时留 0 交给存档迁移补发。
	var raw_uid: Variant = data.get("card_uid")
	if typeof(raw_uid) == TYPE_INT or typeof(raw_uid) == TYPE_FLOAT:
		card_ref.card_uid = max(0, int(raw_uid))
	return card_ref if card_ref.is_valid() else null


## 为 [param property] 中的角色编号提供当前类别的枚举选项；不依赖运行中的 Global。
func _validate_property(property: Dictionary) -> void:
	if property.name != "content_id":
		return
	# 当前类别的角色枚举，包含空编号以便编辑未完成的配置。
	var content_types: Dictionary = {}
	match card_type:
		CardType.Plant:
			content_types = CharacterRegistry.PlantType
		CardType.Zombie:
			content_types = CharacterRegistry.ZombieType
		CardType.ZombieBoss:
			content_types = CharacterRegistry.ZombieBossType
	# 带显式数值的枚举文本，支持 999、1001 等非连续编号。
	var options := PackedStringArray()
	# 当前类别的角色名称用作选项标签，实际保存对应数字编号。
	for content_name: String in content_types:
		options.append("%s:%s" % [content_name, content_types[content_name]])
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(options)
