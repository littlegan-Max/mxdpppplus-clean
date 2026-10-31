extends RefCounted

## Persistent accounts keyed by hashed hardware id. No passwords: the device id is
## the credential, as requested. Server stores only the hash, never the raw id.

var path := "user://mxdpppplus_accounts.json"
var accounts: Dictionary = {}
var codes: Dictionary = {}


func _init() -> void:
    var custom := OS.get_environment("MXD_DATA_PATH")
    if custom != "":
        path = custom
    load_data()


func load_data() -> void:
    if not FileAccess.file_exists(path):
        return
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return
    var d = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(d) != TYPE_DICTIONARY:
        return
    accounts = d.get("accounts", {})
    codes = d.get("codes", {})
    if typeof(accounts) != TYPE_DICTIONARY:
        accounts = {}
    if typeof(codes) != TYPE_DICTIONARY:
        codes = {}


func save() -> void:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        push_error("无法写入账号文件: " + path)
        return
    f.store_string(JSON.stringify({"accounts": accounts, "codes": codes}, "\t"))
    f.close()


func _avatar_for(hwid: String) -> int:
    return int(hwid.hash() % 8)


func get_or_create(hwid: String) -> Dictionary:
    if accounts.has(hwid):
        var a: Dictionary = accounts[hwid]
        a["avatar"] = _avatar_for(hwid)
        return a
    var code := _new_code()
    var acc := {
        "hwid": hwid,
        "name": "",
        "friend_code": code,
        "friends": [],
        "requests_in": [],
        "requests_out": [],
        "avatar": _avatar_for(hwid),
    }
    accounts[hwid] = acc
    codes[code] = hwid
    save()
    return acc


func _new_code() -> String:
    for i in 20:
        var c := str(randi_range(100000, 999999))
        if not codes.has(c):
            return c
    return str(Time.get_ticks_usec()).substr(0, 6)


func by_code(code: String) -> Dictionary:
    var hwid := str(codes.get(code, ""))
    if hwid == "":
        return {}
    return accounts.get(hwid, {})


func set_name(hwid: String, new_name: String) -> Dictionary:
    var n := new_name.strip_edges()
    if n.length() < 2 or n.length() > 12:
        return {"ok": false, "reason": "用户名需为 2~12 个字符"}
    for k in accounts.keys():
        if str(k) != hwid and str(accounts[k].get("name", "")) == n:
            return {"ok": false, "reason": "用户名已被占用"}
    var acc: Dictionary = accounts.get(hwid, {})
    if acc.is_empty():
        return {"ok": false, "reason": "账号不存在"}
    acc["name"] = n
    save()
    return {"ok": true, "account": acc}


func add_friend(a_hwid: String, b_hwid: String) -> void:
    var a: Dictionary = accounts.get(a_hwid, {})
    var b: Dictionary = accounts.get(b_hwid, {})
    if a.is_empty() or b.is_empty():
        return
    if not a["friends"].has(b_hwid):
        a["friends"].append(b_hwid)
    if not b["friends"].has(a_hwid):
        b["friends"].append(a_hwid)
    a["requests_in"] = _remove(a["requests_in"], b_hwid)
    a["requests_out"] = _remove(a["requests_out"], b_hwid)
    b["requests_in"] = _remove(b["requests_in"], a_hwid)
    b["requests_out"] = _remove(b["requests_out"], a_hwid)
    save()


func request_friend(a_hwid: String, b_hwid: String) -> void:
    var a: Dictionary = accounts.get(a_hwid, {})
    var b: Dictionary = accounts.get(b_hwid, {})
    if a.is_empty() or b.is_empty():
        return
    if not a["requests_out"].has(b_hwid):
        a["requests_out"].append(b_hwid)
    if not b["requests_in"].has(a_hwid):
        b["requests_in"].append(a_hwid)
    save()


func remove_request(a_hwid: String, b_hwid: String) -> void:
    var a: Dictionary = accounts.get(a_hwid, {})
    var b: Dictionary = accounts.get(b_hwid, {})
    if a.is_empty() or b.is_empty():
        return
    a["requests_out"] = _remove(a["requests_out"], b_hwid)
    a["requests_in"] = _remove(a["requests_in"], b_hwid)
    b["requests_in"] = _remove(b["requests_in"], a_hwid)
    b["requests_out"] = _remove(b["requests_out"], a_hwid)
    save()


func _remove(arr: Array, v: String) -> Array:
    var out: Array = []
    for x in arr:
        if str(x) != v:
            out.append(x)
    return out
