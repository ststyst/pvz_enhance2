## 玩家背包服务：以键值对管理同一存档内的多个卡片背包，植物卡牌即装备。[br]
## 背包集合、当前背包与卡片增减都落在 [GlobalGameState] 上，由 SaveService 统一序列化。[br]
## 同一背包允许重复条目，因此玩家可以持有多张相同卡片；选卡按背包键读取，只有背包内的植物会进入候选页。
extends Node
class_name BackpackService

## 某个背包内容发生变化；[param backpack_key] 是发生变化的背包键。
signal backpack_changed(backpack_key: String)
## 当前背包发生切换；[param backpack_key] 是新的当前背包键。
signal curr_backpack_changed(backpack_key: String)

## 与 Global 根下的其它服务同级，用唯一名引用，避免依赖兄弟节点顺序。
@onready var global_game_state: GlobalGameState = %GlobalGameState

## 同一帧内的落盘排队标记，避免批量增减卡片反复写文件。
var _save_queued: bool = false

## 默认背包键；与 GlobalGameState.DEFAULT_BACKPACK_KEY 保持一致（跨类常量引用不能作为常量表达式）。
const DEFAULT_BACKPACK_KEY: String = "default"


## 返回运行态；节点尚未就绪时回退到 Global 门面，便于初始化早期调用。
func _state() -> GlobalGameState:
	if global_game_state != null:
		return global_game_state
	if Global != null:
		return Global.global_game_state
	return null


## 保证至少存在一个背包；背包集合为空时用上次出战卡或当前可用植物填充默认背包。[br]
## 已存在背包时不做任何修改，因此重复调用是安全的；不写存档，由调用方决定何时持久化。
func ensure_default_backpack() -> bool:
	return seed_default_backpack(_state())


## 纯状态补建：背包集合为空时用上次出战卡或当前可用植物填充默认背包。[br]
## 供服务与存档读取共用，不依赖节点就绪；已存在背包时不做任何修改并返回 false。
static func seed_default_backpack(state: GlobalGameState) -> bool:
	if state == null:
		return false
	if not state.backpacks.is_empty():
		return false
	# 默认背包的初始内容，优先沿用上次出战卡以保持玩家预期。
	var default_cards: Array[ResourceCardReference] = []
	for reference: ResourceCardReference in state.selected_cards:
		if reference != null and reference.is_valid():
			default_cards.append(reference.copy_reference())
	if default_cards.is_empty():
		for plant_type: CharacterRegistry.PlantType in state.curr_plant:
			default_cards.append(ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type))
	# 补建出来的卡片同样需要唯一 id，删除功能才能精确定位。
	var next_uid: int = max(1, state.next_card_uid)
	for card: ResourceCardReference in default_cards:
		card.card_uid = next_uid
		next_uid += 1
	state.next_card_uid = next_uid
	state.backpacks[DEFAULT_BACKPACK_KEY] = default_cards
	if state.curr_backpack_key.is_empty() or not state.backpacks.has(state.curr_backpack_key):
		state.curr_backpack_key = DEFAULT_BACKPACK_KEY
	return true


## 返回解析后的背包键：空键取当前背包，键不存在时回退到默认或首个背包。[br]
## 返回空字符串表示运行态不可用。
func resolve_backpack_key(backpack_key: String = "", state: GlobalGameState = null) -> String:
	# 调用方传入的运行态可避免重复查询，加载阶段也能复用。
	var curr_state := state if state != null else _state()
	if curr_state == null:
		return ""
	ensure_default_backpack()
	# 空键表示“当前背包”，非空键仍需回退到有效背包。
	var key: String = backpack_key if not backpack_key.is_empty() else curr_state.curr_backpack_key
	if key.is_empty() or not curr_state.backpacks.has(key):
		# 候选回退顺序：默认背包优先，其次是首个登记背包。
		key = DEFAULT_BACKPACK_KEY if curr_state.backpacks.has(DEFAULT_BACKPACK_KEY) else String(curr_state.backpacks.keys()[0])
	return key


## 返回选卡应读取的背包键；[param preferred_key] 为空时使用当前背包。
func get_selection_backpack_key(preferred_key: String = "") -> String:
	return resolve_backpack_key(preferred_key)


