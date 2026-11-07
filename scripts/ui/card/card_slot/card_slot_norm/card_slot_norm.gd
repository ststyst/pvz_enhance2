## 普通卡槽负责选择、重选与预选，所有内容统一使用卡牌引用。
extends Control
class_name CardSlotNorm

## 本局选卡读取的背包键；空字符串表示使用 Global 当前背包。
var backpack_key: String = ""

## 移动选卡时的临时挂载节点，防止卡片被原卡槽遮挡。
@onready var temporary_card: Control = $TemporaryCard
## 备选卡页面与返回容器的管理节点。
@onready var card_slot_candidate: CardSlotCandidate = $CardSlotCandidate
## 出战卡槽及阳光结算节点。
@onready var card_slot_battle: CardSlotBattle = $CardSlotBattle

## 在场景入树前写入选卡背包键；候选页在 _ready 构建，必须在 add_child 之前调用。[br]
## [param key] 为空表示使用 Global 当前背包。
func set_backpack_key_before_ready(key: String) -> void:
	backpack_key = key
	# 此时 @onready 引用尚未赋值，直接按节点路径写入。
	var candidate := get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	if candidate != null:
		candidate.set_backpack_key(key)


## 运行期设置选卡背包键；已构建的候选页不会重建，供调试或下一局使用。
func set_backpack_key(key: String) -> void:
	backpack_key = key
	if card_slot_candidate != null:
		card_slot_candidate.set_backpack_key(key)


## 使用 [param game_para] 初始化槽位、候选点击信号和不可取消的预选卡。
func init_card_slot_norm(game_para: ResourceLevelData) -> void:
	card_slot_battle.init_card_slot_battle(game_para.max_choosed_card_num, game_para.start_sun)
	# 候选容器覆盖重复卡片，逐个连接点击处理。
	for container: CardCandidateContainer in card_slot_candidate.candidate_containers:
		if container.card.card_reference.is_imitater:
			container.card.signal_card_click.connect(_on_imitater_card_click)
		else:
			container.card.signal_card_click.connect(_on_card_click)
	if not game_para.prechosen_cards.is_empty():
		init_pre_choosed_card(game_para.prechosen_cards)

## 读取上次的统一选卡引用，只恢复仍可出战且存在于本次候选页的内容。
func _on_re_card_button_pressed() -> void:
	Global.save_service.load_selected_cards()
	# 上次选卡的引用只读，候选卡拥有自己的引用副本。
	for reference: ResourceCardReference in Global.global_game_state.selected_cards:
		if not AllCards.is_battle_card(reference):
			continue
		# 同一模板只能带一张，已恢复同类卡片时跳过后续重复引用。
		if _has_template_selected(reference):
			continue
		# 根据完整选择键同时区分普通植物和模仿植物。
		var container: CardCandidateContainer = card_slot_candidate.get_candidate(reference)
		if container == null or not container.visible or container.card.is_choosed_pre_card:
			continue
		if reference.is_imitater and card_slot_candidate.card_imitater.is_be_choosed_imitater:
			continue
		container.card._on_button_pressed()

## 倒序取消已选卡片；未连接点击信号的系统预选卡保持不变。
func _on_cancal_card_button_pressed() -> void:
	# 倒序取消避免移动后改变后续索引。
	for index: int in range(card_slot_battle.curr_cards.size() - 1, -1, -1):
		card_slot_battle.curr_cards[index]._on_button_pressed()

## 开始游戏并保存独立的选卡引用，由 SaveService 统一序列化。
func _on_texture_button_pressed() -> void:
	EventBus.push_event("card_slot_norm_start_game")
	Global.global_game_state.selected_cards.clear()
	# 保存引用副本，避免运行中的卡片修改影响持久化身份。
	for card: Card in card_slot_battle.curr_cards:
		Global.global_game_state.selected_cards.append(card.card_reference.copy_reference())
	Global.save_service.save_selected_cards()

