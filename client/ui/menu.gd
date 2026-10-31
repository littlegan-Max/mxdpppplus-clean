extends Control

var name_label: Label
var code_label: Label
var rank_label: Label
var rate_label: Label
var friend_badge: Label
var online_label: Label
var avatar_rect: TextureRect


func _ready() -> void:
    UIKit.bg(self, "bg_lobby.png")
    UIKit.dim(self, 0.35)
    _build()
    _refresh()
    if bool(App.update_info.get("newer", false)):
        call_deferred("on_update_available", App.update_info)


func _build() -> void:
    var top := HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_CENTER_TOP)
    top.position = Vector2(-420, 34)
    top.custom_minimum_size = Vector2(840, 150)
    add_child(top)
    var logo := TextureRect.new()
    logo.texture = UIKit.art("logo.png")
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.custom_minimum_size = Vector2(820, 150)
    top.add_child(logo)

    var root := MarginContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 150)
    root.add_theme_constant_override("margin_right", 150)
    root.add_theme_constant_override("margin_top", 210)
    root.add_theme_constant_override("margin_bottom", 70)
    add_child(root)
    var h := UIKit.hbox(44)
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    root.add_child(h)

    var left := UIKit.panel()
    left.custom_minimum_size = Vector2(680, 600)
    left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    h.add_child(left)
    var lv := UIKit.vbox(16)
    left.add_child(lv)
    lv.add_child(UIKit.label("玩家档案", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
    avatar_rect = UIKit.avatar(int(App.account.get("avatar", 0)), 170)
    avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    lv.add_child(avatar_rect)
    name_label = UIKit.label("未命名", 40, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    lv.add_child(name_label)
    code_label = UIKit.label("好友码 —", 22, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
    lv.add_child(code_label)
    rank_label = UIKit.label("段位 —", 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    lv.add_child(rank_label)
    rate_label = UIKit.label("胜率 —", 18, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER)
    lv.add_child(rate_label)
    lv.add_child(UIKit.label("硬件码账号：换设备会生成新账号\n好友与房间不跨设备同步", 16, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER))
    var sp := Control.new()
    sp.custom_minimum_size = Vector2(0, 30)
    lv.add_child(sp)
    var stat := UIKit.label("● 已连接服务器", 18, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
    if not Net.connected:
        stat.text = "● 离线（仅单机）"
        stat.add_theme_color_override("font_color", UIKit.GREY)
    lv.add_child(stat)
    online_label = UIKit.label("在线 0 人", 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    lv.add_child(online_label)
    var hint := UIKit.label("默认房间：公开 · 6 人 · 不补 AI · 10 秒", 16, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
    lv.add_child(hint)

    var right := UIKit.vbox(16)
    right.custom_minimum_size = Vector2(460, 600)
    right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    h.add_child(right)

    var single := UIKit.button("单人模式", 460, 88, 28)
    single.pressed.connect(func(): App.goto("single"))
    right.add_child(single)
    var multi := UIKit.button("多人联机", 460, 88, 28)
    multi.pressed.connect(func():
        if not Net.connected:
            toast("请先连接服务器")
            return
        App.goto("lobby"))
    right.add_child(multi)
    var friends := UIKit.button("好 友", 460, 80, 26)
    friends.pressed.connect(func(): App.goto("friends"))
    right.add_child(friends)
    friend_badge = UIKit.label("", 18, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
    right.add_child(friend_badge)
    var rename := UIKit.button("改 名", 460, 72, 24)
    rename.pressed.connect(func(): App.goto("name"))
    right.add_child(rename)
    var update := UIKit.button("检查更新", 460, 72, 24)
    update.pressed.connect(func(): App.check_updates(true))
    right.add_child(update)
    var quit := UIKit.button("退 出", 460, 72, 24)
    quit.pressed.connect(func():
        Net.disconnect_now()
        App.goto("connect"))
    right.add_child(quit)
    var tip := UIKit.label("像素卡牌 · 2~8 人双队 · 权威服务端", 16, UIKit.GREY, HORIZONTAL_ALIGNMENT_CENTER)
    right.add_child(tip)
    var learned := AiMemory.total()
    if learned > 0:
        right.add_child(UIKit.label("AI 已从真人出牌中学习 %d 次" % learned, 15, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _refresh() -> void:
    if name_label == null:
        return
    var n := str(App.account.get("name", ""))
    name_label.text = n if n != "" else "未命名"
    var code := str(App.account.get("friend_code", ""))
    code_label.text = "好友码  %s" % (code if code != "" else "—")
    var rank: Dictionary = App.account.get("rank", {})
    rank_label.text = Rank.label(rank)
    rate_label.text = Rank.win_rate_text(rank)
    avatar_rect.texture = UIKit.art("avatar_%d.png" % int(App.account.get("avatar", 0)))
    online_label.text = "在线 %d 人" % App.online_count
    var reqs := App.friend_requests.size()
    friend_badge.visible = reqs > 0
    if reqs > 0:
        friend_badge.text = "有 %d 条好友请求待处理" % reqs


func on_account(_account: Dictionary) -> void:
    _refresh()


func on_rank(_rank: Dictionary, _data: Dictionary) -> void:
    _refresh()


func on_update_available(info: Dictionary) -> void:
    if not bool(info.get("newer", false)):
        return
    var note := str(info.get("notes", ""))
    var body := "最新版本：%s\n当前版本：%s" % [str(info.get("latest", "")), App.app_version()]
    if note != "":
        body += "\n\n" + note
    UIKit.confirm(self, "发现新版本", body,
        func():
            var url := str(info.get("url", ""))
            if url != "":
                OS.shell_open(url),
        func(): pass)


func on_friends(_list: Array) -> void:
    _refresh()


func on_online(count: int) -> void:
    if online_label != null:
        online_label.text = "在线 %d 人" % count


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
