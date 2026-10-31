extends Node

## Application root. Starts either the dedicated server (headless / --server)
## or the client UI. Screens are built in code by client/ui/*.gd.

var server_mode := false
var server_main: Node = null
var account: Dictionary = {}
var friends: Array = []
var friend_requests: Array = []
var rooms: Array = []
var room: Dictionary = {}
var online_count := 0
var invite: Dictionary = {}
var battle_state: Dictionary = {}
var battle_turn: Dictionary = {}
var pending_battle_start: Dictionary = {}
var battle_mode := "online"
var local_engine: BattleEngine = null
var local_cheat := false
var local_ai_pid := 1
var local_turn_deadline := 0.0
var local_reveal_timer := 0.0
var last_error := ""

var ui_layer: CanvasLayer = null
var current_screen: Control = null
var active_screen: Control = null
var _screens := {}

var update_checker: Node = null
var update_info: Dictionary = {}
var _update_checked := false
var _update_manual := false


func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    var all_args := OS.get_cmdline_args()
    server_mode = args.has("--server") or all_args.has("--server") or OS.has_feature("dedicated_server")
    if args.has("--no-ui") or all_args.has("--no-ui"):
        return
    if server_mode:
        var script = load("res://server/server_main.gd")
        if script == null:
            push_error("缺少 server_main.gd")
            return
        server_main = script.new()
        server_main.name = "ServerMain"
        add_child(server_main)
        var port := int(OS.get_environment("MXD_PORT")) if OS.get_environment("MXD_PORT") != "" else 7777
        for a in args:
            if str(a).begins_with("--port="):
                port = int(str(a).substr(7))
        for a in all_args:
            if str(a).begins_with("--port="):
                port = int(str(a).substr(7))
        var err := Net.start_server(port)
        if err != OK:
            push_error("服务端启动失败: %d" % err)
        else:
            print("[server] listening on 0.0.0.0:%d" % port)
    else:
        setup_client()


func setup_client() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 10
    add_child(ui_layer)
    var root := Control.new()
    root.name = "UIRoot"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.theme = UIKit.make_theme()
    ui_layer.add_child(root)
    current_screen = root
    if OS.has_feature("mobile"):
        _apply_mobile_safe_area(root)
        get_viewport().size_changed.connect(func(): _apply_mobile_safe_area(root))
    Net.msg_received.connect(_on_net_message)
    Net.connected_to_server.connect(_on_connected)
    Net.connection_failed.connect(_on_connect_failed)
    Net.server_disconnected.connect(_on_server_disconnected)
    var uc = load("res://client/update_check.gd")
    if uc != null:
        update_checker = uc.new()
        update_checker.name = "UpdateChecker"
        add_child(update_checker)
        update_checker.checked.connect(_on_update_checked)
    _show("connect")
    check_updates(false)


func _apply_mobile_safe_area(root: Control) -> void:
    # 手机横屏时把界面整体右移，避开左侧摄像头/挖孔。
    var scr := DisplayServer.screen_get_size()
    var safe := DisplayServer.get_display_safe_area()
    var ratio := 0.0
    if scr.x > 0 and safe.size.x > 0:
        ratio = clampf(float(safe.position.x) / float(scr.x), 0.0, 0.12)
    var view_w := float(get_viewport().get_visible_rect().size.x)
    if view_w <= 0.0:
        view_w = 1920.0
    var inset := maxf(view_w * ratio, view_w * 0.028)
    UIKit.safe_left = inset
    root.offset_left = inset


func _show(screen_name: String) -> void:
    if current_screen == null:
        return
    var screen_script_path := "res://client/ui/%s.gd" % screen_name
    var script = load(screen_script_path)
    if script == null:
        push_error("找不到界面: " + screen_script_path)
        return
    if current_screen.get_child_count() > 0:
        for c in current_screen.get_children():
            c.queue_free()
    var screen: Control = script.new()
    screen.name = screen_name.capitalize()
    screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    current_screen.add_child(screen)
    active_screen = screen
    _screens[screen_name] = screen