## 按 [param references] 的顺序创建不可取消的预选卡；无效或未注册的出战引用不会进入卡槽。
func init_pre_choosed_card(references: Array[ResourceCardReference]) -> void:
	# 单个预选引用表示一个完整卡片，不再依赖两个补零数组的同下标组合。
	for reference: ResourceCardReference in references:
		if not AllCards.is_battle_card(reference):
			push_error("CardSlotNorm：预选卡必须是已注册的出战卡牌。")
			continue
		if card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
			break
		# 隐藏对应的候选卡，保持预选卡不可取消。
		var container: CardCandidateContainer = card_slot_candidate.get_candidate(reference)
		if container != null:
			container.card.visible = false
			container.card.is_choosed_pre_card = true
		# 实际出战卡是独立实例；开始战斗时再切换上下文。
		var card: Card = AllCards.create_card(reference, Card.CardContext.Selection)
		if card == null:
			continue
		card_slot_battle.curr_cards.append(card)
		pre_choosed_card(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size() - 1])
		# 预选卡同样占用该模板，其余同类候选卡本局不可再选。
		card_slot_candidate.set_template_blocked(reference, true)
		if reference.is_imitater:
			card_slot_candidate.imitater_be_choosed()
	card_disconnect_click_in_choose()

## 返回 [param reference] 的同模板卡片是否已在出战卡槽中。[br]
## 模板键忽略模仿修饰，因此普通卡与模仿卡视为同一种卡片。
func _has_template_selected(reference: ResourceCardReference) -> bool:
	if reference == null:
		return false
	var template_key := reference.get_template_key()
	for card: Card in card_slot_battle.curr_cards:
		if card.card_reference != null and card.card_reference.get_template_key() == template_key:
			return true
	return false

## 返回当前是否处于开局选卡或下一轮重选阶段。
func _is_choosing() -> bool:
	return Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD \
		or Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD

## [param card] 的正常选择信号；只接纳具有出战能力的卡片。[br]
## 同一模板只能选一张：选中后禁用其余同类候选卡，取消后统一恢复。
func _on_card_click(card: Card) -> void:
	if not _is_choosing() or not AllCards.is_battle_card(card.card_reference):
		return
	# 同类卡片已被选中时拒绝再次选择，避免同一植物重复出战。
	if card.is_selection_blocked:
		return
	SoundManager.play_other_SFX("tap")
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		# 取消后恢复所有同类候选卡，玩家可以改选另一张。
		card_slot_candidate.set_template_blocked(card.card_reference, false)
		# 移除后从原位置开始将后续卡片向前移动。
		var card_index: int = card_slot_battle.curr_cards.find(card)
		card_slot_battle.curr_cards.erase(card)
		# 需要重新定位的出战卡索引。
		for index: int in range(card_index, card_slot_battle.curr_cards.size()):
			move_card_to(card_slot_battle.curr_cards[index], card_slot_battle.cards_placeholder[index])
		move_card_to(card, card.card_candidate_container)
	elif card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
		SoundManager.play_other_SFX("buzzer")
	elif _has_template_selected(card.card_reference):
		SoundManager.play_other_SFX("buzzer")
	else:
		card.is_choosed_pre_card = true
		card_slot_battle.curr_cards.append(card)
		# 其余同类卡片本局不可再选，直到取消这张卡。
		card_slot_candidate.set_template_blocked(card.card_reference, true)
		move_card_to(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size() - 1])

