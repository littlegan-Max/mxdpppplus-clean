extends Control

var room: Dictionary = {}
var member_grid: GridContainer
var title_label: Label
var subtitle_label: Label
var ready_btn: Button
var start_btn: Button
var invite_btn: Button
var invite_all_btn: Button
var _invite_cd_left := 0.0
var public_check: CheckBox
var ai_check: CheckBox
var ff_check: CheckBox
var cheat_check: CheckBox
var max_spin: SpinBox
var time_spin: SpinBox
var status_label: Label
var _syncing := false
var _invite_layer: CanvasLayer = null


func _ready() -> void:
    UIKit.bg(self, "bg_room.png")
    UIKit.dim(self, 0.45)
    _build()
    room = App.room
    _render()
    set_process(false)


func _build() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 40)
    margin.add_theme_constant_override("margin_right", 40)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_bottom", 24)
    add_child(margin)
    var root := UIKit.vbox(12)
    margin.add_child(root)

    var head := UIKit.hbox(14)
    var back := UIKit.small_button("← 大厅", 130, 52, 20)
    back.pressed.connect(_leave)
    head.add_child(back)
    title_label = UIKit.label("房间", 34, UIKit.GOLD)
    head.add_child(title_label)
    subtitle_label = UIKit.label("", 18, UIKit.DIM)
    head.add_child(subtitle_label)
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    status_label = UIKit.label("人数 —", 18, UIKit.CYAN)
    head.add_child(status_label)
    root.add_child(head)

    var content := UIKit.hbox(16)
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(content)

    var left := UIKit.panel()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(left)
    var lv := UIKit.vbox(8)
    left.add_child(lv)
    lv.add_child(UIKit.label("参战席（队伍按人数连续分半）", 21, UIKit.WHITE))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    lv.add_child(scroll)
    member_grid = GridContainer.new()
    member_grid.columns = 4
    member_grid.add_theme_constant_override("h_separation", 10)
    member_grid.add_theme_constant_override("v_separation", 10)
    member_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(member_grid)
    var note := UIKit.label("8 人→4v4，7 人→3v4。人数上限可在右侧调整；开启 AI 补全后开局自动补位。", 15, UIKit.DIM)
    lv.add_child(note)

    var right := UIKit.vbox(10)
    right.custom_minimum_size = Vector2(540, 0)
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(right)

    var settings := UIKit.panel("panel_dark.png")
    settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(settings)
    var sv := UIKit.vbox(8)
    settings.add_child(sv)
    sv.add_child(UIKit.label("房间设置（仅房主可改）", 22, UIKit.GOLD))
    public_check = _check("公开房间")
    ai_check = _check("AI 自动补全空位")
    ff_check = _check("允许友伤")
    cheat_check = _check("变态模式（AI 看人类牌）")
    sv.add_child(public_check)
    sv.add_child(ai_check)
    var max_row := UIKit.hbox(8)
    max_row.add_child(UIKit.label("人数上限", 19, UIKit.WHITE))
    max_spin = _spin(6, 2, 8)
    max_row.add_child(max_spin)
    max_row.add_child(UIKit.label("人", 18, UIKit.DIM))
    sv.add_child(max_row)
    var time_row := UIKit.hbox(8)
    time_row.add_child(UIKit.label("出牌限时", 19, UIKit.WHITE))
    time_spin = _spin(10, 3, 60)
    time_row.add_child(time_spin)
    time_row.add_child(UIKit.label("秒", 18, UIKit.DIM))
    sv.add_child(time_row)
    sv.add_child(ff_check)
    sv.add_child(cheat_check)
    var tip := UIKit.label("默认：公开 · 上限 6 · 不补 AI · 10 秒。\n私密房间不在大厅显示，可用房号/邀请进入。\n全员准备后房主才能开始。", 15, UIKit.DIM)
    sv.add_child(tip)

    var badge := UIKit.panel("panel_dark.png")
    right.add_child(badge)
    var bv := UIKit.vbox(4)
    badge.add_child(bv)
    bv.add_child(UIKit.label("邀请好友", 20, UIKit.GOLD))
    bv.add_child(UIKit.label("邀请成功后你成为房主；好友需在线并已互为好友。", 15, UIKit.DIM))
    invite_btn = UIKit.button("从好友列表邀请", 0, 54, 20)
    invite_btn.pressed.connect(_open_invite)
    bv.add_child(invite_btn)
    invite_all_btn = UIKit.button("一键邀请在线所有人（冷却 5 秒）", 0, 54, 20)
    invite_all_btn.pressed.connect(_invite_all)
    bv.add_child(invite_all_btn)

    var actions := UIKit.hbox(14)
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    ready_btn = UIKit.button("准 备", 260, 70, 26)
    ready_btn.pressed.connect(_toggle_ready)
    start_btn = UIKit.button("开始游戏", 260, 70, 26)
    start_btn.pressed.connect(func(): App.send({"t": "room_start"}))
    var leave := UIKit.button("离开房间", 220, 70, 22)
    leave.pressed.connect(_leave)
    actions.add_child(ready_btn)
    actions.add_child(start_btn)
    actions.add_child(leave)
    root.add_child(actions)

    public_check.toggled.connect(func(_v): _send_settings())
    ai_check.toggled.connect(func(on):
        max_spin.min_value = 1 if on else 2
        if int(max_spin.value) < int(max_spin.min_value):
            max_spin.value = max_spin.min_value
        _send_settings())
    ff_check.toggled.connect(func(_v): _send_settings())
    cheat_check.toggled.connect(func(_v): _send_settings())
    max_spin.value_changed.connect(func(_v): _send_settings())
    time_spin.value_changed.connect(func(_v): _send_settings())


