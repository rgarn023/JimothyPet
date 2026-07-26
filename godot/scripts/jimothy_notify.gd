extends Node
## Care notifications — hungry / play / acting up / waste / new form.
## Android: NotificationScheduler plugin (Gradle) + UI-thread NotificationManager
## fallback + Toast confirmation so failures are visible in-game.
## Web: Notification API (+ service worker). Desktop: OS toasts.

const COOLDOWN_SEC := 12 * 60
const ANDROID_CHANNEL_ID := "jimothy_care"
const ANDROID_CHANNEL_NAME := "Jimothy care"
const ANDROID_PERM := "android.permission.POST_NOTIFICATIONS"
const SCHEDULER_SCRIPT := preload("res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd")

var _last := {
	"hungry": -999999,
	"play": -999999,
	"stubborn": -999999,
	"waste": -999999,
	"form": -999999,
}
var _android_channel_ready: bool = false
var _notify_id: int = 1100
var _perm_connected: bool = false
var _bootstrapped: bool = false
var _welcome_sent: bool = false
var _scheduler: Node = null
var _scheduler_ready: bool = false
var _scheduler_channel_ready: bool = false
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
	tree.create_timer(0.5).timeout.connect(_retry_scheduler_init)
	tree.create_timer(1.5).timeout.connect(_retry_scheduler_init)


func _retry_scheduler_init() -> void:
	if _scheduler_ready or _scheduler == null:
		return
	if Engine.has_singleton("NotificationSchedulerPlugin"):
		_scheduler.initialize()


func _on_scheduler_initialized() -> void:
	_scheduler_ready = true
	print("JimothyNotify: NotificationScheduler ready")
	_ensure_scheduler_channel()
	# Exact alarms keep the ~1s “alerts on” test reliable on Android 12+.
	if _scheduler.has_method("has_schedule_exact_alarm_permission") \
			and not _scheduler.has_schedule_exact_alarm_permission() \
			and _scheduler.has_method("request_schedule_exact_alarm_permission"):
		_scheduler.request_schedule_exact_alarm_permission()
	if PetState and PetState.alerts_enabled:
		if _scheduler.has_post_notifications_permission():
			_send_welcome_alert()
		else:
			_scheduler.request_post_notifications_permission()


func _on_scheduler_perm_granted(_permission_name: String) -> void:
	_ensure_scheduler_channel()
	_send_welcome_alert()