## [param card] 的模仿植物选择信号；独立入口本身不作为出战卡。[br]
## 模仿卡与普通卡共享植物模板，因此同样受同类互斥限制。
func _on_imitater_card_click(card: Card) -> void:
	if not _is_choosing() or not AllCards.is_battle_card(card.card_reference):
		return
	# 同类卡片已被选中时拒绝再次选择。
	if card.is_selection_blocked:
		return
	SoundManager.play_other_SFX("tap")
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		# 取消后恢复所有同类候选卡。
		card_slot_candidate.set_template_blocked(card.card_reference, false)
		# 原索引用于重新排列后续卡片。
		var card_index: int = card_slot_battle.curr_cards.find(card)
		card_slot_battle.curr_cards.erase(card)
		# 需要重新定位的出战卡索引。
		for index: int in range(card_index, card_slot_battle.curr_cards.size()):
			move_card_to(card_slot_battle.curr_cards[index], card_slot_battle.cards_placeholder[index])
		await move_card_to(card, card_slot_candidate.card_imitater)
		card.reparent(card.card_candidate_container, false)
		card_slot_candidate.imitater_be_choosed_cancel()
	elif card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
		SoundManager.play_other_SFX("buzzer")
		card_slot_candidate.imitater_card_slot_disappear()
	elif _has_template_selected(card.card_reference):
		SoundManager.play_other_SFX("buzzer")
		card_slot_candidate.imitater_card_slot_disappear()
	elif not card_slot_candidate.card_imitater.is_be_choosed_imitater:
		card.is_choosed_pre_card = true
		card_slot_battle.curr_cards.append(card)
		# 其余同类卡片本局不可再选，直到取消这张卡。
		card_slot_candidate.set_template_blocked(card.card_reference, true)
		card.reparent(card_slot_candidate.card_imitater, false)
		move_card_to(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size() - 1])
		card_slot_candidate.imitater_be_choosed()

## 将 [param card] 动画移动到 [param target_parent] 的全局位置，再重新挂载。
## 移动期间暂停按钮鼠标交互，耗时保持为 0.2 秒。
func move_card_to(card: Card, target_parent: Control) -> void:
	card.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.reparent(temporary_card)
	# 临时挂载后的移动动画。
	var tween: Tween = create_tween()
	tween.tween_property(card, "global_position", target_parent.global_position, 0.2)
	await tween.finished
	card.reparent(target_parent)
	card.button.mouse_filter = Control.MOUSE_FILTER_PASS

## 预选卡不连接选择处理；如存在已连接处理则解除，保持不可取消。
func card_disconnect_click_in_choose() -> void:
	# 系统预选卡不会恢复为候选卡。
	for card: Card in card_slot_battle.curr_cards:
		if card.signal_card_click.is_connected(_on_card_click):
			card.signal_card_click.disconnect(_on_card_click)
		if card.signal_card_click.is_connected(_on_imitater_card_click):
			card.signal_card_click.disconnect(_on_imitater_card_click)

## 将 [param card] 挂到 [param target_parent]；罐子模式仍保留原有零冷却规则。
func pre_choosed_card(card: Card, target_parent: Control) -> void:
	target_parent.add_child(card)
	card.position = Vector2.ZERO
	if Global.main_game.game_para.is_pot_mode:
		match card.card_reference.card_type:
			ResourceCardReference.CardType.Plant:
				if Global.global_read_data.zero_cd_plnat_card_type_on_pot_mode.has(card.card_reference.content_id):
					card.card_change_cool_time(0)
			ResourceCardReference.CardType.Zombie:
				card.card_change_cool_time(0)

## 根据 [param is_appeal] 显示或隐藏候选卡槽，等待原有 0.2 秒移动完成。
func move_card_slot_candidate(is_appeal: bool) -> void:
	# 候选卡槽位移动画。
	var tween: Tween = create_tween()
	tween.tween_property(card_slot_candidate, "position", Vector2(0, 89.0) if is_appeal else Vector2(0, 615.0), 0.2)
	await tween.finished

## 根据 [param is_appeal] 移动出战卡槽；[param appeal_time] 是动画耗时，单位秒。
func move_card_slot_battle(is_appeal: bool, appeal_time: float = 0.2) -> void:
	# 出战卡槽位移动画。
	var tween: Tween = create_tween()
	tween.tween_property(card_slot_battle, "position", Vector2(0, 0) if is_appeal else Vector2(0, -100.0), appeal_time)
	await tween.finished

