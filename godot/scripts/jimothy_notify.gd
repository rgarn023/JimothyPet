extends Node
## Care notifications — hungry / play / acting up / waste / new form.
## Posts real OS / browser notifications (not only in-game banners):
## - Android: NotificationManager via JavaClassWrapper + AndroidRuntime
## - Web export: Notification API (+ service worker when available)
## - Linux: notify-send · macOS: osascript · Windows: PowerShell toast

const COOLDOWN_SEC := 12 * 60
const ANDROID_CHANNEL_ID := "jimothy_care"
const ANDROID_CHANNEL_NAME := "Jimothy care"
const ANDROID_PERM := "android.permission.POST_NOTIFICATIONS"

var _last := {
	"hungry": -999999,
	"play": -999999,
	"stubborn": -999999,
	"waste": -999999,
	"form": -999999,
}
var _android_channel_ready: bool = false
var _notify_id: int = 1001
var _perm_connected: bool = false


func _ready() -> void:
	if PetState:
		PetState.state_changed.connect(_on_state)
		PetState.stage_changed.connect(_on_stage)
	_connect_permission_signal()


func _connect_permission_signal() -> void:
	if _perm_connected:
		return
	var tree := get_tree()
	if tree and tree.has_signal("on_request_permissions_result"):
		tree.on_request_permissions_result.connect(_on_permissions_result)
		_perm_connected = true


func _on_permissions_result(permission: String, granted: bool) -> void:
	if permission != ANDROID_PERM:
		return
	if granted and PetState and PetState.alerts_enabled:
		_ensure_android_channel()
		_post(
			"Jimothy alerts on",
			"Phone alerts for hunger, play, acting up, waste, and new forms."
		)
		check_now()
	elif not granted and PetState:
		PetState.speech.emit("Notification permission denied — enable it in Android Settings → Apps → JimothyPet.")


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


## Call when the player turns Alerts on — requests OS / browser permission.
func request_permission() -> void:
	_connect_permission_signal()
	if OS.has_feature("web"):
		request_permission_web()
		return
	if OS.get_name() == "Android":
		_ensure_android_channel()
		# Returns true if already granted; false if a system prompt was shown.
		var already_granted := false
		if OS.has_method("request_permission"):
			already_granted = OS.request_permission(ANDROID_PERM)
		else:
			already_granted = OS.request_permissions()
		if already_granted or _android_notifications_allowed():
			_post(
				"Jimothy alerts on",
				"Phone alerts for hunger, play, acting up, waste, and new forms."
			)
			check_now()
		# Otherwise wait for MainLoop.on_request_permissions_result.


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
		return 0
	var Build = jw.wrap("android.os.Build$VERSION")
	return int(Build.SDK_INT)


func _android_notifications_allowed() -> bool:
	if OS.get_name() != "Android":
		return false
	var sdk := _android_sdk_int()
	if sdk >= 33:
		var granted: PackedStringArray = OS.get_granted_permissions()
		var has_perm := false
		for p in granted:
			if str(p) == ANDROID_PERM:
				has_perm = true
				break
		if not has_perm:
			return false
	var android_runtime = _android_runtime()
	if android_runtime == null:
		# Permission list said yes (or pre-33) but runtime missing — allow attempt.
		return sdk > 0 and sdk < 33
	var context = android_runtime.getApplicationContext()
	var nm = context.getSystemService("notification")
	if nm == null:
		return true
	return bool(nm.areNotificationsEnabled())


func _ensure_android_channel() -> bool:
	if _android_channel_ready:
		return true
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		push_warning("JimothyNotify: AndroidRuntime/JavaClassWrapper missing.")
		return false
	var context = android_runtime.getApplicationContext()
	var sdk := _android_sdk_int()
	if sdk >= 26:
		var NotificationChannel = jw.wrap("android.app.NotificationChannel")
		# IMPORTANCE_HIGH = 4 (heads-up + shade)
		var channel = NotificationChannel.NotificationChannel(
			ANDROID_CHANNEL_ID,
			ANDROID_CHANNEL_NAME,
			4
		)
		channel.setDescription("Hungry, play, acting up, waste, and new forms")
		var nm = context.getSystemService("notification")
		nm.createNotificationChannel(channel)
		var err = jw.get_exception()
		if err != null:
			push_warning("JimothyNotify: channel error: %s" % str(err))
			return false
	_android_channel_ready = true
	return true


func _android_small_icon_id(context) -> int:
	# MUST be a white/alpha system status icon. Full-color launcher mipmaps are rejected.
	var resources = context.getResources()
	for name in ["ic_dialog_info", "stat_notify_chat", "ic_menu_info_details", "ic_popup_reminder"]:
		var id: int = int(resources.getIdentifier(name, "drawable", "android"))
		if id != 0:
			return id
	return 17301659 # android.R.drawable.ic_dialog_info fallback constant


func _post_android(title: String, body: String) -> bool:
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		push_warning("JimothyNotify: Android notify bridge unavailable.")
		return false
	if not _android_notifications_allowed():
		push_warning("JimothyNotify: POST_NOTIFICATIONS not granted.")
		# Ask again so a later care event can succeed after the user accepts.
		if OS.has_method("request_permission"):
			OS.request_permission(ANDROID_PERM)
		return false
	if not _ensure_android_channel():
		return false

	var context = android_runtime.getApplicationContext()
	var Builder = jw.wrap("android.app.Notification$Builder")
	var PendingIntent = jw.wrap("android.app.PendingIntent")
	var sdk := _android_sdk_int()

	var builder
	if sdk >= 26:
		builder = Builder.Builder(context, ANDROID_CHANNEL_ID)
	else:
		builder = Builder.Builder(context)

	var icon_id := _android_small_icon_id(context)
	builder.setSmallIcon(icon_id)
	builder.setContentTitle(title)
	builder.setContentText(body)
	builder.setAutoCancel(true)
	builder.setOnlyAlertOnce(false)
	if sdk < 26:
		builder.setPriority(1) # PRIORITY_HIGH
	else:
		# Help some OEMs show while app is foregrounded.
		builder.setVisibility(1) # VISIBILITY_PUBLIC

	var launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName())
	if launch != null:
		launch.addFlags(268435456) # FLAG_ACTIVITY_NEW_TASK
		var flags := 201326592 # FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE
		if sdk < 23:
			flags = 134217728
		var pending = PendingIntent.getActivity(context, _notify_id, launch, flags)
		builder.setContentIntent(pending)

	var notification = builder.build()
	var err = jw.get_exception()
	if err != null:
		push_warning("JimothyNotify: build failed: %s" % str(err))
		return false

	var nm = context.getSystemService("notification")
	_notify_id += 1
	# NotificationManager.notify is thread-safe — call directly (UI-thread runnable was dropping errors).
	nm.notify(_notify_id, notification)
	err = jw.get_exception()
	if err != null:
		push_warning("JimothyNotify: notify failed: %s" % str(err))
		return false
	print("JimothyNotify: posted Android notification id=", _notify_id, " title=", title)
	return true