func goto(screen_name: String) -> void:
    _show(screen_name)


func app_version() -> String:
    return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))


func check_updates(manual: bool = false) -> void:
    if update_checker == null:
        return
    if _update_checked and not manual:
        return
    _update_checked = true
    _update_manual = manual
    if manual:
        _toast("正在检查更新…")
    update_checker.check(app_version())


func _on_update_checked(result: Dictionary) -> void:
    update_info = result
    var manual := _update_manual
    if bool(result.get("ok", false)) and bool(result.get("newer", false)):
        _toast("发现新版本 %s" % str(result.get("latest", "")))
        if active_screen and active_screen.has_method("on_update_available"):
            active_screen.on_update_available(update_info)
    elif manual:
        if bool(result.get("ok", false)):
            _toast("已是最新版本 %s" % app_version())
        else:
            _toast("检查更新失败：无法连接更新源")
    _update_manual = false


func _on_connected() -> void:
    pass


func _on_connect_failed() -> void:
    if active_screen and active_screen.has_method("on_net_error"):
        active_screen.on_net_error("无法连接服务器")


func _on_server_disconnected() -> void:
    account.clear()
    room.clear()
    goto("connect")


func _on_net_message(from_id: int, data: Dictionary) -> void:
    if server_mode:
        if server_main != null:
            server_main.on_client_message(from_id, data)
        return
    var t := str(data.get("t", ""))
    match t:
        "error":
            var emsg := str(data.get("msg", "操作失败"))
            _toast(emsg)
            if active_screen and active_screen.has_method("on_error"):
                active_screen.on_error(emsg)
        "hello_ok":
            account = data.get("account", {})
            friends = data.get("friends", [])
            friend_requests = data.get("requests", [])
            if str(account.get("name", "")) == "":
                goto("name")
            else:
                goto("menu")
        "account":
            account = data.get("account", {})
            if active_screen and active_screen.has_method("on_account"):
                active_screen.on_account(account)
        "rank":
            account["rank"] = data.get("rank", {})
            _toast("段位 %s  %s" % [str(data.get("label", "")), str(data.get("delta", ""))])
            if active_screen and active_screen.has_method("on_rank"):
                active_screen.on_rank(account.get("rank", {}), data)
        "friends":
            friends = data.get("friends", [])
            friend_requests = data.get("requests", [])
            if active_screen and active_screen.has_method("on_friends"):
                active_screen.on_friends(friends)
        "friend_request":
            _toast("%s 请求加你为好友" % data.get("from_name", "某人"))
            if active_screen and active_screen.has_method("on_friend_request"):
                active_screen.on_friend_request(data)
        "rooms":
            rooms = data.get("rooms", [])
            if active_screen and active_screen.has_method("on_rooms"):
                active_screen.on_rooms(rooms)
        "online":
            online_count = int(data.get("count", 0))
            if active_screen and active_screen.has_method("on_online"):
                active_screen.on_online(online_count)
        "invite_all_ok":
            var invited := int(data.get("count", 0))
            _toast("已向 %d 位在线玩家发送邀请" % invited if invited > 0 else "当前没有其他在线玩家")
        "room":
            room = data.get("room", {})
            if active_screen and active_screen.has_method("on_room"):
                active_screen.on_room(room)
            elif active_screen and active_screen.name == "Lobby":
                goto("room")
        "room_left":
            room.clear()
            goto("lobby")
        "room_closed":
            room.clear()
            _toast("房间已关闭")
            goto("lobby")
        "invite":
            invite = data
            _toast("%s 邀请你加入房间" % data.get("from_name", "好友"))
            if active_screen and active_screen.has_method("on_invite"):
                active_screen.on_invite(invite)
            _show_invite_dialog(invite)
        "battle_start":
            pending_battle_start = data
            goto("battle")
        "battle_turn":
            battle_turn = data
            if active_screen and active_screen.has_method("on_turn"):
                active_screen.on_turn(battle_turn)
        "battle_reveal":
            if active_screen and active_screen.has_method("on_reveal"):
                active_screen.on_reveal(data)
        "battle_ack":
            if active_screen and active_screen.has_method("on_ack"):
                active_screen.on_ack(data)
        "battle_players":
            if active_screen and active_screen.has_method("on_players"):
                active_screen.on_players(data)
        "battle_end":
            if active_screen and active_screen.has_method("on_battle_end"):
                active_screen.on_battle_end(data)
        "kicked":
            _toast("你被房主移出了房间")
            room.clear()
            goto("lobby")
        "room_state_invite":
            goto("room")


