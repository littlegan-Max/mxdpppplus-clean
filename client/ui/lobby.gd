extends Control

var room_list: VBoxContainer
var empty_label: Label
var join_edit: LineEdit
var refresh_btn: Button
var online_label: Label
var create_layer: CanvasLayer
var public_check: CheckBox
var max_spin: SpinBox
var ai_check: CheckBox
var time_spin: SpinBox
var ff_check: CheckBox
var cheat_check: CheckBox


func _ready() -> void:
    UIKit.bg(self, "bg_lobby.png")
    UIKit.dim(self, 0.4)
    _build()
    App.send({"t": "rooms_list"})
    on_rooms(App.rooms)
    on_online(App.online_count)


func _build() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 44)
    margin.add_theme_constant_override("margin_right", 44)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 28)
    add_child(margin)
    var root := UIKit.vbox(14)
    margin.add_child(root)

    var head := UIKit.hbox(14)
    var back := UIKit.small_button("← 个人中心", 180, 52, 20)
    back.pressed.connect(func(): App.goto("menu"))
    head.add_child(back)
    head.add_child(UIKit.label("多人联机 · 大厅", 34, UIKit.GOLD))
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    online_label = UIKit.label("在线 0 人", 18, UIKit.CYAN)
    head.add_child(online_label)
    var single_btn := UIKit.small_button("单人模式", 132, 52, 20)
    single_btn.pressed.connect(func(): App.goto("single"))
    head.add_child(single_btn)
    refresh_btn = UIKit.small_button("刷新", 120, 52, 20)
    refresh_btn.pressed.connect(func(): App.send({"t": "rooms_list"}))
    head.add_child(refresh_btn)
    var friends_btn := UIKit.small_button("好友", 120, 52, 20)
    friends_btn.pressed.connect(func(): App.goto("friends"))
    head.add_child(friends_btn)
    root.add_child(head)
    root.add_child(UIKit.divider(0.4, 1.0))

    var content := UIKit.hbox(16)
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(content)
    var left := UIKit.panel()
    left.add_theme_stylebox_override("panel", UIKit.gilded_style())
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(left)
    var lv := UIKit.vbox(10)
    left.add_child(lv)
    lv.add_child(UIKit.label("公开房间", 24, UIKit.CYAN))
    lv.add_child(UIKit.label("私密房间不会出现在列表，可用房号或好友邀请进入。", 16, UIKit.GREY))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    lv.add_child(scroll)
    room_list = VBoxContainer.new()
    room_list.add_theme_constant_override("separation", 10)
    room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(room_list)
    empty_label = UIKit.label("暂无公开房间，创建一间或等好友邀请。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
    room_list.add_child(empty_label)

    var right := UIKit.vbox(14)
    right.custom_minimum_size = Vector2(500, 0)
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(right)

    var join_panel := UIKit.panel("panel_dark.png")
    join_panel.add_theme_stylebox_override("panel", UIKit.gilded_style())
    right.add_child(join_panel)
    var jv := UIKit.vbox(10)
    join_panel.add_child(jv)
    jv.add_child(UIKit.label("按房号加入", 22, UIKit.GOLD))
    join_edit = LineEdit.new()
    join_edit.max_length = 6
    join_edit.placeholder_text = "6 位房号"
    join_edit.custom_minimum_size = Vector2(0, 56)
    jv.add_child(join_edit)
    var join_btn := UIKit.button("加入房间", 0, 56, 22)
    join_btn.pressed.connect(_join_by_code)
    jv.add_child(join_btn)
    join_edit.text_submitted.connect(func(_t): _join_by_code())

    var create_panel := UIKit.panel()
    create_panel.add_theme_stylebox_override("panel", UIKit.gilded_style())
    create_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(create_panel)
    var cv := UIKit.vbox(12)
    create_panel.add_child(cv)
    cv.add_child(UIKit.label("创建房间", 24, UIKit.GOLD))
    cv.add_child(UIKit.label("默认：公开 · 上限 6 人 · 不补 AI · 出牌限时 10 秒。\n创建后仍可在房间里调整。", 17, UIKit.DIM))
    var rows := UIKit.vbox(4)
    rows.add_child(UIKit.label("• 人数上限：2~8（开 AI 补全时可设 1）", 16, UIKit.DIM))
    rows.add_child(UIKit.label("• 全员准备后，房主才能开始", 16, UIKit.DIM))
    rows.add_child(UIKit.label("• 房主可踢人、改设置、邀请好友", 16, UIKit.DIM))
    rows.add_child(UIKit.label("• 出牌限时默认 10 秒", 16, UIKit.DIM))
    cv.add_child(rows)
    var sp2 := Control.new()
    sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cv.add_child(sp2)
    var create_btn := UIKit.button("创建房间", 0, 70, 26)
    create_btn.pressed.connect(_open_create)
    cv.add_child(create_btn)


func on_online(count: int) -> void:
    if online_label != null:
        online_label.text = "在线 %d 人" % count


func on_rooms(list: Array) -> void:
    if room_list == null:
        return
    for c in room_list.get_children():
        if c == empty_label:
            continue
        c.queue_free()
    empty_label.visible = list.is_empty()
    for r in list:
        _add_room_row(r)


func _add_room_row(r: Dictionary) -> void:
    var panel := UIKit.panel("panel_dark.png")
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var h := UIKit.hbox(14)
    panel.add_child(h)
    var info := UIKit.vbox(2)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(info)
    info.add_child(UIKit.label("房号 %s · 房主 %s" % [r.get("id", ""), r.get("host_name", "?")], 21, UIKit.WHITE))
    var chips: Array = []
    chips.append("%d/%d 人" % [int(r.get("count", 0)), int(r.get("max_players", 0))])
    chips.append("%d 秒" % int(r.get("turn_time", 10)))
    if bool(r.get("ai_fill", false)):
        chips.append("AI 补全")
    if bool(r.get("friendly_fire", false)):
        chips.append("友伤开")
    if bool(r.get("cheat_mode", false)):
        chips.append("变态模式")
    if bool(r.get("public", true)):
        chips.append("公开")
    info.add_child(UIKit.label(" · ".join(chips), 16, UIKit.DIM))
    var join := UIKit.small_button("加入", 110, 56, 20)
    join.pressed.connect(func(): App.send({"t": "room_join", "room_id": str(r.get("id", ""))}))
    h.add_child(join)
    room_list.add_child(panel)
    UIKit.fade_in(panel, 0.24, 0.04)


func _join_by_code() -> void:
    var code := join_edit.text.strip_edges()
    if code.length() != 6:
        toast("请输入 6 位房号")
        return
    App.send({"t": "room_join", "room_id": code})


func _open_create() -> void:
    if create_layer != null and is_instance_valid(create_layer):
        create_layer.queue_free()
    create_layer = CanvasLayer.new()
    create_layer.layer = 120
    add_child(create_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.01, 0.05, 0.78)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    create_layer.add_child(shade)
    var p := UIKit.panel()
    p.theme = UIKit.make_theme()
    p.custom_minimum_size = Vector2(720, 640)
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.position = Vector2(-360, -320)
    create_layer.add_child(p)
    var v := UIKit.vbox(12)
    p.add_child(v)
    v.add_child(UIKit.title("房间设置", 36))

    public_check = _check("公开房间（出现在大厅列表）", true)
    v.add_child(public_check)
    ai_check = _check("AI 自动补全空位", false)
    v.add_child(ai_check)
    var max_row := UIKit.hbox(12)
    max_row.add_child(UIKit.label("人数上限", 21, UIKit.WHITE))
    max_spin = _spin(6, 2, 8)
    max_row.add_child(max_spin)
    max_row.add_child(UIKit.label("（开启 AI 补全后可设为 1）", 15, UIKit.GREY))
    v.add_child(max_row)
    ai_check.toggled.connect(func(on):
        max_spin.min_value = 1 if on else 2
        if max_spin.value < max_spin.min_value:
            max_spin.value = max_spin.min_value)
    var time_row := UIKit.hbox(12)
    time_row.add_child(UIKit.label("出牌限时", 21, UIKit.WHITE))
    time_spin = _spin(10, 3, 60)
    time_row.add_child(time_spin)
    time_row.add_child(UIKit.label("秒", 18, UIKit.DIM))
    v.add_child(time_row)
    ff_check = _check("允许友伤（可以攻击队友）", false)
    v.add_child(ff_check)
    cheat_check = _check("变态模式（AI 可看到人类出的牌）", false)
    v.add_child(cheat_check)
    v.add_child(UIKit.label("AI 之间不会互相看牌。人数上限默认 6，房主在房间内仍可修改。", 15, UIKit.DIM))
    var bh := UIKit.hbox(16)
    bh.alignment = BoxContainer.ALIGNMENT_CENTER
    var ok := UIKit.button("创建", 240, 60)
    ok.pressed.connect(func():
        App.send({"t": "room_create",
                  "public": public_check.button_pressed,
                  "max_players": int(max_spin.value),
                  "ai_fill": ai_check.button_pressed,
                  "turn_time": int(time_spin.value),
                  "friendly_fire": ff_check.button_pressed,
                  "cheat_mode": cheat_check.button_pressed})
        create_layer.queue_free())
    var cancel := UIKit.button("取消", 200, 60)
    cancel.pressed.connect(func(): create_layer.queue_free())
    bh.add_child(ok)
    bh.add_child(cancel)
    v.add_child(bh)


func _check(text: String, on: bool) -> CheckBox:
    var c := CheckBox.new()
    c.text = text
    c.button_pressed = on
    c.add_theme_font_size_override("font_size", 20)
    return c


func _spin(value: int, mn: int, mx: int) -> SpinBox:
    var s := SpinBox.new()
    s.min_value = mn
    s.max_value = mx
    s.value = value
    s.step = 1
    s.custom_minimum_size = Vector2(130, 50)
    return s


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
