extends Node

## End-to-end bot run as a normal scene so autoloads (Net/App) exist.
## godot --headless --path . res://tests/bot_scene.tscn -- --no-ui --port=7802

var inbox: Array = []
var host := "127.0.0.1"
var port := 7801
var max_players := 2
var private_room := false


func _ready() -> void:
    for a in OS.get_cmdline_user_args():
        if str(a).begins_with("--host="):
            host = str(a).substr(7)
        elif str(a).begins_with("--port="):
            port = int(str(a).substr(7))
        elif str(a).begins_with("--max="):
            max_players = int(str(a).substr(6))
        elif str(a) == "--private":
            private_room = true
    Net.msg_received.connect(func(_from, data): inbox.append(data))
    _run()


func _wait_for(kind: String, ms: int = 5000) -> Dictionary:
    var until := Time.get_ticks_msec() + ms
    while Time.get_ticks_msec() < until:
        for i in inbox.size():
            var d: Dictionary = inbox[i]
            if str(d.get("t", "")) == kind:
                inbox.remove_at(i)
                return d
        await get_tree().create_timer(0.05).timeout
    return {}


func _run() -> void:
    var err := Net.connect_to(host, port)
    if err != OK:
        print("BOT FAIL connect err=", err)
        get_tree().quit(1)
        return
    var until := Time.get_ticks_msec() + 4000
    while not Net.connected and Time.get_ticks_msec() < until:
        await get_tree().create_timer(0.05).timeout
    if not Net.connected:
        print("BOT FAIL not connected")
        get_tree().quit(1)
        return
    await get_tree().create_timer(0.1).timeout
    var hwid := "bot-hwid-0123456789abcdef-" + str(OS.get_process_id())
    Net.send_to_server({"t": "hello", "hwid": hwid})
    var hello := await _wait_for("hello_ok", 6000)
    if hello.is_empty():
        print("BOT FAIL no hello_ok inbox=", inbox)
        get_tree().quit(1)
        return
    print("BOT hello account=", hello.get("account", {}))
    Net.send_to_server({"t": "set_name", "name": "机器人" + str(Time.get_ticks_msec() % 1000)})
    var acc := await _wait_for("account", 3000)
    print("BOT name ack=", acc.get("account", {}).get("name", ""))
    Net.send_to_server({"t": "room_create", "public": not private_room, "max_players": max_players,
                        "ai_fill": true, "turn_time": 3, "friendly_fire": false,
                        "cheat_mode": true})
    var room_msg := await _wait_for("room", 5000)
    if room_msg.is_empty():
        print("BOT FAIL no room inbox=", inbox)
        get_tree().quit(1)
        return
    var room: Dictionary = room_msg["room"]
    print("BOT room=", room.get("id"), " members=", room.get("members", []).size())
    Net.send_to_server({"t": "room_ready", "ready": true})
    await get_tree().create_timer(0.2).timeout
    Net.send_to_server({"t": "room_start"})
    var start := await _wait_for("battle_start", 6000)
    if start.is_empty():
        print("BOT FAIL no battle_start inbox=", inbox)
        get_tree().quit(1)
        return
    print("BOT battle_start you_pid=", start.get("you_pid"),
          " players=", start.get("state", {}).get("players", []).size())
    var rounds := 0
    var finished := false
    while rounds < 20 and not finished:
        var turn := await _wait_for("battle_turn", 8000)
        if turn.is_empty():
            print("BOT FAIL no turn")
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
        var ack := await _wait_for("battle_ack", 3000)
        if ack.is_empty():
            print("BOT WARN no ack ", card)
        var reveal := await _wait_for("battle_reveal", 8000)
        if reveal.is_empty():
            print("BOT FAIL no reveal round=", turn.get("round"))
            get_tree().quit(1)
            return
        var hps: Array = []
        for p in reveal.get("players", []):
            hps.append(int(p.get("hp_t", 0)))
        print("BOT round ", reveal.get("round"), " hp=", hps,
              " choices=", reveal.get("choices", []).size())
        if bool(reveal.get("finished", false)):
            finished = true
            print("BOT finished winner=", reveal.get("winner_team"))
            break
        await get_tree().create_timer(0.3).timeout
    print("BOT PASS rounds=", rounds)
    await get_tree().create_timer(0.5).timeout
    Net.disconnect_now()
    get_tree().quit(0)