func _toast(text: String) -> void:
    last_error = text
    if active_screen and active_screen.has_method("toast"):
        active_screen.toast(text)
    else:
        print("[toast] ", text)


func send(data: Dictionary) -> void:
    Net.send_to_server(data)


func my_pid() -> int:
    return int(account.get("pid", 0))


func my_peer_id() -> int:
    if Net.peer == null:
        return 1
    return int(multiplayer.get_unique_id())


var _device_cache := ""


func device_id() -> String:
    if _device_cache != "":
        return _device_cache
    var raw := OS.get_unique_id()
    if raw == "":
        raw = OS.get_environment("COMPUTERNAME") + "|" + OS.get_environment("HOSTNAME") + "|" + OS.get_processor_name()
    if raw.strip_edges() == "||":
        if FileAccess.file_exists("user://device_id.txt"):
            raw = FileAccess.get_file_as_string("user://device_id.txt")
        else:
            raw = "%d-%d-%d" % [Time.get_ticks_usec(), randi(), Time.get_ticks_msec()]
            var f := FileAccess.open("user://device_id.txt", FileAccess.WRITE)
            if f:
                f.store_string(raw)
                f.close()
    _device_cache = raw.sha256_text()
    return _device_cache


func server_target() -> Dictionary:
    # 连接目标来自未开源的 client/server_target.gd；
    # 开源构建缺少该文件时回退到本机地址。
    if ResourceLoader.exists("res://client/server_target.gd"):
        var script = load("res://client/server_target.gd")
        if script != null:
            var t = script.target()
            if typeof(t) == TYPE_DICTIONARY and str(t.get("host", "")) != "":
                return {"host": str(t["host"]), "port": int(t.get("port", 7777))}
    return {"host": "127.0.0.1", "port": 7777}


func start_single(cheat: bool) -> void:
    battle_mode = "local"
    local_cheat = cheat
    local_ai_pid = 1
    local_engine = BattleEngine.new()
    var my_name := str(account.get("name", "你"))
    if my_name == "":
        my_name = "你"
    local_engine.setup([
        {"name": my_name, "team": 0, "avatar": int(account.get("avatar", 0))},
        {"name": "机灵鬼", "team": 1, "is_ai": true, "avatar": 3},
    ], {"turn_time": 0, "cheat_mode": cheat, "mode": "single", "seed": randi(),
        "ai_bias": AiMemory.snapshot()})
    pending_battle_start = {}
    battle_turn = {}
    goto("battle")


func leave_to_menu() -> void:
    if Net.is_client and Net.connected:
        Net.send_to_server({"t": "room_leave"})
    room.clear()
    battle_mode = "online"
    local_engine = null
    goto("menu")


func _show_invite_dialog(data: Dictionary) -> void:
    if active_screen == null:
        return
    UIKit.confirm(active_screen, "房间邀请",
        "%s 邀请你加入房间 %s" % [data.get("from_name", "好友"), data.get("room_id", "")],
        func():
            send({"t": "invite_respond", "room_id": data.get("room_id", ""), "accept": true}),
        func():
            send({"t": "invite_respond", "room_id": data.get("room_id", ""), "accept": false}))

