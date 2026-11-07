## 角色实体属性集合：以基础值字典加修饰符层计算最终数值。[br]
## 修饰符参考 Minecraft 属性修饰词：同一个属性上可按 id 唯一添加修饰符，[br]
## 支持加法、基础乘区、总乘区三种运算，并可按来源批量移除，供 buff/装备系统使用。[br]
## 计算公式：final = (base + ΣAddition) × (1 + ΣMultiplyBase) × Π(1 + value_MultiplyTotal)
extends RefCounted
class_name CharacterAttributes

## 角色可拥有的属性类型；新增类型时追加在末尾，避免已有存档/代码编号错位。
enum E_Attribute {
	Attack, ## 攻击力
	Hp, ## 生命值
	AbilityPower, ## 增幅能力强度（乘法倍率，1 = 100%）
	Armor, ## 防具强度
	ProductionRate, ## 生产效率（乘法倍率，1 = 100%）
}

## 修饰符运算方式，对应 Minecraft 的三种 operation。
enum E_Operation {
	Addition, ## 加法：直接加到基础值上。
	MultiplyBase, ## 基础乘区：先累加该系数，再乘以基础值。
	MultiplyTotal, ## 总乘区：在最后结果上连乘 (1 + value)。
}

## 各属性的默认基础值；倍率类属性以 1 为中性值，加值类属性以 0 为中性值。
const DEFAULT_VALUES: Dictionary = {
	E_Attribute.Attack: 0.0,
	E_Attribute.Hp: 0.0,
	E_Attribute.AbilityPower: 1.0,
	E_Attribute.Armor: 0.0,
	E_Attribute.ProductionRate: 1.0,
}

## 属性中文名，供日志与界面显示。
const ATTRIBUTE_NAMES: Dictionary = {
	E_Attribute.Attack: "攻击力",
	E_Attribute.Hp: "生命值",
	E_Attribute.AbilityPower: "增幅能力强度",
	E_Attribute.Armor: "防具强度",
	E_Attribute.ProductionRate: "生产效率",
}

## 属性基础值字典；修饰符不写回这里，保证基础值与加成分离。
var base_values: Dictionary[E_Attribute, float] = {}
## 属性修饰符字典：属性 → 修饰符数组，元素为 {id, value, operation, source}。
var modifiers: Dictionary[E_Attribute, Array] = {}

## 某个属性的最终值发生变化；[param attribute] 为属性，[param old_value]/[param new_value] 为变化前后最终值。
signal attribute_changed(attribute: E_Attribute, old_value: float, new_value: float)


func _init() -> void:
	# 初始化每个属性的基础值与空修饰符列表，避免调用方判空。
	for attribute: E_Attribute in E_Attribute.values():
		base_values[attribute] = float(DEFAULT_VALUES.get(attribute, 0.0))
		modifiers[attribute] = []


## 返回 [param attribute] 的基础值；未知属性返回 0。
func get_base(attribute: E_Attribute) -> float:
	return base_values.get(attribute, 0.0)


## 设置 [param attribute] 的基础值，并广播最终值变化。
func set_base(attribute: E_Attribute, value: float) -> void:
	if not base_values.has(attribute):
		return
	var old_value := get_value(attribute)
	base_values[attribute] = value
	attribute_changed.emit(attribute, old_value, get_value(attribute))


## 返回 [param attribute] 叠加修饰符后的最终值。
func get_value(attribute: E_Attribute) -> float:
	if not base_values.has(attribute):
		return 0.0
	# 基础值先接受加法修饰，再分别应用基础乘区与总乘区。
	var total: float = base_values[attribute]
	var multiply_base: float = 0.0
	var multiply_total: float = 1.0
	for modifier: Dictionary in modifiers[attribute]:
		match int(modifier["operation"]):
			E_Operation.Addition:
				total += float(modifier["value"])
			E_Operation.MultiplyBase:
				multiply_base += float(modifier["value"])
			E_Operation.MultiplyTotal:
				multiply_total *= (1.0 + float(modifier["value"]))
	return total * (1.0 + multiply_base) * multiply_total


