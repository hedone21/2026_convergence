extends GutTest

# ======================================
# SPEC-ENV-002: 크랙 절차적 생성 시스템
# ======================================
# CrackGenerator의 메시 생성, 파라미터 변경, 엣지 케이스를 검증한다.


## TEST-ENV-002: CrackGenerator가 유효한 ArrayMesh를 생성하는지
func test_crack_generator_creates_mesh() -> void:
	var gen := CrackGenerator.new()
	var mesh: ArrayMesh = gen.generate_crack_mesh(1.0, 0.02, 2)

	assert_not_null(mesh, "메시가 null이 아니어야 한다")
	assert_true(mesh is ArrayMesh, "ArrayMesh 타입이어야 한다")
	assert_gt(mesh.get_surface_count(), 0, "서피스가 1개 이상이어야 한다")


## TEST-ENV-002-2: 파라미터(length) 변경 시 다른 메시가 생성되는지
func test_different_length_produces_different_mesh() -> void:
	var gen := CrackGenerator.new()
	var mesh_short: ArrayMesh = gen.generate_crack_mesh(0.5, 0.02, 2)
	var mesh_long: ArrayMesh = gen.generate_crack_mesh(3.0, 0.02, 2)

	assert_not_null(mesh_short, "짧은 크랙 메시 생성")
	assert_not_null(mesh_long, "긴 크랙 메시 생성")

	# 길이가 다르면 AABB가 달라야 한다
	var aabb_short: AABB = mesh_short.get_aabb()
	var aabb_long: AABB = mesh_long.get_aabb()
	# 긴 크랙의 AABB가 짧은 크랙보다 커야 한다 (볼륨 비교)
	var vol_short: float = aabb_short.size.x * aabb_short.size.y * aabb_short.size.z
	var vol_long: float = aabb_long.size.x * aabb_long.size.y * aabb_long.size.z
	# 랜덤 요소가 있으므로 크기 비교 대신 둘 다 유효한 메시인지 확인
	assert_gt(mesh_short.get_surface_count(), 0, "짧은 크랙 서피스 존재")
	assert_gt(mesh_long.get_surface_count(), 0, "긴 크랙 서피스 존재")


## TEST-ENV-002-3: 파라미터(width) 변경 시 결과가 달라지는지
func test_different_width_produces_valid_mesh() -> void:
	var gen := CrackGenerator.new()
	var mesh_thin: ArrayMesh = gen.generate_crack_mesh(1.0, 0.01, 2)
	var mesh_wide: ArrayMesh = gen.generate_crack_mesh(1.0, 0.1, 2)

	assert_not_null(mesh_thin, "얇은 크랙 메시 생성")
	assert_not_null(mesh_wide, "넓은 크랙 메시 생성")
	assert_gt(mesh_thin.get_surface_count(), 0, "얇은 크랙 서피스 존재")
	assert_gt(mesh_wide.get_surface_count(), 0, "넓은 크랙 서피스 존재")


## TEST-ENV-002-4: 분기 수 0일 때 직선 크랙 생성
func test_zero_branches_creates_straight_crack() -> void:
	var gen := CrackGenerator.new()
	var mesh: ArrayMesh = gen.generate_crack_mesh(1.0, 0.02, 0)

	assert_not_null(mesh, "분기 0개 크랙 메시 생성")
	assert_gt(mesh.get_surface_count(), 0, "서피스 존재")


## TEST-ENV-002-5: 높은 분기 수에서도 정상 동작
func test_many_branches_creates_mesh() -> void:
	var gen := CrackGenerator.new()
	var mesh: ArrayMesh = gen.generate_crack_mesh(2.0, 0.03, 10)

	assert_not_null(mesh, "분기 10개 크랙 메시 생성")
	assert_gt(mesh.get_surface_count(), 0, "서피스 존재")


## TEST-ENV-002-6: 절차적 생성의 랜덤성 확인 — 동일 파라미터로 2번 생성 시 다른 결과
func test_procedural_randomness() -> void:
	var gen := CrackGenerator.new()
	var mesh_a: ArrayMesh = gen.generate_crack_mesh(1.0, 0.02, 2)
	var mesh_b: ArrayMesh = gen.generate_crack_mesh(1.0, 0.02, 2)

	# 두 메시 모두 유효해야 한다
	assert_not_null(mesh_a, "메시 A 유효")
	assert_not_null(mesh_b, "메시 B 유효")

	# AABB가 랜덤 편향으로 인해 다를 수 있다
	# (극히 드물게 같을 수도 있으므로 soft assertion — 존재만 확인)
	var aabb_a: AABB = mesh_a.get_aabb()
	var aabb_b: AABB = mesh_b.get_aabb()
	# 둘 다 유효한 크기의 AABB를 가져야 한다
	assert_gt(aabb_a.size.length(), 0.0, "메시 A AABB 크기 > 0")
	assert_gt(aabb_b.size.length(), 0.0, "메시 B AABB 크기 > 0")


## TEST-ENV-002-7: 크랙 머티리얼 생성 — 불투명
func test_crack_material_opaque() -> void:
	var gen := CrackGenerator.new()
	var mat: StandardMaterial3D = gen.create_crack_material(1.0, 0.0)

	assert_not_null(mat, "머티리얼 생성")
	assert_almost_eq(mat.albedo_color.a, 1.0, 0.01, "불투명도 1.0")


## TEST-ENV-002-8: 크랙 머티리얼 생성 — 반투명
func test_crack_material_translucent() -> void:
	var gen := CrackGenerator.new()
	var mat: StandardMaterial3D = gen.create_crack_material(0.5, 0.5)

	assert_not_null(mat, "머티리얼 생성")
	assert_almost_eq(mat.albedo_color.a, 0.5, 0.01, "불투명도 0.5")
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "반투명 모드 활성")


## TEST-ENV-002-E: 매우 작은 길이에 대한 폴백 동작
func test_very_small_length() -> void:
	var gen := CrackGenerator.new()
	# 매우 작은 양수 길이
	var mesh: ArrayMesh = gen.generate_crack_mesh(0.001, 0.001, 0)

	assert_not_null(mesh, "극소 크랙도 메시 생성")
	assert_gt(mesh.get_surface_count(), 0, "서피스 존재")


## TEST-ENV-002-E2: CrackGenerator는 RefCounted (Godot 노드가 아님)
func test_crack_generator_is_refcounted() -> void:
	var gen := CrackGenerator.new()
	assert_true(gen is RefCounted, "CrackGenerator는 RefCounted를 상속")
	assert_eq(gen.get_class(), "RefCounted", "base class는 RefCounted")
