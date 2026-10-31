extends Node

## Two-process social/room test. Run server on 7820 first, then:
## run_id=test1
## godot --headless --path . res://tests/social_bot.tscn -- --no-ui --port=7820 --role=a --run=test1
## godot --headless --path . res://tests/social_bot.tscn -- --no-ui --port=7820 --role=b --run=test1
## The `run_id` is only a file key; set the same --run for both.

var inbox: Array = []
var port := 7820
var role := "a"
var run_id := "t1"
var my_hwid := ""
var my_code := ""
var friend_hwid := ""
var room_id := ""
var my_pid := -1


func _ready() -> void:
    for a in OS.get_cmdline_user_args():
        var s := str(a)
        if s.begins_with("--port="):
            port = int(s.substr(7))
        elif s.begins_with("--role="):
            role = s.substr(7)
        elif s.begins_with("--run="):
            run_id = s.substr(6)
    Net.msg_received.connect(func(_from, data): inbox.append(data))
    _run()


func _wait_for(kind: String, ms: int = 6000) -> Dictionary:
    var until := Time.get_ticks_msec() + ms
    while Time.get_ticks_msec() < until:
        for i in inbox.size():
            var d: Dictionary = inbox[i]
            if str(d.get("t", "")) == kind:
                inbox.remove_at(i)
                return d
        await get_tree().create_timer(0.05).timeout
    return {}


func _connect_login(name: String) -> bool:
    var err := Net.connect_to("127.0.0.1", port)
    if err != OK:
        return false
    var until := Time.get_ticks_msec() + 4000
    while not Net.connected and Time.get_ticks_msec() < until:
        await get_tree().create_timer(0.05).timeout
    if not Net.connected:
        return false
    my_hwid = "%s-social-%s" % [role, run_id]
    Net.send_to_server({"t": "hello", "hwid": my_hwid})
    var hello := await _wait_for("hello_ok", 6000)
    if hello.is_empty():
        return false
    Net.send_to_server({"t": "set_name", "name": name})
    var acc := await _wait_for("account", 3000)
    if acc.is_empty():
        return false
    my_code = str(acc.get("account", {}).get("friend_code", ""))
    return true


func _run() -> void:
    var nm := ("Alice" if role == "a" else "Bob") + run_id.substr(0, 5)
    if not await _connect_login(nm.substr(0, 12)):
        print("SOCIAL FAIL login role=", role)
        get_tree().quit(1)
        return
    print("SOCIAL login role=", role, " code=", my_code)
    if role == "a":
        await _role_a()
    else:
        await _role_b()


func _role_a() -> void:
    var code_path := "/tmp/mxd_code_%s.txt" % run_id
    var f := FileAccess.open(code_path, FileAccess.WRITE)
    if f:
        f.store_string(my_code)
        f.close()
    var req := await _wait_for("friend_request", 12000)
    if req.is_empty():
        print("A FAIL no friend_request")
        get_tree().quit(1)
        return
    friend_hwid = str(req.get("from_hwid", ""))
    Net.send_to_server({"t": "friend_respond", "hwid": friend_hwid, "accept": true})
    await get_tree().create_timer(0.6).timeout
    Net.send_to_server({"t": "room_create", "public": true, "max_players": 2,
                        "ai_fill": false, "turn_time": 3, "friendly_fire": false,
                        "cheat_mode": false})
    var room_msg := await _wait_for("room", 5000)
    if room_msg.is_empty():
        print("A FAIL no room")
        get_tree().quit(1)
        return
    room_id = str(room_msg["room"]["id"])
    Net.send_to_server({"t": "friend_invite", "hwid": friend_hwid})
    print("A room=", room_id, " invite sent")
    var joined := await _wait_room_members(2, 12000)
    if joined.is_empty():
        print("A FAIL friend did not join room=", room_id)
        get_tree().quit(1)
        return
    print("A friend joined")
    Net.send_to_server({"t": "room_ready", "ready": true})
    var ready := await _wait_all_ready(2, 10000)
    if ready.is_empty():
        print("A FAIL not all ready")
        get_tree().quit(1)
        return
    Net.send_to_server({"t": "room_start"})
    await _fight("A")


