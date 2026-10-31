extends Control

var name_edit: LineEdit
var status_label: Label
var confirm_btn: Button
var back_btn: Button
var had_name := false


func _ready() -> void:
    had_name = str(App.account.get("name", "")) != ""
    UIKit.bg(self, "bg_room.png")
    UIKit.dim(self, 0.45)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := UIKit.panel()
    panel.custom_minimum_size = Vector2(780, 480)
    center.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 40)
    margin.add_theme_constant_override("margin_right", 40)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_bottom", 30)
    panel.add_child(margin)
    var v := UIKit.vbox(16)
    margin.add_child(v)
    v.add_child(UIKit.title("起个名字", 42))
    v.add_child(UIKit.label("用户名会显示在联机房间与好友列表里。\n2~12 个字符，不能与现有玩家重复。", 19, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    name_edit = LineEdit.new()
    name_edit.max_length = 12
    name_edit.custom_minimum_size = Vector2(0, 64)
    name_edit.placeholder_text = "输入用户名"
    name_edit.text = str(App.account.get("name", ""))
    name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(name_edit)
    status_label = UIKit.label("", 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    status_label.custom_minimum_size = Vector2(0, 30)
    v.add_child(status_label)
    var bh := UIKit.hbox(16)
    bh.alignment = BoxContainer.ALIGNMENT_CENTER
    confirm_btn = UIKit.button("确定", 260, 64)
    confirm_btn.pressed.connect(_submit)
    bh.add_child(confirm_btn)
    if had_name:
        back_btn = UIKit.button("返回", 260, 64)
        back_btn.pressed.connect(func(): App.goto("menu"))
        bh.add_child(back_btn)
    v.add_child(bh)
    v.add_child(UIKit.label("设备账号已自动创建，改名不会丢失好友与记录。", 15, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER))
    name_edit.text_submitted.connect(func(_t): _submit())


func _submit() -> void:
    var n := name_edit.text.strip_edges()
    if n.length() < 2 or n.length() > 12:
        status_label.text = "需要 2~12 个字符"
        status_label.add_theme_color_override("font_color", UIKit.RED)
        return
    confirm_btn.disabled = true
    status_label.text = "保存中…"
    status_label.add_theme_color_override("font_color", UIKit.GOLD)
    App.send({"t": "set_name", "name": n})


func on_account(account: Dictionary) -> void:
    var n := str(account.get("name", ""))
    if n != "":
        App.account = account
        App.goto("menu" if had_name else "lobby")
    else:
        confirm_btn.disabled = false
        status_label.text = "改名失败，请重试"
        status_label.add_theme_color_override("font_color", UIKit.RED)


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
    confirm_btn.disabled = false
    status_label.text = msg
    status_label.add_theme_color_override("font_color", UIKit.RED)
