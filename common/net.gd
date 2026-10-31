extends Node

## ENet transport. One autoload on both client and server; the server scene
## consumes `msg_received`, the client UI consumes `msg_received` as well.

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connected_to_server
signal connection_failed
signal server_disconnected
signal msg_received(from_id: int, data: Dictionary)

var peer: ENetMultiplayerPeer = null
var is_server := false
var is_client := false
var connected := false
var last_server := ""
var last_port := 7777


func _ready() -> void:
    multiplayer.peer_connected.connect(func(id): peer_connected.emit(id))
    multiplayer.peer_disconnected.connect(func(id): peer_disconnected.emit(id))
    multiplayer.connected_to_server.connect(func():
        connected = true
        connected_to_server.emit())
    multiplayer.connection_failed.connect(func():
        connected = false
        connection_failed.emit())
    multiplayer.server_disconnected.connect(func():
        connected = false
        server_disconnected.emit())


func start_server(port: int, max_clients: int = 64) -> int:
    _reset()
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_server(port, max_clients)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    is_server = true
    connected = true
    last_port = port
    return OK


func connect_to(server_ip: String, port: int) -> int:
    _reset()
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_client(server_ip, port)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    is_client = true
    last_server = server_ip
    last_port = port
    return OK


func disconnect_now() -> void:
    _reset()
    server_disconnected.emit()


func _reset() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
    peer = null
    is_server = false
    is_client = false
    connected = false


func send_to_server(data: Dictionary) -> void:
    if peer == null or not is_client:
        return
    _msg.rpc_id(1, JSON.stringify(data))


func send_to_peer(peer_id: int, data: Dictionary) -> void:
    if peer == null:
        return
    _msg.rpc_id(peer_id, JSON.stringify(data))


func broadcast(data: Dictionary) -> void:
    if peer == null:
        return
    _msg.rpc(JSON.stringify(data))


@rpc("any_peer", "call_remote", "reliable", 0)
func _msg(text: String) -> void:
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var sender := multiplayer.get_remote_sender_id()
    msg_received.emit(int(sender), parsed)
