class_name SessionLogger
extends Node

## SPEC-DAT-001: 세션 결과 로컬 파일 저장
## 세션 결과를 JSON(상세) + CSV(스프레드시트 호환) 두 가지 형식으로 저장한다.
## 저장 경로: data/sessions/
## 파일명 규칙: {subject_id}_{timestamp}_result.json / .csv / _hazards.csv

## 저장 성공 시 파일 경로(JSON 기준)를 전달
signal save_completed(path: String)
## 저장 실패 시 에러 메시지를 전달
signal save_failed(error: String)

const SAVE_DIR: String = "data/sessions"
const FALLBACK_DIR: String = "user://sessions"


## SPEC-DAT-001: 세션 결과를 JSON + CSV 형식으로 저장한다.
## 성공 시 JSON 파일 경로를 반환하며 save_completed 시그널을 발행한다.
## 실패 시 빈 문자열을 반환하며 save_failed 시그널을 발행한다.
func save_session_result(session_data: SessionData) -> String:
	var subject_id: String = ""
	if session_data.subject != null:
		subject_id = session_data.subject.subject_id

	var timestamp_str: String = _timestamp_to_filename_str(session_data.start_time)
	var base_name: String = _generate_filename(subject_id, timestamp_str)

	var dir: String = SAVE_DIR
	if not _ensure_dir(dir):
		dir = FALLBACK_DIR
		if not _ensure_dir(dir):
			var msg: String = "저장 디렉토리 생성 실패: %s, %s" % [SAVE_DIR, FALLBACK_DIR]
			push_error(msg)
			_log_to_console(session_data)
			save_failed.emit(msg)
			return ""

	var json_path: String = dir.path_join(base_name + "_result.json")
	var csv_path: String = dir.path_join(base_name + "_result.csv")
	var hazards_csv_path: String = dir.path_join(base_name + "_hazards.csv")

	## SPEC-DAT-001: 기존 파일이 있으면 덮어쓰지 않고 순번을 붙여 새 파일 생성
	json_path = _resolve_unique_path(json_path)
	csv_path = _resolve_unique_path(csv_path)
	hazards_csv_path = _resolve_unique_path(hazards_csv_path)

	var json_ok: bool = _save_json(session_data, json_path)
	var csv_ok: bool = _save_csv(session_data, csv_path)
	var hazards_csv_ok: bool = _save_hazards_csv(session_data, hazards_csv_path)

	if not (json_ok and csv_ok and hazards_csv_ok):
		var msg: String = "일부 파일 저장 실패 — json:%s csv:%s hazards_csv:%s" % [
			json_ok, csv_ok, hazards_csv_ok
		]
		push_error(msg)
		_log_to_console(session_data)
		save_failed.emit(msg)
		return ""

	save_completed.emit(json_path)
	return json_path


## JSON 상세 결과 파일 저장
func _save_json(session_data: SessionData, path: String) -> bool:
	var data: Dictionary = _build_json_dict(session_data)
	var json_text: String = JSON.stringify(data, "\t")
	return _write_file(path, json_text)


## CSV 요약 파일 저장 (세션 1행)
func _save_csv(session_data: SessionData, path: String) -> bool:
	var subject_id: String = ""
	var experience_years: int = 0
	var experience_category: String = ""
	if session_data.subject != null:
		subject_id = session_data.subject.subject_id
		experience_years = session_data.subject.experience_years
		experience_category = session_data.subject.experience_category

	var start_iso: String = _epoch_ms_to_iso(session_data.start_time)

	var header: String = "subject_id,experience_years,scenario_id,site_type,start_time,elapsed_sec,end_reason,total_hazards,discovered,discovery_rate,avg_reaction_ms"
	var row: String = "%s,%d,%s,%s,%s,%.1f,%s,%d,%d,%.1f,%.1f" % [
		subject_id,
		experience_years,
		session_data.scenario_id,
		session_data.site_type,
		start_iso,
		session_data.get_elapsed_seconds(),
		session_data.end_reason,
		session_data.total_hazards,
		session_data.get_discovered_hazards(),
		session_data.get_discovery_rate_percent(),
		session_data.get_avg_reaction_time_ms(),
	]
	return _write_file(path, header + "\n" + row + "\n")


