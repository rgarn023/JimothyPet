extends Node
## Care notifications — specific needs (hungry / sick / acting up / waste / bored)
## and combinations of those, plus new-form milestones.
## Android: NotificationScheduler plugin (Gradle) + UI-thread NotificationManager
## fallback + Toast confirmation so failures are visible in-game.
## Web: Notification API (+ service worker). Desktop: OS toasts.

const COOLDOWN_SEC := 12 * 60
const ANDROID_CHANNEL_ID := "jimothy_care"
const ANDROID_CHANNEL_NAME := "Jimothy care"
const ANDROID_PERM := "android.permission.POST_NOTIFICATIONS"
const SCHEDULER_SCRIPT := preload("res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd")
## Stable AlarmManager ids so closed-app alerts can be cancelled / replaced.
const SCHED_IDS := {
	"bush": 1210,
	"hungry": 1211,
	"bored": 1212,
	"sick": 1213,
	"acting": 1214,
	"waste": 1215,
	"form": 1216,
	"care": 1217,
}

var _last := {
	"care": -999999,
	"form": -999999,
}
var _last_care_fp: String = ""
var _last_scheduled_fp: String = ""
var _last_scheduled_at: float = -999999.0
var _android_channel_ready: bool = false
var _notify_id: int = 1100
var _perm_connected: bool = false
var _bootstrapped: bool = false
var _perm_prompted_session: bool = false
var _scheduler: Node = null
var _scheduler_ready: bool = false
var _scheduler_channel_ready: bool = false
## Care OS notifications are closed-app only (no test/welcome shade spam).
var _is_foreground: bool = true
const MIN_AWAY_SEC := 60
const SAME_CARE_COOLDOWN_SEC := 30 * 60
## Last delivery diagnostic for UI / speech.
var last_error: String = ""


func _ready() -> void:
	if PetState:
		PetState.state_changed.connect(_on_state)
		PetState.stage_changed.connect(_on_stage)
	_setup_scheduler()
	_connect_permission_signal()
	call_deferred("_bootstrap_alerts")


func _setup_scheduler() -> void:
	if OS.get_name() != "Android":
		return
	_scheduler = SCHEDULER_SCRIPT.new()
	_scheduler.name = "NotificationScheduler"
	add_child(_scheduler)
	_scheduler.initialization_completed.connect(_on_scheduler_initialized)
	_scheduler.post_notifications_permission_granted.connect(_on_scheduler_perm_granted)
	_scheduler.post_notifications_permission_denied.connect(_on_scheduler_perm_denied)
	_scheduler.initialize()
	# Plugin singleton can appear a moment after activity bind (esp. gdap path).
	call_deferred("_retry_scheduler_init")
	call_deferred("_schedule_scheduler_retries")


func _schedule_scheduler_retries() -> void:
	var tree := get_tree()
	if tree == null:
		return
	# Plugin bind can lag a few seconds on cold start.
	for sec in [0.3, 0.8, 1.5, 2.5, 4.0]:
		tree.create_timer(sec).timeout.connect(_retry_scheduler_init)


func _retry_scheduler_init() -> void:
	if _scheduler_ready or _scheduler == null:
		return
	if Engine.has_singleton("NotificationSchedulerPlugin"):
		_scheduler.initialize()
	elif Engine.has_singleton("NotificationScheduler"):
		# Older / alternate singleton name.
		_scheduler.initialize()


func _on_scheduler_initialized() -> void:
	_scheduler_ready = true
	print("JimothyNotify: NotificationScheduler ready")
	_ensure_scheduler_channel()
	# Exact alarms keep closed-app / timed care alerts reliable on Android 12+.
	if _scheduler.has_method("has_schedule_exact_alarm_permission") \
			and not _scheduler.has_schedule_exact_alarm_permission() \
			and _scheduler.has_method("request_schedule_exact_alarm_permission"):
		_scheduler.request_schedule_exact_alarm_permission()
	# Prompt for shade permission when alerts are on (no test notification).
	if PetState and PetState.alerts_enabled and not _scheduler.has_post_notifications_permission():
		_scheduler.request_post_notifications_permission()
	# If the player already left the app before the plugin bound, arm alerts now.
	if not _is_foreground:
		_schedule_background_alerts()


func closed_app_ready() -> bool:
	return OS.get_name() == "Android" and _scheduler_ready and _plugin() != null