func _on_scheduler_perm_denied(_permission_name: String) -> void:
	last_error = "Notification permission denied"
	if PetState:
		PetState.speech.emit(
			"Phone notifications blocked — open Settings → Apps → JimothyPet → Notifications → On."
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
		"channel_description": "Hungry, play, acting up, waste, and new forms",
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
	if PetState == null:
		return
	if PetState.alerts_enabled:
		request_permission()


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


func _send_welcome_alert() -> void:
	if _welcome_sent:
		return
	if PetState == null or not PetState.alerts_enabled:
		return
	# Defer so permission grants settle; only mark sent after a real attempt.
	call_deferred("_send_welcome_alert_now")


func _send_welcome_alert_now() -> void:
	if _welcome_sent:
		return
	if PetState == null or not PetState.alerts_enabled:
		return
	# If OS permission isn’t granted yet, ask and allow a later retry.
	if OS.get_name() == "Android" and not os_permission_granted():
		if OS.has_method("request_permission"):
			OS.request_permission(ANDROID_PERM)
		if _scheduler != null and _scheduler_ready:
			_scheduler.request_post_notifications_permission()
		_android_toast("Tap Allow for Jimothy notifications")
		if PetState:
			PetState.speech.emit(
				"Allow notifications on the popup. If you don’t see one: phone Settings → Apps → JimothyPet → Notifications → On, then tap Alerts."
			)
		return

	var ok := _post(
		"Jimothy alerts on",
		"Phone alerts for hunger, play, acting up, waste, and new forms."
	)
	_welcome_sent = true
	if ok:
		last_error = ""
		if PetState:
			PetState.speech.emit("Phone alert sent — pull down the notification shade.")
		_android_toast("Jimothy alert sent")
	else:
		last_error = last_error if last_error != "" else "notify failed"
		if PetState:
			PetState.speech.emit("Alert failed: %s" % last_error)
		_android_toast("Alert failed: %s" % last_error.substr(0, 40))
	check_now()


func _on_permissions_result(permission: String, granted: bool) -> void:
	if permission != ANDROID_PERM:
		return
	if granted:
		_send_welcome_alert()
	elif PetState:
		last_error = "Notification permission denied"
		PetState.speech.emit(
			"Notification permission denied — enable it in Android Settings → Apps → JimothyPet."
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		check_now()


func _on_state() -> void:
	check_now()


func _on_stage(stage: String) -> void:
	if PetState == null or not PetState.alerts_enabled:
		return
	if stage in ["bush"]:
		return
	var body := ""
	match stage:
		"baby":
			body = "Baby kit Jimothy burst from the bush!"
		"young":
			body = "Young kit form: %s. Check Form paths for his forks." % PetState.young_form.capitalize()
		"teen":
			var teen_label := PetState.teen_form.capitalize() if PetState.teen_form != "" else "Teen"
			body = "Teen kit form: %s. Adult flair is taking shape." % teen_label
		"adult":
			body = "%s Jimothy — fully grown short-spine cryptid." % PetState.adult_form_title()
		_:
			return
	_try_send("form", "Jimothy found a new form", body, Time.get_unix_time_from_system(), true)


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


## Allow UI to force a fresh welcome/test notification on the next grant.
func reset_welcome() -> void:
	_welcome_sent = false


## Call when the player turns Alerts on — requests OS / browser permission.
func request_permission() -> void:
	_connect_permission_signal()
	if OS.has_feature("web"):
		request_permission_web()
		return
	if OS.get_name() != "Android":
		if not _welcome_sent:
			_welcome_sent = true
			_post(
				"Jimothy alerts on",
				"Desktop alerts for hunger, play, acting up, waste, and new forms."
			)
			check_now()
		return

	# Always ask the OS directly — works with or without the Gradle plugin.
	_ensure_android_channel()
	if OS.has_method("request_permission"):
		OS.request_permission(ANDROID_PERM)
	elif OS.has_method("request_permissions"):
		OS.request_permissions()

	# Optional plugin path (only if NotificationScheduler is in the APK).
	if _scheduler != null:
		if not _scheduler_ready:
			_scheduler.initialize()
		if _scheduler_ready and not _scheduler.has_post_notifications_permission():
			_scheduler.request_post_notifications_permission()

	# If already allowed, send the test shade alert now.
	if os_permission_granted() or _android_notifications_allowed():
		_send_welcome_alert()
	else:
		last_error = "Waiting for notification permission"
		_android_toast("Allow Jimothy notifications")


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


func _post_android_jni(title: String, body: String) -> bool:
	# Step markers stay in last_error so a mid-function crash still reports
	# where it died (instead of the generic "JNI notify failed").
	last_error = "JNI:start"
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		last_error = "JNI: no AndroidRuntime"
		return false

	if not _android_notifications_allowed():
		if OS.has_method("request_permission"):
			OS.request_permission(ANDROID_PERM)

	last_error = "JNI:context"
	var activity = android_runtime.getActivity()
	var context = android_runtime.getApplicationContext()
	if context == null and activity != null:
		context = activity
	if context == null:
		last_error = "JNI: no context"
		return false

	last_error = "JNI:channel"
	_android_channel_ready = false
	if not _ensure_android_channel():
		last_error = "JNI: channel failed"
		return false

	last_error = "JNI:icon"
	var icon_id := _android_small_icon_id(context)
	if icon_id == 0:
		icon_id = 17301659 # android.R.drawable.ic_dialog_info

	last_error = "JNI:builder"
	jw.get_exception() # clear
	var Builder = jw.wrap("android.app.Notification$Builder")
	if Builder == null:
		last_error = "JNI: Builder wrap failed"
		return false

	# IMPORTANT: Use the 1-arg constructor only.
	# Godot's JavaClassWrapper often fails to resolve the overloaded
	# Builder(Context, String) and returns null ("JNI: Builder ctor failed").
	# On API 26+ we call setChannelId() afterward instead.
	var builder = null
	var err = null
	# Prefer Activity context; some devices reject Application context here.
	for ctx in [activity, context]:
		if ctx == null:
			continue
		jw.get_exception()
		builder = Builder.Builder(ctx)
		err = jw.get_exception()
		if err == null and builder != null:
			context = ctx
			break
		builder = null
	if builder == null:
		last_error = "JNI: Builder ctor failed"
		return false

	last_error = "JNI:channelId"
	var sdk := _android_sdk_int()
	if sdk >= 26:
		builder.setChannelId(String(ANDROID_CHANNEL_ID))
		err = jw.get_exception()
		if err != null:
			last_error = "JNI: setChannelId failed"
			return false

	last_error = "JNI:setters"
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
	if sdk < 26:
		builder.setPriority(1)

	last_error = "JNI:build"
	var notification = builder.build()
	err = jw.get_exception()
	if err != null or notification == null:
		last_error = "JNI: build() failed"
		return false

	last_error = "JNI:manager"
	var nm = context.getSystemService("notification")
	if nm == null and activity != null:
		nm = activity.getSystemService("notification")
	if nm == null:
		last_error = "JNI: no NotificationManager"
		return false

	last_error = "JNI:notify"
	_notify_id += 1
	# Use the 3-arg overload (tag, id, notification). The 2-arg notify(id, n)
	# can collide with Godot Object / Java Object method resolution.
	nm.notify("jimothy", _notify_id, notification)
	err = jw.get_exception()
	if err != null:
		# Fallback: try 2-arg form.
		jw.get_exception()
		nm.notify(_notify_id, notification)
		err = jw.get_exception()
		if err != null:
			last_error = "JNI: notify() failed"
			return false

	if not _android_notifications_allowed():
		last_error = "Permission off in Settings"
		return false

	print("JimothyNotify: posted Android JNI notification id=", _notify_id, " icon=", icon_id)
	last_error = ""
	return true
