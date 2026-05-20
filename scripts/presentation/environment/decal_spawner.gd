class_name DecalSpawner
extends Node3D

## SPEC-GFX-002 (TBD): Decal 시스템
##
## walls/floor 영역에 paint/stain/dirt 데칼을 random_placement로 spawn.
## min_spacing 적용하여 데칼 간 간격 유지.
##
## 사용:
##   var spawner = DecalSpawner.new()
##   parent.add_child(spawner)
##   spawner.spawn_decals(bounds, 12)

const DECAL_TEXTURES: Array[String] = [
	"res://assets/textures/dirt/dirt_aerial_02_diff_1k.png",
	"res://assets/textures/paint_peeling/metal_plate_02_diff_1k.png",
	"res://assets/textures/rust/rust_coarse_01_diff_1k.png",
]

const DEFAULT_DECAL_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const MIN_SPACING_M: float = 1.5


## SPEC-GFX-002: bounds 영역 안에 count 개의 random 데칼을 spawn한다.
## min_spacing보다 가까운 위치는 skip하고 최대 spawn 시도 (count * 3) 횟수 제한.
## 반환: 실제 spawn된 데칼 수.
func spawn_decals(bounds: AABB, count: int, seed: int = 0) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()

	var placed_positions: Array[Vector3] = []
	var spawned: int = 0
	var max_attempts: int = count * 5

	for _i: int in range(max_attempts):
		if spawned >= count:
			break
		var pos: Vector3 = Vector3(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			bounds.position.y + 0.05,
			rng.randf_range(bounds.position.z, bounds.position.z + bounds.size.z),
		)
		var too_close: bool = false
		for p: Vector3 in placed_positions:
			if pos.distance_to(p) < MIN_SPACING_M:
				too_close = true
				break
		if too_close:
			continue

		var decal: Decal = _create_decal(rng)
		decal.position = pos
		decal.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		add_child(decal)
		placed_positions.append(pos)
		spawned += 1

	return spawned


func _create_decal(rng: RandomNumberGenerator) -> Decal:
	var decal: Decal = Decal.new()
	var tex_path: String = DECAL_TEXTURES[rng.randi_range(0, DECAL_TEXTURES.size() - 1)]
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex != null:
		decal.texture_albedo = tex
	var size_jitter: float = rng.randf_range(0.6, 1.4)
	decal.size = DEFAULT_DECAL_SIZE * size_jitter
	decal.modulate = Color(1.0, 1.0, 1.0, rng.randf_range(0.5, 0.9))
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	return decal
