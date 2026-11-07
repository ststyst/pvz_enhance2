## 植物星级动画：按星级加载横向长条素材，拆帧为 SpriteFrames 并循环播放。[br]
## 素材位于 res://animation/star/，4~17 星各一张；其它星级只隐藏节点，不播放动画。[br]
## 该节点作为植物 body 的子节点挂载，因此共享 body 的翻转与染色表现。
extends AnimatedSprite2D
class_name StarLevelAnimation

## 支持的最低星级。
const STAR_MIN: int = 4
## 支持的最高星级。
const STAR_MAX: int = 17
## 星级动画的播放速度，单位为帧/秒。
const FPS: float = 12.0
## 相对 body 节点的位置偏移；星级动画整体悬浮在植物上方，可按美术效果调整。
const BODY_OFFSET: Vector2 = Vector2(0, 5)
## 每个星级只有一条循环动画，名称固定便于调试。
const ANIMATION_NAME: StringName = &"star"

## 星级 → 素材路径与总帧数；帧数由原始长条图决定，4、5 星只有一帧。
const STAR_ASSETS: Dictionary = {
	4: {"path": "res://animation/star/star_04.png", "frames": 1},
	5: {"path": "res://animation/star/star_05.png", "frames": 1},
	6: {"path": "res://animation/star/star_06.png", "frames": 8},
	7: {"path": "res://animation/star/star_07.png", "frames": 8},
	8: {"path": "res://animation/star/star_08.png", "frames": 8},
	9: {"path": "res://animation/star/star_09.png", "frames": 8},
	10: {"path": "res://animation/star/star_10.png", "frames": 8},
	11: {"path": "res://animation/star/star_11.png", "frames": 8},
	12: {"path": "res://animation/star/star_12.png", "frames": 8},
	13: {"path": "res://animation/star/star_13.png", "frames": 8},
	14: {"path": "res://animation/star/star_14.png", "frames": 8},
	15: {"path": "res://animation/star/star_15.png", "frames": 8},
	16: {"path": "res://animation/star/star_16.png", "frames": 8},
	17: {"path": "res://animation/star/star_17.png", "frames": 8},
}


## 返回 [param star] 是否有对应的星级动画资源。
static func is_supported(star: int) -> bool:
	return star >= STAR_MIN and star <= STAR_MAX and STAR_ASSETS.has(star)


## 按 [param star] 构建 SpriteFrames 并循环播放。[br]
## 越界星级或素材缺失时隐藏节点并返回 false；成功时显示节点并返回 true。
func setup(star: int) -> bool:
	# 无论是否支持都先归位，避免复用节点时停留在旧偏移。
	position = BODY_OFFSET
	z_index = 10
	if not is_supported(star):
		visible = false
		stop()
		return false
	# 当前星级的素材描述。
	var info: Dictionary = STAR_ASSETS[star]
	var texture := load(info["path"]) as Texture2D
	if texture == null:
		push_error("StarLevelAnimation：星级素材缺失：%s" % info["path"])
		visible = false
		stop()
		return false
	# 长条按等宽切帧；帧数来自素材表，不依赖图片尺寸推断。
	var frame_count: int = int(info["frames"])
	var frame_size := Vector2(texture.get_width() / float(frame_count), texture.get_height())
	sprite_frames = _build_frames(texture, frame_count, frame_size)
	visible = true
	play(ANIMATION_NAME)
	return true


## 把 [param texture] 按 [param frame_count] 等宽切成帧，返回循环动画的 SpriteFrames。[br]
## 使用 AtlasTexture 引用同一张贴图，不复制像素数据。
func _build_frames(texture: Texture2D, frame_count: int, frame_size: Vector2) -> SpriteFrames:
	var frames := SpriteFrames.new()
	# 新建的 SpriteFrames 自带 default 动画，这里替换成星级动画。
	frames.remove_animation(&"default")
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop(ANIMATION_NAME, true)
	frames.set_animation_speed(ANIMATION_NAME, FPS)
	for index: int in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(ANIMATION_NAME, atlas)
	return frames