func build_label() -> String:
	var ver := str(ProjectSettings.get_setting("application/config/version", "?"))
	return "v%s" % ver


func scheduler_status_line() -> String:
	if OS.get_name() != "Android":
		return "%s · not Android" % build_label()
	var has_plugin := Engine.has_singleton("NotificationSchedulerPlugin") \
			or Engine.has_singleton("NotificationScheduler")
	if not os_permission_granted():
		return "%s · notifications blocked — tap Alerts: Allow" % build_label()
	if closed_app_ready():
		return "%s · closed-app alerts ready" % build_label()
	if has_plugin and not _scheduler_ready:
		return "%s · plugin starting…" % build_label()
	return "%s · closed-app plugin missing" % build_label()


func _on_scheduler_perm_granted(_permission_name: String) -> void:
	_ensure_scheduler_channel()
	last_error = ""
	if PetState:
		PetState.speech.emit(
			"Notifications allowed. Care alerts show after you leave the app."
		)
	_android_toast("Jimothy notifications on")


func _on_scheduler_perm_denied(_permission_name: String) -> void:
	last_error = "Notification permission denied"
	if PetState:
		PetState.speech.emit(
			"Notifications blocked — tap Alerts: Allow again, or enable them in phone Settings."
		)
	_android_toast("Enable Jimothy notifications in Settings")


func _plugin() -> Object:
	if _scheduler == null:
		return null
	# NotificationScheduler keeps the Android singleton here after initialize().
	return _scheduler.get("_plugin_singleton") as Object


func _ensure_scheduler_channel() -> bool:
	if _scheduler == null or not _scheduler_ready:
		return false
	if _scheduler_channel_ready:
		return true
	var plugin := _plugin()
	if plugin == null:
		last_error = "NotificationScheduler plugin missing from APK"
		return false
	# Plain String keys — Java isValid()/containsKey() is strict about this.
	var channel := {
		"channel_id": ANDROID_CHANNEL_ID,
		"channel_name": ANDROID_CHANNEL_NAME,
		"channel_description": "Hungry, sick, acting up, waste, bored, and new forms",
		"channel_importance": 4, # HIGH
		"badge_enabled": true,
	}
	var result: int = int(plugin.create_notification_channel(channel))
	if result == OK or result == ERR_ALREADY_EXISTS:
		_scheduler_channel_ready = true
		return true
	last_error = "Channel create failed (%s)" % result
	push_warning("JimothyNotify: channel create failed err=%s" % result)
	return false


func _bootstrap_alerts() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true
	_connect_permission_signal()
	# Ask for OS permission when alerts are on — never send a test shade alert.
	if PetState and PetState.alerts_enabled:
		call_deferred("request_permission")


func _connect_permission_signal() -> void:
	if _perm_connected:
		return
	var tree := get_tree()
	if tree and tree.has_signal("on_request_permissions_result"):
		tree.on_request_permissions_result.connect(_on_permissions_result)
		_perm_connected = true


func os_permission_granted() -> bool:
	if OS.has_feature("web"):
		return _web_permission_granted()
	if OS.get_name() != "Android":
		return true
	if _scheduler != null and _scheduler_ready:
		return bool(_scheduler.has_post_notifications_permission())
	return _android_notifications_allowed()


func _web_permission_granted() -> bool:
	if not OS.has_feature("web"):
		return false
	var status = JavaScriptBridge.eval(
		"(function(){ return ('Notification' in window) ? Notification.permission : 'unsupported'; })();"
	)
	return str(status) == "granted"


func _open_notification_settings_if_possible() -> void:
	if OS.get_name() != "Android":
		return
	if _scheduler != null and _scheduler_ready and _scheduler.has_method("open_app_info_settings"):
		_scheduler.open_app_info_settings()