func _role_b() -> void:
    var code_path := "/tmp/mxd_code_%s.txt" % run_id
    var code := ""
    var until := Time.get_ticks_msec() + 12000
    while Time.get_ticks_msec() < until:
        if FileAccess.file_exists(code_path):
            code = FileAccess.get_file_as_string(code_path).strip_edges()
            if code != "":
                break
        await get_tree().create_timer(0.1).timeout
    if code == "":
        print("B FAIL no code file")
        get_tree().quit(1)
        return
    Net.send_to_server({"t": "friend_add", "code": code})
    var friends := await _wait_for("friends", 5000)
    if friends.is_empty():
        print("B FAIL no friends payload")
        get_tree().quit(1)
        return
    var until2 := Time.get_ticks_msec() + 10000
    var got_friend := false
    while Time.get_ticks_msec() < until2:
        for f in friends.get("friends", []):
            if str(f.get("code", "")) == code:
                got_friend = true
                friend_hwid = str(f.get("hwid", ""))
        if got_friend:
            break
        friends = await _wait_for("friends", 3000)
        if friends.is_empty():
            break
    if not got_friend:
        print("B FAIL friend not accepted")
        get_tree().quit(1)
        return
    print("B friend accepted hwid=", friend_hwid)
    var inv := await _wait_for("invite", 12000)
    if inv.is_empty():
        print("B FAIL no invite")
        get_tree().quit(1)
        return
    Net.send_to_server({"t": "invite_respond", "room_id": str(inv["room_id"]), "accept": true})
    var room_msg := await _wait_for("room", 5000)
    if room_msg.is_empty():
        print("B FAIL no room after invite")
        get_tree().quit(1)
        return
    room_id = str(room_msg["room"]["id"])
    print("B joined room=", room_id)
    Net.send_to_server({"t": "room_ready", "ready": true})
    await _fight("B")


func _wait_room_members(n: int, ms: int) -> Dictionary:
    var until := Time.get_ticks_msec() + ms
    while Time.get_ticks_msec() < until:
        var r := await _wait_for("room", 3000)
        if r.is_empty():
            continue
        var room: Dictionary = r["room"]
        if room.get("members", []).size() >= n:
            return r
    return {}


func _wait_all_ready(members: int, ms: int) -> Dictionary:
    var until := Time.get_ticks_msec() + ms
    while Time.get_ticks_msec() < until:
        var r := await _wait_for("room", 3000)
        if r.is_empty():
            continue
        var room: Dictionary = r["room"]
        var all_ready := true
        for m in room.get("members", []):
            if not bool(m.get("ready", false)):
                all_ready = false
        if all_ready and room.get("members", []).size() >= members:
            return r
    return {}


func _fight(tag: String) -> void:
    var start := await _wait_for("battle_start", 8000)
    if start.is_empty():
        print(tag, " FAIL no battle_start")
        get_tree().quit(1)
        return
    my_pid = int(start.get("you_pid", 0))
    print(tag, " battle_start pid=", my_pid,
          " players=", start.get("state", {}).get("players", []).size())
    var rounds := 0
    while rounds < 25:
        var turn := await _wait_for("battle_turn", 6000)
        if turn.is_empty():
            print(tag, " FAIL no turn")
            get_tree().quit(1)
            return
        rounds += 1
        var legal: Array = turn.get("legal", [])
        if legal.is_empty():
            await get_tree().create_timer(0.2).timeout
            continue
        var card := str(legal[0])
        var targets_map: Dictionary = turn.get("targets", {})
        var tlist: Array = targets_map.get(card, [])
        var target := -1 if tlist.is_empty() else int(tlist[0])
        Net.send_to_server({"t": "battle_choose", "card": card,
                            "target": target, "targets": tlist})
        await _wait_for("battle_ack", 2500)
        var reveal := await _wait_for("battle_reveal", 6000)
        if reveal.is_empty():
            print(tag, " FAIL no reveal")
            get_tree().quit(1)
            return
        var hps: Array = []
        for p in reveal.get("players", []):
            hps.append(int(p.get("hp_t", 0)))
        print(tag, " round=", reveal.get("round"), " hp=", hps)
        if bool(reveal.get("finished", false)):
            print(tag, " FINISHED winner=", reveal.get("winner_team"))
            break
        await get_tree().create_timer(0.2).timeout
    print("SOCIAL PASS role=", tag, " rounds=", rounds)
    await get_tree().create_timer(0.3).timeout
    Net.disconnect_now()
    get_tree().quit(0)
