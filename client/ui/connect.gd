extends Control

var status_label: Label
var connect_btn: Button
var single_btn: Button


func _ready() -> void:
    UIKit.bg(self, "bg_title.png")
    UIKit.dim(self, 0.35)
    Net.connected_to_server.connect(_on_connected)
    Net.connection_failed.connect(_on_failed)
    Net.server_disconnected.connect(_on_disconnected)
    _build()


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
    v.add_child(UIKit.title("选择模式", 38))
    v.add_child(UIKit.label("账号由设备硬件码自动注册，无需密码。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))

    status_label = UIKit.label("点「联机模式」自动连接服务器。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
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
    v.add_child(UIKit.label("单机模式无需服务器，直接 1v1 人机。", 16, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER))


func _connect() -> void:
    if Net.connected:
        App.goto("menu")
        return
    status_label.text = "连接中…"
    status_label.add_theme_color_override("font_color", UIKit.GOLD)
    connect_btn.disabled = true
    single_btn.disabled = true
    var target := App.server_target()
    var err := Net.connect_to(str(target.get("host", "")), int(target.get("port", 0)))
    if err != OK:
        status_label.text = "无法连接服务器，请稍后重试"
        status_label.add_theme_color_override("font_color", UIKit.RED)
        connect_btn.disabled = false
        single_btn.disabled = false


func _on_connected() -> void:
    status_label.text = "已连接，正在登录…"
    Net.send_to_server({"t": "hello", "hwid": App.device_id()})


func _on_failed() -> void:
    status_label.text = "连接失败，请稍后重试"
    status_label.add_theme_color_override("font_color", UIKit.RED)
    connect_btn.disabled = false
    single_btn.disabled = false


func _on_disconnected() -> void:
    status_label.text = "与服务器断开"
    status_label.add_theme_color_override("font_color", UIKit.RED)
    connect_btn.disabled = false
    single_btn.disabled = false


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