## 严格解析：显式键不存在时返回空字符串，避免误写其它背包；空键仍取当前背包。[br]
## 增减卡片等写操作使用本函数；读操作使用 [method resolve_backpack_key] 的回退语义。
func resolve_existing_backpack_key(backpack_key: String = "", state: GlobalGameState = null) -> String:
	# 调用方传入的运行态可避免重复查询。
	var curr_state := state if state != null else _state()
	if curr_state == null:
		return ""
	ensure_default_backpack()
	if backpack_key.is_empty():
		return resolve_backpack_key("", curr_state)
	if not curr_state.backpacks.has(backpack_key):
		return ""
	return backpack_key


#region 背包管理

## 返回全部背包键，顺序为登记顺序；运行态不可用时返回空列表。
func get_backpack_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	var state := _state()
	if state == null:
		return keys
	ensure_default_backpack()
	for key: String in state.backpacks.keys():
		keys.append(key)
	return keys


## 返回是否存在 [param backpack_key] 背包；空键表示当前背包。[br]
## 只检查真实登记，不做回退，因此不存在的键会返回 false。
func has_backpack(backpack_key: String = "") -> bool:
	var state := _state()
	if state == null:
		return false
	ensure_default_backpack()
	if backpack_key.is_empty():
		return state.backpacks.has(resolve_backpack_key("", state))
	return state.backpacks.has(backpack_key)


## 新增一个空背包；键为空或已存在时返回 false。[br]
## [param copy_from] 非空时把该背包内容复制进新背包，用独立引用副本，不共享条目。
func add_backpack(backpack_key: String, copy_from: String = "") -> bool:
	var state := _state()
	if state == null:
		return false
	# 去除首尾空白，避免“看起来同名”的背包键。
	var key := backpack_key.strip_edges()
	if key.is_empty():
		push_warning("BackpackService：背包键不能为空，已忽略新增请求。")
		return false
	ensure_default_backpack()
	if state.backpacks.has(key):
		push_warning("BackpackService：背包已存在，已忽略新增请求：%s" % key)
		return false
	var cards: Array[ResourceCardReference] = []
	if not copy_from.is_empty():
		for reference: ResourceCardReference in get_backpack(copy_from):
			# 复制背包时每张卡都视为新实体，副本的 id 由下面统一重新分配。
			cards.append(reference.copy_reference())
	state.backpacks[key] = cards
	_assign_missing_card_uids(state)
	_notify_backpack_changed(key)
	return true


## 删除背包；删除当前背包后自动切到剩余的首个背包。[br]
## 始终保留至少一个背包，删除最后一个背包返回 false。
func remove_backpack(backpack_key: String) -> bool:
	var state := _state()
	if state == null:
		return false
	if backpack_key.is_empty() or not state.backpacks.has(backpack_key):
		return false
	if state.backpacks.size() <= 1:
		push_warning("BackpackService：至少需要保留一个背包，已忽略删除请求。")
		return false
	state.backpacks.erase(backpack_key)
	# 当前背包被删除时把当前键切到仍存在的背包。
	if state.curr_backpack_key == backpack_key:
		state.curr_backpack_key = String(state.backpacks.keys()[0])
		curr_backpack_changed.emit(state.curr_backpack_key)
	_notify_backpack_changed(backpack_key)
	return true


## 清空背包内容但保留背包本身；返回被清空的卡片数量。
func clear_backpack(backpack_key: String = "") -> int:
	var state := _state()
	if state == null:
		return 0
	var key := resolve_existing_backpack_key(backpack_key, state)
	if key.is_empty():
		return 0
	var removed := get_backpack(key).size()
	var empty_cards: Array[ResourceCardReference] = []
	state.backpacks[key] = empty_cards
	_notify_backpack_changed(key)
	return removed


## 设置当前背包；键不存在时返回 false。
func set_curr_backpack(backpack_key: String) -> bool:
	var state := _state()
	if state == null:
		return false
	ensure_default_backpack()
	if not state.backpacks.has(backpack_key):
		return false
	if state.curr_backpack_key == backpack_key:
		return true
	state.curr_backpack_key = backpack_key
	curr_backpack_changed.emit(backpack_key)
	_persist()
	return true


