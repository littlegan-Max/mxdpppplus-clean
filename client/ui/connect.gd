extends Control

var status_label: Label
var connect_btn: Button
var single_btn: Button
var _busy := false


func _ready() -> void:
    UIKit.bg(self, "bg_title.png")
    UIKit.dim(self, 0.35)
    Net.connected_to_server.connect(_on_connected)
    Net.connection_failed.connect(_on_failed)
    Net.server_disconnected.connect(_on_disconnected)
    _build()
    if Net.connected:
        App.goto("lobby")
        return
    if str(App.server_target().get("host", "")) == "":
        _set_status("未配置服务器地址，请联系服主", UIKit.RED)
        connect_btn.disabled = true
    else:
        call_deferred("_connect")


func _build() -> void:
    var logo := TextureRect.new()
    logo.texture = UIKit.art("logo.png")
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
    logo.position = Vector2(-470, 44)
    logo.size = Vector2(940, 235)
    add_child(logo)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := UIKit.panel()
    panel.custom_minimum_size = Vector2(760, 380)
    center.add_child(panel)
    var outer := MarginContainer.new()
    outer.add_theme_constant_override("margin_left", 34)
    outer.add_theme_constant_override("margin_right", 34)
    outer.add_theme_constant_override("margin_top", 26)
    outer.add_theme_constant_override("margin_bottom", 26)
    panel.add_child(outer)
    var v := UIKit.vbox(16)
    outer.add_child(v)
    v.add_child(UIKit.title("联机模式", 38))
    v.add_child(UIKit.label("账号由设备硬件码自动注册，无需密码。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))

    status_label = UIKit.label("正在连接服务器…", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
    status_label.custom_minimum_size = Vector2(0, 40)
    v.add_child(status_label)

    var bh := UIKit.hbox(16)
    bh.alignment = BoxContainer.ALIGNMENT_CENTER
    connect_btn = UIKit.button("联机模式", 300, 66)
    connect_btn.pressed.connect(_connect)
    single_btn = UIKit.button("单机模式", 300, 66)
    single_btn.pressed.connect(func(): App.goto("single"))
    bh.add_child(connect_btn)
    bh.add_child(single_btn)
    v.add_child(bh)
    v.add_child(UIKit.label("点击「联机模式」直接进入服务器，无需填写任何信息。", 16, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER, true))


func _connect() -> void:
    if _busy:
        return
    if Net.connected:
        App.goto("lobby")
        return
    var target := App.server_target()
    var host := str(target.get("host", ""))
    var port := int(target.get("port", 7777))
    if host == "":
        _set_status("未配置服务器地址，请联系服主", UIKit.RED)
        connect_btn.disabled = true
        return
    _set_busy(true)
    _set_status("正在连接服务器…", UIKit.GOLD)
    print("[client] connecting to %s:%d" % [host, port])
    var err := Net.connect_to(host, port)
    if err != OK:
        _set_status("无法连接服务器，请稍后重试", UIKit.RED)
        _set_busy(false)


func _set_status(text: String, color: Color) -> void:
    status_label.text = text
    status_label.add_theme_color_override("font_color", color)


func _set_busy(busy: bool) -> void:
    _busy = busy
    connect_btn.disabled = busy
    single_btn.disabled = busy


func _on_connected() -> void:
    _set_status("已连接，正在登录…", UIKit.GOLD)
    Net.send_to_server({"t": "hello", "hwid": App.device_id()})


func _on_failed() -> void:
    _set_status("连接失败，请点击「联机模式」重试", UIKit.RED)
    _set_busy(false)


func _on_disconnected() -> void:
    _set_status("与服务器断开，请点击「联机模式」重连", UIKit.RED)
    _set_busy(false)


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
