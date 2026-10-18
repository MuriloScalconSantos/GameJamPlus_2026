extends CharacterBody3D

@export_group("Input")
@export var auto_detect_actions: bool = true
@export var fallback_to_wasd_keys: bool = true
@export var input_left: StringName = &""
@export var input_right: StringName = &""
@export var input_up: StringName = &""
@export var input_down: StringName = &""

@export_group("Velocidade")
@export var walk_speed: float = 5.0

@export_group("Aceleração e arraste")
@export var walk_acceleration: float = 28.0
@export var ground_friction: float = 22.0
@export var skid_deceleration: float = 55.0
@export var skid_min_speed: float = 3.5
@export_range(-1.0, 0.0) var skid_dot_threshold: float = -0.5
@export_range(0.0, 1.0) var air_control: float = 0.45
@export var air_drag: float = 1.5

@export_group("Sprite")
@export var sprite: SpriteBase3D
@export var hold_facing_while_skidding: bool = true
@export_range(0.0, 1.0) var facing_deadzone: float = 0.1

@export_group("Juice")
@export var visual: Node3D
@export var squash_stiffness: float = 220.0
@export var squash_damping: float = 14.0
@export var landing_squash_amount: float = 0.03
@export var landing_squash_max: float = 0.4
@export var skid_squash: float = 0.18
@export var bob_height: float = 0.06
@export var bob_frequency: float = 1.6

signal landed(impact_speed: float)
signal skid_started
signal facing_changed(facing_right: bool)

var _act_left: StringName = &""
var _act_right: StringName = &""
var _act_up: StringName = &""
var _act_down: StringName = &""

var _is_skidding: bool = false
var _facing_right: bool = true
var _use_scale_flip: bool = false
var _directional_sprite: AnimatedSprite3D
var _last_animation_direction: String = "down"

var _squash: float = 0.0
var _squash_velocity: float = 0.0

var _bob_time: float = 0.0
var _visual_base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_resolve_visuals()
	_resolve_inputs()


func _resolve_visuals() -> void:
	if sprite == null and visual is SpriteBase3D:
		sprite = visual as SpriteBase3D
	if sprite == null:
		var found: Array[Node] = find_children("*", "SpriteBase3D", true, false)
		if not found.is_empty():
			sprite = found[0] as SpriteBase3D
	if visual == null:
		visual = sprite

	if visual:
		_visual_base_position = visual.position

	_use_scale_flip = sprite == null
	if sprite is AnimatedSprite3D:
		var candidate: AnimatedSprite3D = sprite as AnimatedSprite3D
		var frames: SpriteFrames = candidate.sprite_frames
		if frames:
			var all_directions: bool = true
			for direction_name: String in ["down", "up", "left", "right"]:
				if not frames.has_animation("walk_" + direction_name) or not frames.has_animation("idle_" + direction_name):
						all_directions = false
						break
			if all_directions:
				_directional_sprite = candidate

	if sprite:
		if _directional_sprite:
			_directional_sprite.flip_h = false
			_directional_sprite.play(&"idle_down")
		else:
			sprite.flip_h = not _facing_right


func _resolve_inputs() -> void:
	_act_left = _resolve_action(input_left, KEY_A, PackedStringArray(["left", "esq"]))
	_act_right = _resolve_action(input_right, KEY_D, PackedStringArray(["right", "direita"]))
	_act_up = _resolve_action(input_up, KEY_W, PackedStringArray(["up", "forward", "front", "frente", "cima"]))
	_act_down = _resolve_action(input_down, KEY_S, PackedStringArray(["down", "back", "tras", "baixo"]))


func _resolve_action(manual: StringName, key: Key, hints: PackedStringArray) -> StringName:
	if manual != &"":
		if InputMap.has_action(manual):
			return manual
	if auto_detect_actions:
		return _find_action_for_key(key, hints)
	return &""


func _find_action_for_key(key: Key, hints: PackedStringArray) -> StringName:
	var fallback: StringName = &""
	for action: StringName in InputMap.get_actions():
		var action_name: String = String(action)
		if action_name.begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event: InputEventKey = event as InputEventKey
				if key_event.physical_keycode == key or key_event.keycode == key:
					var lower: String = action_name.to_lower()
					for hint: String in hints:
						if lower.contains(hint):
							return action
					if fallback == &"":
						fallback = action
	return fallback


