class_name SubjectData
extends Resource

## SPEC-DAT-001: 피험자 정보 데이터 모델
## 세션 결과 저장 시 피험자 식별 정보를 담는다.

@export var subject_id: String = ""
@export var experience_years: int = 0
@export var experience_category: String = ""


func to_dict() -> Dictionary:
	return {
		"subject_id": subject_id,
		"experience_years": experience_years,
		"experience_category": experience_category,
	}