## 返回当前背包键；运行态不可用时返回空字符串。
func get_curr_backpack_key() -> String:
	var state := _state()
	if state == null:
		return ""
	return resolve_backpack_key("", state)

#endregion

#region 卡片增减

## 返回背包内的卡片引用列表；空键表示当前背包。[br]
## 返回的是独立数组，但元素仍与背包共享引用对象，修改身份请通过本服务的增减接口。
func get_backpack(backpack_key: String = "") -> Array[ResourceCardReference]:
	var cards: Array[ResourceCardReference] = []
	var state := _state()
	if state == null:
		return cards
	var key := resolve_existing_backpack_key(backpack_key, state)
	if key.is_empty():
		return cards
	for card: Variant in state.backpacks[key]:
		if card is ResourceCardReference:
			cards.append(card)
	return cards


## 返回背包内容的值副本，调用方可自由修改，不影响存档。
func get_backpack_copy(backpack_key: String = "") -> Array[ResourceCardReference]:
	var copies: Array[ResourceCardReference] = []
	for reference: ResourceCardReference in get_backpack(backpack_key):
		copies.append(reference.copy_reference())
	return copies


## 返回背包内的卡片总数；空键表示当前背包。
func get_backpack_size(backpack_key: String = "") -> int:
	return get_backpack(backpack_key).size()


## 返回背包内与 [param reference] 同模板的卡片数量；模仿修饰不参与计数，用于判断“是否拥有该植物”。
func count_card(backpack_key: String, reference: ResourceCardReference) -> int:
	if reference == null:
		return 0
	# 目标模板身份，忽略模仿修饰与具体副本。
	var target := reference.get_template_key()
	var count := 0
	for card: ResourceCardReference in get_backpack(backpack_key):
		if card.get_template_key() == target:
			count += 1
	return count


## 返回背包内是否存在 [param reference]；空键表示当前背包。
func has_card(backpack_key: String, reference: ResourceCardReference) -> bool:
	return count_card(backpack_key, reference) > 0


## 追加 [param count] 张相同卡片，返回追加后该模板的持有数量。[br]
## 允许重复条目，因此同一植物可以持有多张；引用以独立副本保存。
func add_card(backpack_key: String, reference: ResourceCardReference, count: int = 1) -> int:
	var state := _state()
	if state == null or reference == null or not reference.is_valid() or count <= 0:
		return 0
	var key := resolve_existing_backpack_key(backpack_key, state)
	if key.is_empty():
		return 0
	var cards := get_backpack(key)
	# 每张卡片都是独立引用，避免共享可写属性；唯一 id 稍后统一分配。
	for _index: int in count:
		cards.append(reference.copy_reference())
	state.backpacks[key] = cards
	_assign_missing_card_uids(state)
	_notify_backpack_changed(key)
	return count_card(key, reference)


## 从背包移除最多 [param count] 张相同卡片，返回实际移除数量；空键表示当前背包。[br]
## 从列表尾部开始移除，保持剩余条目顺序。
func remove_card(backpack_key: String, reference: ResourceCardReference, count: int = 1) -> int:
	var state := _state()
	if state == null or reference == null or count <= 0:
		return 0
	var key := resolve_existing_backpack_key(backpack_key, state)
	if key.is_empty():
		return 0
	var cards := get_backpack(key)
	var target := reference.get_template_key()
	var removed := 0
	# 倒序遍历避免删除后索引前移。
	for index: int in range(cards.size() - 1, -1, -1):
		if removed >= count:
			break
		if cards[index].get_template_key() == target:
			cards.remove_at(index)
			removed += 1
	if removed > 0:
		state.backpacks[key] = cards
		_notify_backpack_changed(key)
	return removed


## 移除背包内全部同模板卡片，返回移除数量。
func remove_all_cards(backpack_key: String, reference: ResourceCardReference) -> int:
	return remove_card(backpack_key, reference, 2147483647)


## 把植物卡片加入背包，返回加入后该植物的持有数量；[param plant_type] 取 [enum CharacterRegistry.PlantType]。[br]
## [param star_level] 是该卡片的星级（1~16），不同星级的同种植物互相独立。
func add_plant_card(backpack_key: String, plant_type: int, count: int = 1, star_level: int = 1) -> int:
	return add_card(
		backpack_key,
		ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type, false, star_level),
		count
	)


