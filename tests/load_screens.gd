extends Node

func _ready() -> void:
    var paths := [
        "res://client/ui/connect.gd", "res://client/ui/name.gd",
        "res://client/ui/menu.gd", "res://client/ui/single.gd",
        "res://client/ui/lobby.gd", "res://client/ui/room.gd",
        "res://client/ui/friends.gd", "res://client/ui/battle.gd",
        "res://client/ui_kit.gd", "res://client/app.gd",
        "res://common/net.gd", "res://common/cards.gd",
        "res://common/battle_engine.gd", "res://server/server_main.gd",
    ]
    var bad := 0
    for p in paths:
        var s = load(p)
        if s == null:
            bad += 1
            print("LOAD FAIL ", p)
        else:
            print("LOAD OK ", p)
    get_tree().quit(1 if bad > 0 else 0)