## 添加一条属性修饰符，返回是否为新添加（false 表示同 id 的旧修饰符被替换）。[br]
## [param id] 在同一属性内唯一，与 Minecraft 一致：重复 id 直接覆盖旧值和运算方式。[br]
## [param source] 是来源标签（如某个 buff 名），用于按来源批量移除。
func add_modifier(
	attribute: E_Attribute,
	id: String,
	value: float,
	operation: E_Operation = E_Operation.Addition,
	source: String = ""
) -> bool:
	if not base_values.has(attribute) or id.is_empty():
		return false
	# 本次修改前该属性的最终值，用于广播变化。
	var old_value := get_value(attribute)
	# 当前属性上的修饰符列表。
	var attribute_modifiers: Array = modifiers[attribute]
	# 是否命中同 id 修饰符；命中时替换而不是叠加。
	var replaced := false
	for index: int in attribute_modifiers.size():
		if attribute_modifiers[index]["id"] == id:
			attribute_modifiers[index] = {
				"id": id,
				"value": value,
				"operation": operation,
				"source": source,
			}
			replaced = true
			break
	if not replaced:
		attribute_modifiers.append({
			"id": id,
			"value": value,
			"operation": operation,
			"source": source,
		})
	attribute_changed.emit(attribute, old_value, get_value(attribute))
	return not replaced


## 移除 [param attribute] 上 id 为 [param id] 的修饰符，返回是否移除成功。
func remove_modifier(attribute: E_Attribute, id: String) -> bool:
	if not modifiers.has(attribute):
		return false
	# 当前属性上的修饰符列表。
	var attribute_modifiers: Array = modifiers[attribute]
	for index: int in attribute_modifiers.size():
		if attribute_modifiers[index]["id"] == id:
			var old_value := get_value(attribute)
			attribute_modifiers.remove_at(index)
			attribute_changed.emit(attribute, old_value, get_value(attribute))
			return true
	return false


## 按来源移除所有属性上的修饰符，返回移除数量；buff 结束时常用。
func remove_modifiers_by_source(source: String) -> int:
	if source.is_empty():
		return 0
	var removed := 0
	for attribute: E_Attribute in modifiers.keys():
		# 当前属性上的修饰符列表。
		var attribute_modifiers: Array = modifiers[attribute]
		var old_value := get_value(attribute)
		var before_size := attribute_modifiers.size()
		# 倒序遍历，删除后不影响未检查的下标。
		for index: int in range(attribute_modifiers.size() - 1, -1, -1):
			if attribute_modifiers[index]["source"] == source:
				attribute_modifiers.remove_at(index)
		var removed_here := before_size - attribute_modifiers.size()
		if removed_here > 0:
			removed += removed_here
			attribute_changed.emit(attribute, old_value, get_value(attribute))
	return removed


## 清空 [param attribute] 上的全部修饰符。
func clear_modifiers(attribute: E_Attribute) -> void:
	if not modifiers.has(attribute):
		return
	var old_value := get_value(attribute)
	(modifiers[attribute] as Array).clear()
	attribute_changed.emit(attribute, old_value, get_value(attribute))


## 返回 [param attribute] 上是否已有 id 为 [param id] 的修饰符。
func has_modifier(attribute: E_Attribute, id: String) -> bool:
	if not modifiers.has(attribute):
		return false
	for modifier: Dictionary in modifiers[attribute]:
		if modifier["id"] == id:
			return true
	return false


## 返回 [param attribute] 上的修饰符数组副本；[param deep] 为 true 时同时复制每条记录。
func get_modifiers(attribute: E_Attribute, deep: bool = false) -> Array:
	if not modifiers.has(attribute):
		return []
	var result: Array = (modifiers[attribute] as Array).duplicate(true if deep else false)
	return result


## 返回全部属性的最终值，便于调试与界面展示。
func get_all_values() -> Dictionary[E_Attribute, float]:
	var values: Dictionary[E_Attribute, float] = {}
	for attribute: E_Attribute in base_values.keys():
		values[attribute] = get_value(attribute)
	return values


## 返回属性的中文名；未知属性返回空字符串。
static func get_attribute_name(attribute: E_Attribute) -> String:
	return str(ATTRIBUTE_NAMES.get(attribute, ""))
