class_name VRInitializer
extends RefCounted

## SPEC-VR-001: OpenXR 초기화 유틸리티
## XRServer를 통해 OpenXR 인터페이스를 찾고 초기화한다.
## 초기화 결과를 Dictionary로 반환하여 호출자가 분기 처리할 수 있게 한다.

## OpenXR 초기화를 시도한다.
## 성공 시 {"success": true, "interface": XRInterface} 반환
## 실패 시 {"success": false, "reason": String} 반환
static func initialize_openxr() -> Dictionary:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")

	if xr_interface == null:
		var reason := "OpenXR interface not found. No VR runtime available."
		push_warning(reason)
		return {"success": false, "reason": reason}

	if not xr_interface.initialize():
		var reason := "OpenXR interface found but initialization failed."
		push_warning(reason)
		return {"success": false, "reason": reason}

	print("[VRInitializer] OpenXR initialized successfully.")
	return {"success": true, "interface": xr_interface}
