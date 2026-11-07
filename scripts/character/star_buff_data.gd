## 植物星级永久加成表（全局常量）。[br]
## 结构：植物类型 → { "attribute": 加成属性, "operation": 乘区类型, "values": [17 个数值] }。[br]
## values 的下标就是星级 0~16，共 17 个元素；某个星级写 0 表示该星级不提供加成。[br]
## 植物未配置或星级越界时不施加任何加成，已有加成保持不变。[br]
## 填写示例：[br]
#CharacterRegistry.PlantType.P001PeaShooterSingle: {
	 #"attribute": CharacterAttributes.E_Attribute.Attack,
	 #"operation": CharacterAttributes.E_Operation.MultiplyBase,
	 #"values": [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
 #},
## 数值含义由乘区类型决定：Addition 为加值，MultiplyBase / MultiplyTotal 为比例（0.5 表示 +50%）。
extends RefCounted
class_name StarBuffData

## 每个植物配置的星级数量：0~16 星，共 17 个数值。
const STAR_COUNT: int = 17

## 植物星级加成配置；具体数据由项目维护者填写，未配置的植物不会获得加成。
const STAR_BUFFS: Dictionary = {
	 CharacterRegistry.PlantType.P001PeaShooterSingle: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P006SnowPea: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P008PeaShooterDouble: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P009PuffShroom: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P011FumeShroom: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P014ScaredyShroom: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P019ThreePeater: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P025SeaShroom: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P029SplitPea: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P030StarFruit: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P033CabbagePult: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P035CornPult: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P040MelonPult: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P041GatlingPea: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P043GloomShroom: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P044Cattail: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P045WinterMelon: {
	 "attribute": CharacterAttributes.E_Attribute.Attack,
	 "operation": CharacterAttributes.E_Operation.Addition,
	 "values": [20, 22, 24, 26, 30, 34, 38, 42, 46, 50, 60, 75, 90, 120, 150, 200, 250],
 },
	CharacterRegistry.PlantType.P002SunFlower: {
	 "attribute": CharacterAttributes.E_Attribute.ProductionRate,
	 "operation": CharacterAttributes.E_Operation.MultiplyBase,
	 "values": [0.15, 0.2, 0.25, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3, 1.6, 2.0, 2.4, 2.8, 3.2, 3.8, 4.5, 5.4],
 },
}


## 返回 [param plant_type] 的星级加成配置；未配置时返回空字典。
static func get_buff(plant_type: int) -> Dictionary:
	return STAR_BUFFS.get(plant_type, {})


## 返回 [param star] 星级对应的加成数值；星级越界或数组长度不符时返回 null。[br]
## 返回 0.0 表示该星级在表里配置为无加成，与“读取失败”区分开。
static func get_buff_value(config: Dictionary, star: int) -> Variant:
	var values: Variant = config.get("values", [])
	if not values is Array:
		return null
	# 下标即星级，因此只接受 0~STAR_COUNT-1 且落在数组范围内。
	if star < 0 or star >= STAR_COUNT or star >= (values as Array).size():
		return null
	return float(values[star])


## 返回配置是否完整可用：必须包含属性、乘区类型以及 17 个数值。
static func is_valid_config(config: Dictionary) -> bool:
	if config.is_empty():
		return false
	if not config.has("attribute") or not config.has("operation"):
		return false
	var values: Variant = config.get("values", [])
	return values is Array and (values as Array).size() == STAR_COUNT


## 校验整张表并返回错误描述；空数组表示全部合法，供填写数据后自检。
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for plant_type: Variant in STAR_BUFFS.keys():
		# 当前植物类型的配置；非字典或字段缺失都视为错误。
		var config: Variant = STAR_BUFFS[plant_type]
		if not config is Dictionary or not is_valid_config(config):
			errors.append("植物 %s 的星级加成配置不完整（需要 attribute/operation/values[%d]）" % [str(plant_type), STAR_COUNT])
	return errors
