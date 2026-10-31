extends Control

var code_label: Label
var add_edit: LineEdit
var friends_list: VBoxContainer
var requests_list: VBoxContainer
var request_title: Label


func _ready() -> void:
    UIKit.bg(self, "bg_lobby.png")
    UIKit.dim(self, 0.4)
    _build()
    _refresh()


func _build() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 60)
    margin.add_theme_constant_override("margin_right", 60)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 28)
    add_child(margin)
    var root := UIKit.vbox(14)
    margin.add_child(root)

    var head := UIKit.hbox(14)
    var back := UIKit.small_button("← 返回", 140, 52, 20)
    back.pressed.connect(func(): App.goto("menu"))
    head.add_child(back)
    head.add_child(UIKit.label("好 友", 34, UIKit.GOLD))
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(sp)
    var refresh := UIKit.small_button("刷新", 120, 52, 20)
    refresh.pressed.connect(func(): App.send({"t": "friends_list"}))
    head.add_child(refresh)
    root.add_child(head)

    var content := UIKit.hbox(18)
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(content)

    var left := UIKit.vbox(12)
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(left)

    var card := UIKit.panel()
    left.add_child(card)
    var cv := UIKit.vbox(8)
    card.add_child(cv)
    cv.add_child(UIKit.label("我的好友码", 20, UIKit.GOLD))
    code_label = UIKit.label("—", 40, UIKit.CYAN)
    cv.add_child(code_label)
    cv.add_child(UIKit.label("把好友码发给对方；对方添加时你需要同意。好友邀请会直接进入对方房间。", 15, UIKit.DIM))
    var add_row := UIKit.hbox(10)
    add_edit = LineEdit.new()
    add_edit.max_length = 6
    add_edit.placeholder_text = "输入对方 6 位好友码"
    add_edit.custom_minimum_size = Vector2(0, 54)
    add_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_row.add_child(add_edit)
    var add_btn := UIKit.button("添加", 140, 54, 20)
    add_btn.pressed.connect(_add_friend)
    add_row.add_child(add_btn)
    cv.add_child(add_row)
    add_edit.text_submitted.connect(func(_t): _add_friend())

    var list_panel := UIKit.panel("panel_dark.png")
    list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(list_panel)
    var lv := UIKit.vbox(8)
    list_panel.add_child(lv)
    lv.add_child(UIKit.label("好友列表", 22, UIKit.WHITE))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    lv.add_child(scroll)
    friends_list = VBoxContainer.new()
    friends_list.add_theme_constant_override("separation", 8)
    friends_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(friends_list)

    var right := UIKit.vbox(12)
    right.custom_minimum_size = Vector2(560, 0)
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(right)
    var req_panel := UIKit.panel()
    req_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(req_panel)
    var rv := UIKit.vbox(8)
    req_panel.add_child(rv)
    request_title = UIKit.label("好友请求", 22, UIKit.WHITE)
    rv.add_child(request_title)
    var rscroll := ScrollContainer.new()
    rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rv.add_child(rscroll)
    requests_list = VBoxContainer.new()
    requests_list.add_theme_constant_override("separation", 8)
    requests_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rscroll.add_child(requests_list)
    rv.add_child(UIKit.label("只有对方同意后，好友关系才成立。删除好友暂未开放。", 15, UIKit.DIM))


func _refresh() -> void:
    if code_label == null:
        return
    code_label.text = str(App.account.get("friend_code", "—"))
    _rebuild_friends()
    _rebuild_requests()


func _rebuild_friends() -> void:
    for c in friends_list.get_children():
        c.queue_free()
    if App.friends.is_empty():
        friends_list.add_child(UIKit.label("还没有好友。用上面的好友码添加。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
        return
    for f in App.friends:
        var row := UIKit.panel("panel_dark.png")
        var h := UIKit.hbox(10)
        row.add_child(h)
        var online := bool(f.get("online", false))
        var dot := UIKit.label("●", 24, UIKit.CYAN if online else UIKit.GREY)
        h.add_child(dot)
        var info := UIKit.vbox(0)
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(info)
        info.add_child(UIKit.label(str(f.get("name", "未命名")), 20, UIKit.WHITE))
        var sub := "在线" if online else "离线"
        var rid := str(f.get("room_id", ""))
        if rid != "":
            sub += " · 房间 %s" % rid
        info.add_child(UIKit.label("好友码 %s · %s" % [f.get("code", "—"), sub], 15, UIKit.GREY))
        var btn := UIKit.small_button("邀请", 110, 48, 18)
        btn.disabled = not online
        var fhwid := str(f.get("hwid", ""))
        btn.pressed.connect(func():
            App.send({"t": "friend_invite", "hwid": fhwid})
            toast("已发送邀请"))
        h.add_child(btn)
        friends_list.add_child(row)


func _rebuild_requests() -> void:
    for c in requests_list.get_children():
        c.queue_free()
    request_title.text = "好友请求（%d）" % App.friend_requests.size()
    if App.friend_requests.is_empty():
        requests_list.add_child(UIKit.label("暂无待处理请求。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
        return
    for r in App.friend_requests:
        var row := UIKit.panel("panel_red.png")
        var v := UIKit.vbox(6)
        row.add_child(v)
        v.add_child(UIKit.label("%s · 好友码 %s" % [r.get("name", "?"), r.get("code", "—")], 18, UIKit.WHITE))
        var h := UIKit.hbox(8)
        var hwid := str(r.get("hwid", ""))
        var accept := UIKit.small_button("接受", 120, 44, 18)
        accept.pressed.connect(func(): App.send({"t": "friend_respond", "hwid": hwid, "accept": true}))
        var decline := UIKit.small_button("拒绝", 120, 44, 18)
        decline.pressed.connect(func(): App.send({"t": "friend_respond", "hwid": hwid, "accept": false}))
        h.add_child(accept)
        h.add_child(decline)
        v.add_child(h)
        requests_list.add_child(row)


func _add_friend() -> void:
    var code := add_edit.text.strip_edges()
    if code.length() != 6:
        toast("好友码应为 6 位数字")
        return
    App.send({"t": "friend_add", "code": code})
    add_edit.text = ""


func on_friends(_list: Array) -> void:
    _refresh()


func on_account(_account: Dictionary) -> void:
    _refresh()


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
