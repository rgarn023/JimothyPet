extends Node
## Care notifications — hungry / play / acting up / waste.
## Web: Notification API via JavaScriptBridge. Desktop Linux: notify-send.
## Cooldown prevents spam.

const COOLDOWN_SEC := 12 * 60

var _last := {
	"hungry": -999999,
	"play": -999999,
	"stubborn": -999999,
	"waste": -999999,
}


func _ready() -> void:
	if PetState:
		PetState.state_changed.connect(_on_state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		check_now()


func _on_state() -> void:
	# Light polling when state changes (stubborn flip, decay tick, etc.)
	check_now()


func check_now() -> void:
	if PetState == null or not PetState.alerts_enabled:
		return
	if not PetState.alive or PetState.ascending or PetState.stage == "bush":
		return

	var now := Time.get_unix_time_from_system()
	if PetState.stubborn:
		_try_send("stubborn", "Jimothy is acting up", _stubborn_body(), now)
	if PetState.hunger < 25.0:
		_try_send("hungry", "Jimothy is hungry", "He’s hunting for a real meal. Time to feed him.", now)
	if PetState.stage != "baby" and PetState.energy >= 18.0 and PetState.happy < 25.0:
		_try_send(
			"play",
			"Jimothy wants to play",
			"Restless cryptid energy — try a Dumpster Dive night run.",
			now
		)
	if PetState.has_mess:
		_try_send(
			"waste",
			"Jimothy left a mess",
			"Nest waste is piling up — open the app and Clean.",
			now
		)


func _stubborn_body() -> String:
	if PetState.stubborn_reason != "":
		return "He’s %s. Open the app and scold him." % PetState.stubborn_reason
	return "He’s being stubborn — open the app and scold him."


func _try_send(kind: String, title: String, body: String, now: float) -> void:
	var last: float = float(_last.get(kind, -999999))
	if now - last < COOLDOWN_SEC:
		return
	if not _post(title, body):
		return
	_last[kind] = now


func _post(title: String, body: String) -> bool:
	# Godot web export
	if OS.has_feature("web"):
		return _post_web(title, body)
	# Linux desktop
	if OS.get_name() == "Linux":
		var code := OS.execute("notify-send", ["-a", "Jimothy", "-i", "dialog-information", title, body], [], false, false)
		return code == 0
	# macOS desktop
	if OS.get_name() == "macOS":
		var script := "display notification \"%s\" with title \"%s\"" % [
			body.replace("\"", "'"),
			title.replace("\"", "'"),
		]
		var code := OS.execute("osascript", ["-e", script], [], false, false)
		return code == 0
	return false


func _post_web(title: String, body: String) -> bool:
	if not OS.has_feature("web"):
		return false
	# Escape for JS string literals
	var t := title.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ")
	var b := body.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ")
	var js := """
(function(){
  if (!('Notification' in window)) return false;
  if (Notification.permission !== 'granted') return false;
  try {
    new Notification("%s", { body: "%s", icon: "icons/icon-192.png", tag: "jimothy-care" });
    return true;
  } catch (e) { return false; }
})();
""" % [t, b]
	var result = JavaScriptBridge.eval(js)
	return bool(result)


func request_permission_web() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
(async function(){
  if (!('Notification' in window)) return;
  if (Notification.permission === 'default') await Notification.requestPermission();
})();
""")
