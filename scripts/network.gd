extends Node
## Connection management, autoloaded as `Network`.
## The host is the authoritative server and also plays (peer id 1).
##
## Uses WebSockets so browser players can join too. Desktop builds can host;
## browser builds can only join (or play solo), because a web page cannot
## open a listening socket.

signal player_joined(peer_id: int, info: Dictionary)
signal player_left(peer_id: int)

const DEFAULT_PORT := 24565
const MAX_CLIENTS := 3  # plus the host = 4 players
## Generous buffers: the initial sync of a level sends every creature at once.
const BUFFER_SIZE := 1 << 20
const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.5, 0.95), Color(0.3, 0.85, 0.4), Color(0.95, 0.75, 0.2), Color(0.8, 0.35, 0.9),
]

var player_name := "Player"
## Server only: peer_id -> { "name": String, "color": Color }.
var players := {}


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _notification(what: int) -> void:
	# Disconnect before the scene tree is torn down. Otherwise a quitting host
	# sends a despawn for every node, after the world itself was already removed
	# on the clients, which floods their logs with errors.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Hosting needs a listening socket, which browsers don't allow.
func can_host() -> bool:
	return not OS.has_feature("web")


func host(port := DEFAULT_PORT) -> Error:
	var peer := _new_peer()
	var err := peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## `address` can be an IP or host name ("192.168.1.20"), with an optional port
## ("example.com:24565"), or a full WebSocket URL ("wss://abc.trycloudflare.com").
func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := _new_peer()
	var err := peer.create_client(server_url(address, port))
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Single player: no network at all. This peer is its own server.
func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


static func server_url(address: String, port := DEFAULT_PORT) -> String:
	address = address.strip_edges()
	if address.begins_with("ws://") or address.begins_with("wss://"):
		return address
	if ":" in address:
		return "ws://" + address
	return "ws://%s:%d" % [address, port]


func close() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()


func register_host() -> void:
	_register(1, player_name)


func _new_peer() -> WebSocketMultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = BUFFER_SIZE
	peer.outbound_buffer_size = BUFFER_SIZE
	return peer


func _on_connected_to_server() -> void:
	_request_register.rpc_id(1, player_name)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().size() > MAX_CLIENTS:
		(multiplayer.multiplayer_peer as WebSocketMultiplayerPeer).disconnect_peer(id)


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