## CSV 위험 요소 상세 파일 저장 (위험 요소별 1행)
func _save_hazards_csv(session_data: SessionData, path: String) -> bool:
	var header: String = "hazard_id,type,difficulty,discovered,reaction_time_ms,player_x,player_y,player_z,gaze_x,gaze_y,gaze_z"
	var lines: PackedStringArray = PackedStringArray()
	lines.append(header)

	for result: MarkingResult in session_data.get_hazard_results():
		var pos_x: String = ""
		var pos_y: String = ""
		var pos_z: String = ""
		var gaze_x: String = ""
		var gaze_y: String = ""
		var gaze_z: String = ""

		if result.reaction_time_ms >= 0.0:
			pos_x = "%.2f" % result.player_position.x
			pos_y = "%.2f" % result.player_position.y
			pos_z = "%.2f" % result.player_position.z
			gaze_x = "%.4f" % result.gaze_direction.x
			gaze_y = "%.4f" % result.gaze_direction.y
			gaze_z = "%.4f" % result.gaze_direction.z

		var row: String = "%s,%s,%.2f,%s,%.1f,%s,%s,%s,%s,%s,%s" % [
			result.hazard_id,
			result.hazard_type,
			result.hazard_difficulty,
			"true" if result.is_correct else "false",
			result.reaction_time_ms,
			pos_x, pos_y, pos_z,
			gaze_x, gaze_y, gaze_z,
		]
		lines.append(row)

	return _write_file(path, "\n".join(lines) + "\n")


## JSON 딕셔너리 빌드
func _build_json_dict(session_data: SessionData) -> Dictionary:
	var subject_dict: Dictionary = {}
	if session_data.subject != null:
		subject_dict = session_data.subject.to_dict()

	var hazard_results_arr: Array = []
	for result: MarkingResult in session_data.get_hazard_results():
		hazard_results_arr.append(result.to_dict())

	var false_positives_arr: Array = []
	for fp: MarkingResult in session_data.get_false_positives():
		false_positives_arr.append(fp.to_dict())

	return {
		"session_id": session_data.session_id,
		"subject": subject_dict,
		"scenario_id": session_data.scenario_id,
		"site_type": session_data.site_type,
		"start_time_epoch_ms": session_data.start_time,
		"end_time_epoch_ms": session_data.end_time,
		"time_limit_seconds": session_data.time_limit_seconds,
		"elapsed_seconds": session_data.get_elapsed_seconds(),
		"end_reason": session_data.end_reason,
		"total_hazards": session_data.total_hazards,
		"discovered_hazards": session_data.get_discovered_hazards(),
		"discovery_rate_percent": snappedf(session_data.get_discovery_rate_percent(), 0.1),
		"avg_reaction_time_ms": session_data.get_avg_reaction_time_ms(),
		"hazard_results": hazard_results_arr,
		"false_positives": false_positives_arr,
	}


## SPEC-DAT-001: 파일명 생성 — {subject_id}_{timestamp}
func _generate_filename(subject_id: String, timestamp_str: String) -> String:
	var safe_id: String = subject_id.strip_edges()
	if safe_id.is_empty():
		safe_id = "unknown"
	return "%s_%s" % [safe_id, timestamp_str]


## SPEC-DAT-001: 기존 파일 덮어쓰지 않기 — 순번 suffix 추가
func _resolve_unique_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		return path

	var base: String = path.get_basename()
	var ext: String = path.get_extension()
	var idx: int = 1
	var candidate: String = "%s_%02d.%s" % [base, idx, ext]
	while FileAccess.file_exists(candidate):
		idx += 1
		candidate = "%s_%02d.%s" % [base, idx, ext]
	return candidate


## 디렉토리가 없으면 생성한다.
func _ensure_dir(dir_path: String) -> bool:
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_error("디렉토리 생성 실패 (%s): %s" % [dir_path, error_string(err)])
		return false
	return true


## 파일에 텍스트를 쓴다. 성공 시 true 반환.
func _write_file(path: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("파일 열기 실패 (%s): %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(content)
	file.close()
	return true


## SPEC-DAT-001: 저장 실패 시 콘솔에 최소 결과 출력 (대안 동작)
func _log_to_console(session_data: SessionData) -> void:
	var subject_id: String = ""
	if session_data.subject != null:
		subject_id = session_data.subject.subject_id
	print("[SessionLogger] 파일 저장 실패 — 콘솔 출력 폴백")
	print("  session_id      : ", session_data.session_id)
	print("  subject_id      : ", subject_id)
	print("  scenario_id     : ", session_data.scenario_id)
	print("  discovery_rate  : %.1f%%" % session_data.get_discovery_rate_percent())
	print("  avg_reaction_ms : %.1f" % session_data.get_avg_reaction_time_ms())
	print("  elapsed_seconds : %.1f" % session_data.get_elapsed_seconds())


## Unix epoch ms → ISO 8601 날짜+시간 문자열 (로컬 시간 없이 UTC 근사)
func _epoch_ms_to_iso(epoch_ms: int) -> String:
	if epoch_ms <= 0:
		return ""
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(epoch_ms / 1000)
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"],
	]


## Unix epoch ms → 파일명용 타임스탬프 문자열 (20260401_143022)
func _timestamp_to_filename_str(epoch_ms: int) -> String:
	if epoch_ms <= 0:
		return "00000000_000000"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(epoch_ms / 1000)
	return "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"],
	]