func _on_permissions_result(permission: String, granted: bool) -> void:
	if permission != ANDROID_PERM:
		return
	if granted:
		_ensure_android_channel()
		_ensure_scheduler_channel()
		last_error = ""
		if PetState:
			PetState.speech.emit(
				"Notifications allowed. Care alerts show after you leave the app."
			)
		_android_toast("Jimothy notifications on")
	elif PetState:
		last_error = "Notification permission denied"
		PetState.speech.emit(
			"Notification permission denied — tap Alerts: Allow, or enable in Settings → Apps → JimothyPet → Notifications."
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		_is_foreground = false
		# Arm closed-app alarms when leaving. Retry shortly if the plugin is still binding.
		_schedule_background_alerts()
		var tree := get_tree()
		if tree and (not _scheduler_ready or _plugin() == null):
			tree.create_timer(1.0).timeout.connect(_schedule_background_alerts)
			tree.create_timer(2.5).timeout.connect(_schedule_background_alerts)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# Cancel only on full resume — not on notification-shade FOCUS_IN flicker.
		_is_foreground = true
		_cancel_background_alerts()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_is_foreground = true


func _on_state() -> void:
	# No shade spam while playing — needs are visible in-app.
	pass


func _on_stage(_stage: String) -> void:
	# Growth is shown in-app while open. Closed-app milestones are scheduled on pause.
	if not _is_foreground:
		_schedule_background_alerts()


func check_now() -> void:
	# Kept for API compatibility / desktop. Android care alerts are closed-app only.
	if OS.get_name() == "Android":
		return
	if PetState == null or not PetState.alerts_enabled:
		return
	if not PetState.alive or PetState.ascending or PetState.stage == "bush":
		return
	var snap := _care_snapshot()
	if snap["flags"].is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var fp: String = str(snap["fp"])
	if fp == _last_care_fp and now - float(_last.get("care", -999999)) < COOLDOWN_SEC:
		return
	if _post(_care_title(snap["flags"]), _care_body(snap["lines"])):
		_last["care"] = now
		_last_care_fp = fp


func _schedule_background_alerts() -> void:
	if PetState == null or not PetState.alerts_enabled:
		_cancel_background_alerts()
		return
	if OS.get_name() != "Android":
		return
	# Never arm closed-app alarms while the player is actively in the app.
	if _is_foreground:
		return
	if not _scheduler_ready or _plugin() == null:
		last_error = "NotificationScheduler not ready — will retry"
		_retry_scheduler_init()
		return
	if not _ensure_scheduler_channel():
		return
	# Prefer plugin permission; fall back to OS permission check.
	var allowed := bool(_plugin().has_post_notifications_permission()) \
			or os_permission_granted() \
			or _android_notifications_allowed()
	if not allowed:
		last_error = "Notification permission missing for closed-app alerts"
		return

	_cancel_background_alerts()
	var events: Array = PetState.predict_care_alerts(MIN_AWAY_SEC)
	var now := Time.get_unix_time_from_system()
	var scheduled := 0
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var key := str(ev.get("key", ""))
		var delay := int(ev.get("delay", 0))
		var title := str(ev.get("title", ""))
		var body := str(ev.get("body", ""))
		var fp := str(ev.get("fp", key))
		if key == "" or title == "" or delay < 1:
			continue
		# Don't re-queue the same care set for a while (stops reopen/close spam).
		if key == "care" and fp == _last_scheduled_fp \
				and now - _last_scheduled_at < SAME_CARE_COOLDOWN_SEC:
			continue
		if _schedule_android_event(key, title, body, delay):
			scheduled += 1
			if key == "care":
				_last_scheduled_fp = fp
				_last_scheduled_at = now
	if scheduled > 0:
		last_error = ""
		print("JimothyNotify: scheduled ", scheduled, " closed-app alerts")
	elif events.is_empty():
		print("JimothyNotify: no closed-app alerts to schedule right now")


func _cancel_background_alerts() -> void:
	if OS.get_name() != "Android":
		return
	var plugin := _plugin()
	if plugin == null:
		return
	for key in SCHED_IDS.keys():
		plugin.cancel(int(SCHED_IDS[key]))


func _schedule_android_event(key: String, title: String, body: String, delay_sec: int) -> bool:
	var id := int(SCHED_IDS.get(key, 0))
	if id == 0:
		_notify_id += 1
		id = _notify_id
	# Prefer the typed GDScript wrapper (same Dictionary payload underneath).
	if _scheduler != null and _scheduler_ready and _scheduler.has_method("schedule"):
		var nd := NotificationData.new()
		nd.set_id(id) \
			.set_channel_id(ANDROID_CHANNEL_ID) \
			.set_title(title) \
			.set_content(body) \
			.set_small_icon_name("ic_default_notification") \
			.set_delay(maxi(1, delay_sec))
		var wrapped: int = int(_scheduler.schedule(nd))
		if wrapped == OK:
			return true
		push_warning("JimothyNotify: schedule %s via wrapper failed err=%s" % [key, wrapped])
	var plugin := _plugin()
	if plugin == null:
		return false
	var data := {
		"notification_id": id,
		"channel_id": ANDROID_CHANNEL_ID,
		"title": title,
		"content": body,
		"small_icon_name": "ic_default_notification",
		"delay": maxi(1, delay_sec),
	}
	var result: int = int(plugin.schedule(data))
	if result != OK:
		push_warning("JimothyNotify: schedule %s failed err=%s" % [key, result])
		return false
	return true


func _care_snapshot() -> Dictionary:
	var flags: PackedStringArray = []
	var lines: PackedStringArray = []

	if PetState.sick:
		flags.append("sick")
		lines.append("Sick — open Action → Heal (upset stomach).")
	if PetState.stubborn:
		flags.append("acting up")
		if PetState.stubborn_reason != "":
			lines.append("Acting up — he’s %s. Scold him." % PetState.stubborn_reason)
		else:
			lines.append("Acting up — open Action → Scold.")
	if PetState.hunger < 25.0:
		flags.append("hungry")
		lines.append("Hungry — feed him a real meal.")
	if PetState.has_mess:
		flags.append("waste")
		if PetState.mess_count <= 1:
			lines.append("Waste — one pile in the nest. Clean it.")
		else:
			lines.append("Waste — %d piles in the nest. Clean them." % PetState.mess_count)
	if PetState.stage != "baby" and PetState.energy >= 18.0 and PetState.happy < 25.0:
		flags.append("bored")
		lines.append("Bored — open Play for a game.")
	elif PetState.health < 30.0 and not PetState.sick:
		flags.append("run-down")
		lines.append("Run-down — skip treats; offer fish or berries.")

	return {
		"flags": flags,
		"lines": lines,
		"fp": "|".join(flags),
	}


func _care_title(flags: PackedStringArray) -> String:
	var n := flags.size()
	if n == 0:
		return "Jimothy needs care"
	if n == 1:
		match flags[0]:
			"sick":
				return "Jimothy is sick"
			"acting up":
				return "Jimothy is acting up"
			"hungry":
				return "Jimothy is hungry"
			"waste":
				return "Jimothy left a mess"
			"bored":
				return "Jimothy is bored"
			"run-down":
				return "Jimothy is run-down"
			_:
				return "Jimothy needs care"
	if n == 2:
		return "Jimothy: %s & %s" % [flags[0], flags[1]]
	# Keep shade titles short when many needs stack.
	return "Jimothy needs care (%d things)" % n


func _care_body(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return "Open the app — something changed."
	return "\n".join(lines)


func _try_send(kind: String, title: String, body: String, now: float, force: bool = false) -> void:
	var last: float = float(_last.get(kind, -999999))
	if not force and now - last < COOLDOWN_SEC:
		return
	if not _post(title, body):
		return
	_last[kind] = now


func supports_os_notifications() -> bool:
	if OS.has_feature("web"):
		return true
	match OS.get_name():
		"Android", "Linux", "macOS", "Windows":
			return true
		_:
			return false


## Kept for older UI hooks — no test alert is sent anymore.
func reset_welcome() -> void:
	pass


## Call when the player turns Alerts on — requests OS / browser permission only.
func request_permission() -> void:
	_connect_permission_signal()
	if OS.has_feature("web"):
		request_permission_web()
		return
	if OS.get_name() != "Android":
		return

	_ensure_android_channel()
	# Already allowed — just make sure channels exist.
	if os_permission_granted() or _android_notifications_allowed():
		_ensure_scheduler_channel()
		last_error = ""
		return

	# Second tap while still blocked → open app notification settings.
	if _perm_prompted_session:
		_open_notification_settings_if_possible()

	_perm_prompted_session = true
	if OS.has_method("request_permission"):
		OS.request_permission(ANDROID_PERM)
	elif OS.has_method("request_permissions"):
		OS.request_permissions()

	if _scheduler != null:
		if not _scheduler_ready:
			_scheduler.initialize()
		if _scheduler_ready and not _scheduler.has_post_notifications_permission():
			_scheduler.request_post_notifications_permission()

	last_error = "Waiting for notification permission"
	_android_toast("Allow Jimothy notifications")
	if PetState:
		PetState.speech.emit(
			"Allow notifications on the popup. If it doesn’t appear: Settings → Apps → JimothyPet → Notifications → On."
		)


func _post(title: String, body: String) -> bool:
	if OS.has_feature("web"):
		return _post_web(title, body)
	match OS.get_name():
		"Android":
			return _post_android(title, body)
		"Linux":
			return OS.execute(
				"notify-send",
				["-a", "JimothyPet", "-i", "dialog-information", title, body],
				[],
				false,
				false
			) == 0
		"macOS":
			var script := "display notification \"%s\" with title \"%s\"" % [
				body.replace("\"", "'"),
				title.replace("\"", "'"),
			]
			return OS.execute("osascript", ["-e", script], [], false, false) == 0
		"Windows":
			return _post_windows(title, body)
		_:
			return false


func _post_windows(title: String, body: String) -> bool:
	var t := title.replace("'", "''")
	var b := body.replace("'", "''")
	var ps := """
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$template = @"
<toast><visual><binding template='ToastGeneric'><text>%s</text><text>%s</text></binding></visual></toast>
"@
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('JimothyPet').Show($toast)
""" % [t, b]
	return OS.execute("powershell", ["-NoProfile", "-Command", ps], [], false, false) == 0


func _post_web(title: String, body: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var t := title.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ")
	var b := body.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ")
	var js := """
(async function(){
  if (!('Notification' in window)) return false;
  if (Notification.permission !== 'granted') return false;
  var opts = {
    body: "%s",
    icon: "icons/icon-192.png",
    badge: "icons/icon-192.png",
    tag: "jimothy-care",
    renotify: true,
    data: { url: "./" }
  };
  try {
    if ('serviceWorker' in navigator) {
      var reg = await navigator.serviceWorker.ready;
      if (reg && reg.showNotification) {
        await reg.showNotification("%s", opts);
        return true;
      }
    }
    new Notification("%s", opts);
    return true;
  } catch (e) { return false; }
})();
""" % [b, t, t]
	return bool(JavaScriptBridge.eval(js))


func request_permission_web() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
(async function(){
  if (!('Notification' in window)) return;
  if (Notification.permission === 'default') await Notification.requestPermission();
})();
""")


func _post_android(title: String, body: String) -> bool:
	# Built-in NotificationManager first (works without Gradle plugins).
	var jni_err := ""
	var jni_ok := _post_android_jni(title, body)
	if not jni_ok:
		jni_err = last_error if last_error != "" else "JNI notify failed"

	# Optional scheduler only if the editor plugin was packaged into the APK.
	var sched_err := ""
	var sched_ok := false
	if _scheduler != null and _scheduler_ready and _plugin() != null:
		sched_ok = _post_android_scheduler(title, body)
		if not sched_ok:
			sched_err = last_error if last_error != "" else "scheduler failed"
	# else: plugin not in this APK — not an error by itself

	if jni_ok or sched_ok:
		last_error = ""
		return true

	var parts: PackedStringArray = []
	if jni_err != "":
		parts.append(jni_err)
	if sched_err != "":
		parts.append(sched_err)
	if parts.is_empty():
		parts.append("Could not post Android notification")
	last_error = " / ".join(parts)
	return false


func _post_android_scheduler(title: String, body: String) -> bool:
	var plugin := _plugin()
	if plugin == null:
		last_error = "NotificationScheduler not in APK"
		return false
	if not bool(plugin.has_post_notifications_permission()):
		plugin.request_post_notifications_permission()
		last_error = "Waiting for notification permission"
		return false
	if not _ensure_scheduler_channel():
		return false
	_notify_id += 1
	var data := {
		"notification_id": _notify_id,
		"channel_id": ANDROID_CHANNEL_ID,
		"title": title,
		"content": body,
		"small_icon_name": "ic_default_notification",
		"delay": 1,
	}
	var result: int = int(plugin.schedule(data))
	if result != OK:
		push_warning("JimothyNotify: scheduler.schedule failed err=%s" % result)
		last_error = "Scheduler error %s" % result
		return false
	print("JimothyNotify: scheduled via NotificationScheduler id=", _notify_id, " title=", title)
	return true


func _android_runtime():
	if OS.get_name() != "Android":
		return null
	if Engine.has_singleton("AndroidRuntime"):
		return Engine.get_singleton("AndroidRuntime")
	return null


func _jw():
	if Engine.has_singleton("JavaClassWrapper"):
		return Engine.get_singleton("JavaClassWrapper")
	return null


func _android_sdk_int() -> int:
	var jw = _jw()
	if jw == null:
		return 33 # assume modern Android if we can't read SDK
	var Build = jw.wrap("android.os.Build$VERSION")
	if Build == null:
		return 33
	var sdk := int(Build.SDK_INT)
	return sdk if sdk > 0 else 33


func _android_notifications_allowed() -> bool:
	if OS.get_name() != "Android":
		return false
	# Plugin OR OS grant — don't let one stale check block the other path.
	if _scheduler != null and _scheduler_ready and _scheduler.has_post_notifications_permission():
		return true
	var sdk := _android_sdk_int()
	if sdk == 0:
		return true
	if sdk >= 33:
		var granted: PackedStringArray = OS.get_granted_permissions()
		for p in granted:
			if str(p) == ANDROID_PERM:
				return true
		# Also trust NotificationManager if the OS switch is on.
	var android_runtime = _android_runtime()
	if android_runtime == null:
		return sdk < 33
	var context = android_runtime.getApplicationContext()
	var nm = context.getSystemService("notification")
	if nm == null:
		return sdk < 33
	return bool(nm.areNotificationsEnabled())


func _ensure_android_channel() -> bool:
	if _android_channel_ready:
		return true
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		return false
	var context = android_runtime.getApplicationContext()
	if context == null:
		var activity = android_runtime.getActivity()
		if activity != null:
			context = activity
	if context == null:
		return false
	var sdk := _android_sdk_int()
	if sdk < 26:
		_android_channel_ready = true
		return true
	jw.get_exception() # clear
	var NotificationChannel = jw.wrap("android.app.NotificationChannel")
	if NotificationChannel == null:
		return false
	# IMPORTANCE_HIGH = 4
	var channel = NotificationChannel.NotificationChannel(
		String(ANDROID_CHANNEL_ID),
		String(ANDROID_CHANNEL_NAME),
		4
	)
	var err = jw.get_exception()
	if err != null or channel == null:
		push_warning("JimothyNotify: channel ctor: %s" % str(err))
		return false
	if channel.has_method("setDescription"):
		channel.setDescription("Jimothy care alerts")
	var nm = context.getSystemService("notification")
	if nm == null:
		return false
	nm.createNotificationChannel(channel)
	err = jw.get_exception()
	if err != null:
		push_warning("JimothyNotify: channel create: %s" % str(err))
		return false
	_android_channel_ready = true
	return true


func _android_small_icon_id(context) -> int:
	var resources = context.getResources()
	var pkg: String = str(context.getPackageName())
	for entry in [
		["ic_default_notification", "drawable", pkg],
		["icon", "mipmap", pkg],
		["notification_icon", "mipmap", pkg],
		["icon", "drawable", pkg],
		["ic_dialog_info", "drawable", "android"],
		["stat_notify_chat", "drawable", "android"],
		["ic_popup_reminder", "drawable", "android"],
	]:
		var id: int = int(resources.getIdentifier(str(entry[0]), str(entry[1]), str(entry[2])))
		if id != 0:
			return id
	return 17301659 # android.R.drawable.ic_dialog_info


func _android_toast(message: String) -> void:
	if OS.get_name() != "Android":
		return
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		return
	var activity = android_runtime.getActivity()
	if activity == null:
		return
	var msg := message
	var toast_callable = func() -> void:
		var ToastClass = jw.wrap("android.widget.Toast")
		ToastClass.makeText(activity, msg, ToastClass.LENGTH_LONG).show()
	activity.runOnUiThread(android_runtime.createRunnableFromGodotCallable(toast_callable))


func _android_make_builder(jw, context, channel_id: String) -> Dictionary:
	## Nested class ctor name is the LAST dotted segment: "Notification$Builder".
	## GDScript cannot write Builder.Notification$Builder(...) because $ is syntax,
	## so we must use .call("Notification$Builder", ...). Calling .Builder(...) aborts.
	var failures: PackedStringArray = []
	jw.get_exception()
	var sdk := _android_sdk_int()
	var channel := String(channel_id)
	# Godot stores nested ctors under this name (and also under a space alias).
	const CTOR := "Notification$Builder"

	var Builder = jw.wrap("android.app.Notification$Builder")
	if Builder == null:
		return {"builder": null, "detail": "wrap Notification$Builder=null"}

	# Prefer 2-arg (API 26+). Fall back to 1-arg + setChannelId.
	if sdk >= 26:
		jw.get_exception()
		var b2 = Builder.call(CTOR, context, channel)
		var err2 = jw.get_exception()
		if err2 == null and b2 != null:
			return {"builder": b2, "detail": "call Notification$Builder 2arg"}
		failures.append("2arg:%s" % str(err2))

		# Space alias used internally by JavaClassWrapper for constructors.
		jw.get_exception()
		b2 = Builder.call(" ", context, channel)
		err2 = jw.get_exception()
		if err2 == null and b2 != null:
			return {"builder": b2, "detail": "call space 2arg"}
		failures.append("space2:%s" % str(err2))

	jw.get_exception()
	var b1 = Builder.call(CTOR, context)
	var err1 = jw.get_exception()
	if err1 == null and b1 != null:
		if sdk >= 26:
			b1.setChannelId(channel)
			jw.get_exception()
		return {"builder": b1, "detail": "call Notification$Builder 1arg"}
	failures.append("1arg:%s" % str(err1))

	jw.get_exception()
	b1 = Builder.call(" ", context)
	err1 = jw.get_exception()
	if err1 == null and b1 != null:
		if sdk >= 26:
			b1.setChannelId(channel)
			jw.get_exception()
		return {"builder": b1, "detail": "call space 1arg"}
	failures.append("space1:%s" % str(err1))

	return {"builder": null, "detail": " / ".join(failures)}


func _post_android_jni(title: String, body: String) -> bool:
	last_error = "JNI start"
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		last_error = "JNI: no AndroidRuntime"
		return false

	if not _android_notifications_allowed():
		if OS.has_method("request_permission"):
			OS.request_permission(ANDROID_PERM)

	var activity = android_runtime.getActivity()
	var app_ctx = android_runtime.getApplicationContext()
	# Prefer Activity — some OEMs reject Application context for Notification.Builder.
	var context = activity if activity != null else app_ctx
	if context == null:
		last_error = "JNI: no context"
		return false

	_android_channel_ready = false
	if not _ensure_android_channel():
		push_warning("JimothyNotify: channel ensure failed; continuing")

	var icon_id := _android_small_icon_id(context)
	if icon_id == 0:
		icon_id = 17301659

	var made: Dictionary = _android_make_builder(jw, context, ANDROID_CHANNEL_ID)
	var builder = made.get("builder", null)
	if builder == null and activity != null and app_ctx != null and activity != app_ctx:
		made = _android_make_builder(jw, app_ctx, ANDROID_CHANNEL_ID)
		builder = made.get("builder", null)
		if builder != null:
			context = app_ctx
	if builder == null:
		last_error = "JNI ctor: %s" % str(made.get("detail", "failed"))
		return false

	var err = null
	builder.setSmallIcon(icon_id)
	err = jw.get_exception()
	if err != null:
		last_error = "JNI: setSmallIcon failed"
		return false
	builder.setContentTitle(String(title))
	err = jw.get_exception()
	if err != null:
		last_error = "JNI: setContentTitle failed"
		return false
	builder.setContentText(String(body))
	err = jw.get_exception()
	if err != null:
		last_error = "JNI: setContentText failed"
		return false
	builder.setAutoCancel(true)
	if _android_sdk_int() < 26 and builder.has_method("setPriority"):
		builder.setPriority(1)

	var notification = builder.build()
	err = jw.get_exception()
	if err != null or notification == null:
		last_error = "JNI: build() failed"
		return false

	var nm = context.getSystemService("notification")
	if nm == null and activity != null:
		nm = activity.getSystemService("notification")
	if nm == null:
		last_error = "JNI: no NotificationManager"
		return false

	_notify_id += 1
	nm.notify("jimothy", _notify_id, notification)
	err = jw.get_exception()
	if err != null:
		jw.get_exception()
		nm.notify(_notify_id, notification)
		err = jw.get_exception()
		if err != null:
			last_error = "JNI: notify() failed"
			return false

	if not _android_notifications_allowed():
		last_error = "Permission off in Settings"
		return false

	print(
		"JimothyNotify: posted Android JNI notification id=",
		_notify_id,
		" icon=",
		icon_id,
		" via=",
		str(made.get("detail", "?"))
	)
	last_error = ""
	return true