func _check(text: String) -> CheckBox:
    var c := CheckBox.new()
    c.text = text
    c.add_theme_font_size_override("font_size", 19)
    return c


func _spin(value: int, mn: int, mx: int) -> SpinBox:
    var s := SpinBox.new()
    s.min_value = mn
    s.max_value = mx
    s.step = 1
    s.value = value
    s.custom_minimum_size = Vector2(130, 48)
    return s


func on_room(r: Dictionary) -> void:
    room = r
    _render()


func _is_host() -> bool:
    return int(room.get("host_peer", 0)) == App.my_peer_id()


func _my_member() -> Dictionary:
    for m in room.get("members", []):
        if int(m.get("peer", 0)) == App.my_peer_id():
            return m
    return {}


func _render() -> void:
    if room.is_empty() or member_grid == null:
        return
    var host := _is_host()
    title_label.text = "房间 %s" % str(room.get("id", ""))
    subtitle_label.text = "%s · 房主 %s · %s" % [
        "公开" if bool(room.get("public", true)) else "私密",
        room.get("host_name", "?"),
        "对局中" if str(room.get("state", "lobby")) == "battle" else "等待准备",
    ]
    var humans: Array = room.get("members", [])
    var mx := int(room.get("max_players", 6))
    status_label.text = "人类 %d / 上限 %d%s" % [
        humans.size(), mx, " · AI 补全" if bool(room.get("ai_fill", false)) else ""
    ]
    _rebuild_members(humans, mx)
    _syncing = true
    public_check.button_pressed = bool(room.get("public", true))
    ai_check.button_pressed = bool(room.get("ai_fill", false))
    ff_check.button_pressed = bool(room.get("friendly_fire", false))
    cheat_check.button_pressed = bool(room.get("cheat_mode", false))
    max_spin.min_value = 1 if bool(room.get("ai_fill", false)) else 2
    max_spin.value = clampi(mx, int(max_spin.min_value), 8)
    time_spin.value = clampi(int(room.get("turn_time", 10)), 3, 60)
    public_check.disabled = not host
    ai_check.disabled = not host
    ff_check.disabled = not host
    cheat_check.disabled = not host
    max_spin.editable = host
    time_spin.editable = host
    _syncing = false
    var me := _my_member()
    ready_btn.text = "取消准备" if bool(me.get("ready", false)) else "准 备"
    var all_ready := true
    for m in humans:
        if not bool(m.get("ready", false)):
            all_ready = false
    var total_possible := maxi(2, humans.size()) if bool(room.get("ai_fill", false)) else humans.size()
    start_btn.visible = host
    start_btn.disabled = humans.is_empty() or not all_ready or total_possible < 2
    start_btn.tooltip_text = "" if not start_btn.disabled else "需要全员准备且参战者≥2"
    invite_btn.disabled = humans.size() >= mx or str(room.get("state", "lobby")) != "lobby"
    invite_all_btn.disabled = invite_btn.disabled or _invite_cd_left > 0.0


func _rebuild_members(humans: Array, mx: int) -> void:
    for c in member_grid.get_children():
        c.queue_free()
    for i in mx:
        if i < humans.size():
            member_grid.add_child(_member_slot(humans[i], i))
        else:
            member_grid.add_child(_empty_slot(bool(room.get("ai_fill", false))))


