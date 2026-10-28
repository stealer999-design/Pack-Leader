extends Node
## Connection management, autoloaded as `Network`.
## The host is the authoritative server and also plays (peer id 1).

signal player_joined(peer_id: int, info: Dictionary)
signal player_left(peer_id: int)

const DEFAULT_PORT := 24565
const MAX_CLIENTS := 3  # plus the host = 4 players
const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.5, 0.95), Color(0.3, 0.85, 0.4), Color(0.95, 0.75, 0.2), Color(0.8, 0.35, 0.9),
]

var player_name := "Player"
## Server only: peer_id -> { "name": String, "color": Color }.
var players := {}


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host(port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func close() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()


func register_host() -> void:
	_register(1, player_name)


func _on_connected_to_server() -> void:
	_request_register.rpc_id(1, player_name)


@rpc("any_peer", "reliable")
func _request_register(requested_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and not players.has(id):
		_register(id, requested_name)


func _register(id: int, requested_name: String) -> void:
	var clean := requested_name.strip_edges().substr(0, 16)
	if clean.is_empty():
		clean = "Player %d" % (players.size() + 1)
	var info := {"name": clean, "color": _free_color()}
	players[id] = info
	player_joined.emit(id, info)


func _free_color() -> Color:
	var used := players.values().map(func(p: Dictionary) -> Color: return p.color)
	for c in PLAYER_COLORS:
		if c not in used:
			return c
	return Color.from_hsv(randf(), 0.6, 0.9)


func _on_peer_disconnected(id: int) -> void:
	if players.erase(id):
		player_left.emit(id)