func _axis(action: StringName, key: Key) -> float:
	if action != &"":
		return Input.get_action_strength(action)
	if fallback_to_wasd_keys and Input.is_physical_key_pressed(key):
		return 1.0
	return 0.0


func _read_move_input() -> Vector2:
	var result: Vector2 = Vector2(
		_axis(_act_right, KEY_D) - _axis(_act_left, KEY_A),
		_axis(_act_down, KEY_S) - _axis(_act_up, KEY_W)
	)
	return result.limit_length(1.0)


func _physics_process(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir: Vector2 = _read_move_input()
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	var has_input: bool = direction.length_squared() > 0.0001

	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var on_floor: bool = is_on_floor()
	var control: float = 1.0 if on_floor else air_control
	var accel: float = walk_acceleration * control

	if has_input:
		var speed: float = horizontal.length()
		var skidding_now: bool = false

		if on_floor and speed > skid_min_speed:
			var dot: float = horizontal.normalized().dot(direction.normalized())
			skidding_now = dot < skid_dot_threshold

		if skidding_now:
			horizontal = horizontal.move_toward(Vector3.ZERO, skid_deceleration * delta)
			if not _is_skidding:
				skid_started.emit()
				_squash_velocity += skid_squash * 12.0
		else:
			var target: Vector3 = direction * walk_speed
			horizontal = horizontal.move_toward(target, accel * delta)

		_is_skidding = skidding_now

		var keep_facing: bool = skidding_now and hold_facing_while_skidding
		if not keep_facing and absf(input_dir.x) > facing_deadzone:
			_set_facing(input_dir.x > 0.0)
	else:
		_is_skidding = false
		var friction: float = ground_friction if on_floor else air_drag
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var fall_speed: float = -velocity.y
	move_and_slide()

	if is_on_floor() and not was_on_floor:
		var impact: float = maxf(fall_speed, 0.0)
		landed.emit(impact)
		var amount: float = clampf(impact * landing_squash_amount, 0.0, landing_squash_max)
		_squash = maxf(_squash, amount)
		_squash_velocity = 0.0

	_update_juice(delta)
	_update_directional_animation(input_dir, has_input)


func _set_facing(facing_right: bool) -> void:
	if facing_right == _facing_right:
		return
	_facing_right = facing_right
	if sprite and not _directional_sprite:
		sprite.flip_h = not facing_right
	facing_changed.emit(facing_right)


func _update_directional_animation(input_dir: Vector2, has_input: bool) -> void:
	if not _directional_sprite:
		return

	var movement: Vector2 = Vector2(velocity.x, velocity.z)
	var moving: bool = has_input or movement.length_squared() > 0.04
	if moving:
		var facing_input: Vector2 = input_dir
		if not has_input or (_is_skidding and hold_facing_while_skidding):
			facing_input = movement
		if facing_input.length_squared() > 0.0001:
			if absf(facing_input.x) >= absf(facing_input.y):
				_last_animation_direction = "right" if facing_input.x > 0.0 else "left"
			else:
				_last_animation_direction = "down" if facing_input.y > 0.0 else "up"

	var animation_name: StringName = StringName(("walk_" if moving else "idle_") + _last_animation_direction)
	if _directional_sprite.animation != animation_name or not _directional_sprite.is_playing():
		_directional_sprite.play(animation_name)


func _update_juice(delta: float) -> void:
	if not visual:
		return

	var spring_force: float = -_squash * squash_stiffness - _squash_velocity * squash_damping
	_squash_velocity += spring_force * delta
	_squash += _squash_velocity * delta

	var flip: float = -1.0 if (_use_scale_flip and not _facing_right) else 1.0
	visual.scale = Vector3(
		(1.0 + _squash * 0.5) * flip,
		1.0 - _squash,
		1.0 + _squash * 0.5
	)

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(horizontal_speed / walk_speed, 0.0, 1.0)

	var bob: float = 0.0
	if is_on_floor() and speed_ratio > 0.05:
		_bob_time += delta * horizontal_speed * bob_frequency
		bob = absf(sin(_bob_time)) * bob_height * speed_ratio

	visual.position = _visual_base_position + Vector3(0.0, bob, 0.0)
