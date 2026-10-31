class_name AiMemory
extends RefCounted

## 让 AI 从真人出牌里学习：按「局面上下文 + 所选技能」计数，归一化成小幅加分。
## 数据保存在 user:// 下，服务端与单机客户端共用同一套格式。
## 只记录真人（非 AI）的合法出牌，AI 自己的选择不计入。

const PATH := "user://mxdpppplus_ai_memory.json"
const MAX_GLOBAL := 8.0
const MAX_CTX := 10.0

static var _data: Dictionary = {}
static var _dirty := false


static func _load() -> void:
    if not _data.is_empty():
        return
    _data = {"v": 1, "total": 0, "global": {}, "ctx": {}}
    if not FileAccess.file_exists(PATH):
        return
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null:
        return
    var d = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(d) != TYPE_DICTIONARY:
        return
    _data["total"] = int(d.get("total", 0))
    var g = d.get("global", {})
    var c = d.get("ctx", {})
    if typeof(g) == TYPE_DICTIONARY:
        _data["global"] = g
    if typeof(c) == TYPE_DICTIONARY:
        _data["ctx"] = c


static func context_key(hp_t: int, luck_t: int, round_no: int) -> String:
    var phase := "early"
    if round_no > 8:
        phase = "late"
    elif round_no > 3:
        phase = "mid"
    var hpb := "low" if hp_t <= 4 else "ok"
    var lb := "poor"
    if luck_t >= 60:
        lb = "rich"
    elif luck_t >= 30:
        lb = "mid"
    return "%s|%s|%s" % [phase, hpb, lb]


static func record(card_id: String, hp_t: int, luck_t: int, round_no: int) -> void:
    if card_id == "":
        return
    _load()
    _data["total"] = int(_data["total"]) + 1
    var g: Dictionary = _data["global"]
    g[card_id] = int(g.get(card_id, 0)) + 1
    var key := context_key(hp_t, luck_t, round_no)
    var c: Dictionary = _data["ctx"].get(key, {})
    c[card_id] = int(c.get(card_id, 0)) + 1
    _data["ctx"][key] = c
    _dirty = true


static func absorb(observations: Array) -> void:
    for o in observations:
        if typeof(o) != TYPE_DICTIONARY:
            continue
        record(str(o.get("card", "")), int(o.get("hp_t", 10)), int(o.get("luck_t", 0)),
               int(o.get("round", 1)))


static func snapshot() -> Dictionary:
    _load()
    var total := maxi(1, int(_data["total"]))
    var out := {"global": {}, "ctx": {}}
    var g: Dictionary = _data["global"]
    for card in g.keys():
        var w := minf(MAX_GLOBAL, float(g[card]) / float(total) * 40.0)
        if w > 0.05:
            out["global"][card] = w
    var ctxd: Dictionary = _data["ctx"]
    for key in ctxd.keys():
        var bucket: Dictionary = ctxd[key]
        var sum := 0
        for card in bucket.keys():
            sum += int(bucket[card])
        if sum <= 0:
            continue
        var norm: Dictionary = {}
        for card in bucket.keys():
            var w := minf(MAX_CTX, float(bucket[card]) / float(sum) * 22.0)
            if w > 0.05:
                norm[card] = w
        if not norm.is_empty():
            out["ctx"][key] = norm
    return out


static func flush() -> void:
    _load()
    if not _dirty:
        return
    var f := FileAccess.open(PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(_data))
    f.close()
    _dirty = false


static func total() -> int:
    _load()
    return int(_data["total"])


static func reset() -> void:
    _data = {"v": 1, "total": 0, "global": {}, "ctx": {}}
    _dirty = true
    flush()