## 从背包移除植物卡片，返回实际移除数量。[br]
## 该接口按模板删除，会移除任意星级的同种卡；需要精确删除某一张时请用 [method remove_card_by_uid]。
func remove_plant_card(backpack_key: String, plant_type: int, count: int = 1) -> int:
	return remove_card(backpack_key, ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type), count)


## 按唯一 id 删除背包内的一张卡片，返回是否删除成功。[br]
## 星级与重复卡不影响定位：只会删除 id 匹配的那一张，避免误删不同星级的同种卡。
func remove_card_by_uid(backpack_key: String, card_uid: int) -> bool:
	var state := _state()
	if state == null or card_uid <= 0:
		return false
	var key := resolve_existing_backpack_key(backpack_key, state)
	if key.is_empty():
		return false
	var cards := get_backpack(key)
	for index: int in range(cards.size() - 1, -1, -1):
		if cards[index].card_uid == card_uid:
			cards.remove_at(index)
			state.backpacks[key] = cards
			_notify_backpack_changed(key)
			return true
	return false


## 按唯一 id 查找背包内的卡片，未找到返回 null。[br]
## 返回的是背包内的同一引用对象，请勿直接修改其身份字段。
func get_card_by_uid(backpack_key: String, card_uid: int) -> ResourceCardReference:
	for card: ResourceCardReference in get_backpack(backpack_key):
		if card.card_uid == card_uid:
			return card
	return null


## 返回背包内全部卡片的唯一 id；顺序与背包内容一致。
func get_card_uids(backpack_key: String = "") -> PackedInt32Array:
	var uids := PackedInt32Array()
	for card: ResourceCardReference in get_backpack(backpack_key):
		uids.append(card.card_uid)
	return uids

#endregion


## 为所有缺少唯一 id 的卡片补发 id，并推进 next_card_uid。[br]
## 新增卡片先以 0 加入背包，再统一分配，保证同批次与已有卡片都不会拿到重复 id。
func _assign_missing_card_uids(state: GlobalGameState) -> void:
	# 已被占用的 id 集合，包含其它背包里的卡片。
	var used_uids: Dictionary = {}
	for backpack_key: String in state.backpacks.keys():
		for card: Variant in state.backpacks[backpack_key]:
			if card is ResourceCardReference and card.card_uid > 0:
				used_uids[card.card_uid] = true
	# 下一个可用 id 从存档计数器继续，至少为 1。
	var next_uid: int = max(1, state.next_card_uid)
	for backpack_key: String in state.backpacks.keys():
		for card: Variant in state.backpacks[backpack_key]:
			if not card is ResourceCardReference:
				continue
			if card.card_uid > 0:
				continue
			# 跳过已被占用的号段，避免手动改档后出现重复 id。
			while used_uids.has(next_uid):
				next_uid += 1
			card.card_uid = next_uid
			used_uids[next_uid] = true
			next_uid += 1
	state.next_card_uid = next_uid


## 在 [param backpack_key] 的内容被外部直接修改后调用，广播变化并请求写档。[br]
## 用于强化等直接改写卡片字段的流程，避免绕过信号与保存。
func mark_backpack_changed(backpack_key: String = "") -> void:
	var state := _state()
	if state == null:
		return
	var key := resolve_existing_backpack_key(backpack_key, state)
	if key.is_empty():
		return
	_notify_backpack_changed(key)


## 广播背包变化并请求写回存档；同一帧内的多次变化会合并为一次落盘。
func _notify_backpack_changed(backpack_key: String) -> void:
	backpack_changed.emit(backpack_key)
	_persist()


## 立即保存全局存档；未登录或服务不可用时安全跳过。[br]
## 同一帧内多次增减只落盘一次，避免批量操作反复写文件。
func _persist() -> void:
	if _save_queued:
		return
	_save_queued = true
	_flush_save.call_deferred()


## 延迟落盘的实际执行体；重置排队标记后写回完整全局存档。
func _flush_save() -> void:
	_save_queued = false
	if Global == null:
		return
	if Global.save_service == null:
		return
	Global.save_service.save_now()