func _member_slot(m: Dictionary, seat: int) -> PanelContainer:
    var p := UIKit.panel("panel_cyan.png" if int(m.get("team", seat % 2)) == 0 else "panel_red.png")
    p.custom_minimum_size = Vector2(0, 150)
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var v := UIKit.vbox(2)
    p.add_child(v)
    var h := UIKit.hbox(6)
    h.add_child(UIKit.avatar(int(m.get("avatar", 0)), 58))
    var info := UIKit.vbox(0)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(info)
    var head := UIKit.hbox(4)
    head.add_child(UIKit.label(str(m.get("name", "未命名")), 19, UIKit.WHITE))
    if bool(m.get("is_host", false)):
        head.add_child(UIKit.label("♛", 18, UIKit.GOLD))
    if int(m.get("peer", 0)) == App.my_peer_id():
        head.add_child(UIKit.label("你", 15, UIKit.GOLD))
    info.add_child(head)
    var ready := bool(m.get("ready", false))
    info.add_child(UIKit.label("已准备" if ready else "未准备", 16, UIKit.CYAN if ready else UIKit.GREY))
    v.add_child(h)
    if _is_host() and int(m.get("peer", 0)) != App.my_peer_id():
        var kick := UIKit.small_button("踢出", 90, 40, 16)
        kick.pressed.connect(func(): App.send({"t": "room_kick", "peer": int(m.get("peer", 0))}))
        v.add_child(kick)
    return p


func _empty_slot(ai_fill: bool) -> PanelContainer:
    var p := UIKit.panel("panel_dark.png")
    p.custom_minimum_size = Vector2(0, 150)
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var v := UIKit.vbox(6)
    p.add_child(v)
    v.add_child(UIKit.label("AI 自动补位" if ai_fill else "空 位", 19, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER))
    v.add_child(UIKit.label("开局时填充" if ai_fill else "等待玩家加入", 15, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    return p


func _toggle_ready() -> void:
    var me := _my_member()
    if me.is_empty():
        return
    App.send({"t": "room_ready", "ready": not bool(me.get("ready", false))})


func _send_settings() -> void:
    if _syncing or not _is_host() or room.is_empty():
        return
    App.send({"t": "room_settings",
              "public": public_check.button_pressed,
              "max_players": int(max_spin.value),
              "ai_fill": ai_check.button_pressed,
              "turn_time": int(time_spin.value),
              "friendly_fire": ff_check.button_pressed,
              "cheat_mode": cheat_check.button_pressed})


func _leave() -> void:
    App.send({"t": "room_leave"})
    App.goto("lobby")


func _invite_all() -> void:
    if _invite_cd_left > 0.0:
        return
    App.send({"t": "invite_all"})
    _invite_cd_left = 5.0
    invite_all_btn.disabled = true
    invite_all_btn.text = "冷却中… 5.0 秒"
    set_process(true)


func _process(delta: float) -> void:
    if _invite_cd_left <= 0.0:
        set_process(false)
        return
    _invite_cd_left = maxf(_invite_cd_left - delta, 0.0)
    if invite_all_btn == null:
        set_process(false)
        return
    if _invite_cd_left > 0.0:
        invite_all_btn.text = "冷却中… %.1f 秒" % _invite_cd_left
    else:
        invite_all_btn.text = "一键邀请在线所有人（冷却 5 秒）"
        set_process(false)
        _render()


func _open_invite() -> void:
    if _invite_layer != null and is_instance_valid(_invite_layer):
        _invite_layer.queue_free()
    _invite_layer = CanvasLayer.new()
    _invite_layer.layer = 120
    add_child(_invite_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.01, 0.05, 0.78)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _invite_layer.add_child(shade)
    var p := UIKit.panel()
    p.theme = UIKit.make_theme()
    p.custom_minimum_size = Vector2(700, 560)
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.position = Vector2(-350, -280)
    _invite_layer.add_child(p)
    var v := UIKit.vbox(10)
    p.add_child(v)
    v.add_child(UIKit.title("邀请好友", 34))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    v.add_child(scroll)
    var list := UIKit.vbox(8)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    var any_online := false
    for f in App.friends:
        if not bool(f.get("online", false)):
            continue
        any_online = true
        var row := UIKit.panel("panel_dark.png")
        var h := UIKit.hbox(8)
        row.add_child(h)
        h.add_child(UIKit.label("%s · 好友码 %s" % [f.get("name", "?"), f.get("code", "")], 18, UIKit.WHITE))
        var sp := Control.new()
        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(sp)
        var btn := UIKit.small_button("邀请", 110, 46, 18)
        var fhwid := str(f.get("hwid", ""))
        btn.pressed.connect(func():
            App.send({"t": "friend_invite", "hwid": fhwid})
            toast("已发送邀请"))
        h.add_child(btn)
        list.add_child(row)
    if not any_online:
        list.add_child(UIKit.label("没有在线好友。好友必须在线才能收到邀请。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    var close := UIKit.button("关闭", 200, 56, 20)
    close.pressed.connect(func(): _invite_layer.queue_free())
    v.add_child(close)


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
