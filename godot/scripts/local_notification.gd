extends Node
## Autoload wrapper for the kyoz LocalNotification Android plugin.
## Official API: https://github.com/kyoz/godot-local-notification
## Requires: Project → Install Android Build Template + Gradle export + plugin enabled.

signal on_permission_request_completed()

var ln = null


func _ready() -> void:
	# Defer so Android plugin singletons are registered.
	call_deferred("init")


func init() -> void:
	if ln != null:
		return
	if Engine.has_singleton("LocalNotification"):
		ln = Engine.get_singleton("LocalNotification")
		init_signals()
		print("[LocalNotification] plugin ready")
	elif OS.get_name() == "Android":
		push_warning(
			"[LocalNotification] Plugin missing — Project → Install Android Build Template, "
			+ "then export with Use Gradle Build + Local Notification plugin enabled."
		)


func init_signals() -> void:
	if ln == null:
		return
	if not ln.is_connected("permission_request_completed", Callable(self, "_permission_request_completed")):
		ln.connect("permission_request_completed", Callable(self, "_permission_request_completed"))


func _permission_request_completed() -> void:
	emit_signal("on_permission_request_completed")


func available() -> bool:
	if ln == null:
		init()
	return ln != null


func isPermissionGranted() -> bool:
	if not ln:
		return false
	return bool(ln.isPermissionGranted())


func requestPermission() -> void:
	if not ln:
		not_found_plugin()
		return
	ln.requestPermission()


func openAppSetting() -> void:
	if not ln:
		not_found_plugin()
		return
	ln.openAppSetting()


func show(title, message, interval, tag) -> void:
	if not ln:
		not_found_plugin()
		return
	# Plugin requires interval > 0; tag must be int.
	ln.show(str(title), str(message), maxi(1, int(interval)), int(tag))


func showRepeating(title, message, interval, repeat_interval, tag) -> void:
	if not ln:
		not_found_plugin()
		return
	ln.showRepeating(
		str(title),
		str(message),
		maxi(1, int(interval)),
		maxi(1, int(repeat_interval)),
		int(tag)
	)


func cancel(tag) -> void:
	if not ln:
		not_found_plugin()
		return
	ln.cancel(int(tag))


func not_found_plugin() -> void:
	print(
		"[LocalNotification] Not found plugin. Enable Local Notification in the Android export "
		+ "(custom Gradle build)."
	)
