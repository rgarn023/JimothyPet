extends Node
## Care notifications — hungry / play / acting up / waste / new form.
## Posts real OS / browser notifications (not only in-game banners):
## - Android: NotificationManager via JavaClassWrapper
## - Web export: Notification API (+ service worker when available)
## - Linux: notify-send · macOS: osascript · Windows: PowerShell toast
## Cooldown prevents spam (form milestones bypass care cooldown).

const COOLDOWN_SEC := 12 * 60
const ANDROID_CHANNEL_ID := "jimothy_care"
const ANDROID_CHANNEL_NAME := "Jimothy care"

var _last := {
	"hungry": -999999,
	"play": -999999,
	"stubborn": -999999,
	"waste": -999999,
	"form": -999999,
}
var _android_channel_ready: bool = false
var _notify_id: int = 1001


func _ready() -> void:
	if PetState:
		PetState.state_changed.connect(_on_state)
		PetState.stage_changed.connect(_on_stage)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
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
	if OS.has_feature("web"):
		request_permission_web()
		return
	if OS.get_name() == "Android":
		# Runtime prompt on Android 13+ (export preset includes POST_NOTIFICATIONS).
		OS.request_permissions()
		_ensure_android_channel()


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
	if not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime")


func _jw():
	# JavaClassWrapper is an Engine singleton (Android). Guarded callers only use this on Android.
	if Engine.has_singleton("JavaClassWrapper"):
		return Engine.get_singleton("JavaClassWrapper")
	return null


func _ensure_android_channel() -> bool:
	if _android_channel_ready:
		return true
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		return false
	var context = android_runtime.getApplicationContext()
	var NotificationChannel = jw.wrap("android.app.NotificationChannel")
	var Build = jw.wrap("android.os.Build$VERSION")
	var sdk: int = int(Build.SDK_INT)
	if sdk >= 26:
		# IMPORTANCE_DEFAULT = 3
		var channel = NotificationChannel.NotificationChannel(
			ANDROID_CHANNEL_ID,
			ANDROID_CHANNEL_NAME,
			3
		)
		channel.setDescription("Hungry, play, acting up, waste, and new forms")
		var nm = context.getSystemService("notification")
		nm.createNotificationChannel(channel)
	_android_channel_ready = true
	return true


func _android_small_icon_id(jw, context) -> int:
	var resources = context.getResources()
	var package_name: String = str(context.getPackageName())
	for pair in [["icon", "mipmap"], ["icon", "drawable"], ["notification_icon", "drawable"]]:
		var id: int = int(resources.getIdentifier(str(pair[0]), str(pair[1]), package_name))
		if id != 0:
			return id
	var sys = jw.wrap("android.R$drawable")
	return int(sys.ic_dialog_info)


func _post_android(title: String, body: String) -> bool:
	var android_runtime = _android_runtime()
	var jw = _jw()
	if android_runtime == null or jw == null:
		push_warning("JimothyNotify: Android notify bridge unavailable in this build.")
		return false
	if not _ensure_android_channel():
		return false

	var activity = android_runtime.getActivity()
	if activity == null:
		return false

	var do_post := func():
		var context = android_runtime.getApplicationContext()
		var Builder = jw.wrap("android.app.Notification$Builder")
		var PendingIntent = jw.wrap("android.app.PendingIntent")
		var Build = jw.wrap("android.os.Build$VERSION")
		var sdk: int = int(Build.SDK_INT)

		var builder
		if sdk >= 26:
			builder = Builder.Builder(context, ANDROID_CHANNEL_ID)
		else:
			builder = Builder.Builder(context)

		builder.setContentTitle(title)
		builder.setContentText(body)
		builder.setSmallIcon(_android_small_icon_id(jw, context))
		builder.setAutoCancel(true)
		if sdk < 26:
			builder.setPriority(0) # PRIORITY_DEFAULT

		var launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName())
		if launch != null:
			launch.addFlags(268435456) # FLAG_ACTIVITY_NEW_TASK
			var flags := 201326592 # FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE
			if sdk < 23:
				flags = 134217728 # FLAG_UPDATE_CURRENT only
			var pending = PendingIntent.getActivity(context, 0, launch, flags)
			builder.setContentIntent(pending)

		var nm = context.getSystemService("notification")
		_notify_id += 1
		nm.notify(_notify_id, builder.build())

	activity.runOnUiThread(android_runtime.createRunnableFromGodotCallable(do_post))
	return true
