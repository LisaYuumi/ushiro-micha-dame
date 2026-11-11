class_name NetSession
extends Node
## オンライン対戦のつながり。
## - 仲介(無料のお知らせ配信サービス ntfy.sh)は「相手を見つける」ためだけに使う。
##   ホストは「部屋の合言葉」の話題で待ち、参加する人はその話題に接続の申し込みを書きこむ。
##   (PeerJS の公開サーバーは、相手にメッセージを渡してくれなかったのでやめた)
## - つながったあとのゲームのやりとりは、ブラウザどうしの直接通信(WebRTC)。
## - ルールを動かすのはホストだけ。ほかの人は命令を送り、ホストは状態とお知らせを全員に配る。
##
## このノードは、ホストでも参加者でも同じ場所(Main/Net)に置く(RPC の宛先が同じになるように)。

signal status_changed(text: String)
## ホスト: 参加者が増えた/減った(godot の peer id の配列)
signal peers_changed(peer_ids: Array)
## 参加者: ホストとつながった
signal connected_to_host
## 参加者: ホストから届いた
signal lobby_received(info: Dictionary)
signal snapshot_received(snap: Dictionary)
signal events_received(events: Array)
## ホスト: 参加者から命令が届いた
signal command_received(peer_id: int, cmd: String, args: Array)
## 参加者: ホストとの通信が切れた
signal host_lost

## 仲介に使う無料サービス ntfy.sh(アカウント不要)。合言葉ごとの「話題」でメッセージを受け渡す
const NTFY_WS := "wss://ntfy.sh/%s/ws"
const NTFY_POST := "https://ntfy.sh/%s"
const ID_PREFIX := "ushiromichadame-v1-"
const ICE_SERVERS := [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]

var is_host := false
var is_online := false
var room_code := ""

var _ws := WebSocketPeer.new()
var _ws_was_open := false
var _my_topic := ""
var _send_queue: Array = []
var _sending := false
var _rtc := WebRTCMultiplayerPeer.new()
## 仲介サーバーでの相手の名前 -> {"conn": WebRTCPeerConnection, "godot_id": int}
var _conns := {}
var _host_signal_id := ""
var _my_godot_id := 1
## 参加者: ホストに申し込んでから直接つながるまでの残り時間(これを過ぎたら「つながらなかった」と出す)
var _connect_timeout := -1.0
const CONNECT_TIMEOUT := 15.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## 部屋を作る(ホスト)。4桁の合言葉を決めて、仲介サーバーで待つ
func host_room() -> void:
	is_host = true
	is_online = true
	room_code = "%04d" % randi_range(0, 9999)
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_server()
	multiplayer.multiplayer_peer = _rtc
	_connect_signaling(ID_PREFIX + "room-" + room_code)
	status_changed.emit("部屋を作っています…")


## 合言葉の部屋に入る(参加者)
func join_room(code: String) -> void:
	is_host = false
	is_online = true
	room_code = code
	_my_godot_id = randi_range(2, 1 << 30)
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_client(_my_godot_id)
	multiplayer.multiplayer_peer = _rtc
	_host_signal_id = ID_PREFIX + "room-" + code
	_connect_signaling(ID_PREFIX + "guest-%d-%d" % [randi(), randi()])
	status_changed.emit("部屋 %s をさがしています…" % code)


func leave() -> void:
	_ws.close()
	_send_queue.clear()
	for k in _conns:
		_conns[k]["conn"].close()
	_conns.clear()
	multiplayer.multiplayer_peer = null
	is_online = false


# --- 送る ---

## 参加者 → ホスト: 命令
func send_command(cmd: String, args: Array) -> void:
	if is_online and not is_host:
		_rpc_command.rpc_id(1, cmd, args)


## ホスト → 全員: 状態(こまめに送る。少し抜けてもよい)
func broadcast_snapshot(snap: Dictionary) -> void:
	if is_host and not multiplayer.get_peers().is_empty():
		_rpc_snapshot.rpc(snap)


## ホスト → 全員: お知らせ(必ず届ける)
func broadcast_events(events: Array) -> void:
	if is_host and not events.is_empty() and not multiplayer.get_peers().is_empty():
		_rpc_events.rpc(events)


## ホスト → 1人: 部屋の様子(だれが入っているか、あなたは何番か、始まったか)
func send_lobby(peer_id: int, info: Dictionary) -> void:
	if is_host:
		_rpc_lobby.rpc_id(peer_id, info)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_command(cmd: String, args: Array) -> void:
	if is_host:
		command_received.emit(multiplayer.get_remote_sender_id(), cmd, args)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(snap: Dictionary) -> void:
	snapshot_received.emit(snap)


@rpc("authority", "call_remote", "reliable")
func _rpc_events(events: Array) -> void:
	events_received.emit(events)


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(info: Dictionary) -> void:
	lobby_received.emit(info)


func _on_peer_connected(id: int) -> void:
	if is_host:
		peers_changed.emit(multiplayer.get_peers())
	elif id == 1:
		_connect_timeout = -1.0
		connected_to_host.emit()
		status_changed.emit("ホストとつながりました")


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		peers_changed.emit(multiplayer.get_peers())
	elif id == 1:
		host_lost.emit()
		status_changed.emit("ホストとの通信が切れました")


# --- 仲介(ntfy.sh) ---
# 自分あての「話題(topic)」を WebSocket で聞き、相手の話題には HTTP で書きこむ。
# ホストの話題は合言葉から決まる。参加者は自分の話題を作り、申し込みに「返事はここへ」と書く。
# 書きこみは順番に1つずつ送る(申し込みより先に別のお知らせが届かないように)。

func _connect_signaling(my_topic: String) -> void:
	_my_topic = my_topic
	_ws = WebSocketPeer.new()
	_ws_was_open = false
	var err := _ws.connect_to_url(NTFY_WS % my_topic)
	if err != OK:
		status_changed.emit("仲介サーバーにつなげません(%d)" % err)


func _process(delta: float) -> void:
	if not is_online:
		return
	if _connect_timeout > 0.0:
		_connect_timeout -= delta
		if _connect_timeout <= 0.0:
			status_changed.emit("直接つながりませんでした。\n全員が同じ Wi-Fi につないで(携帯回線は切って)、ページを読み込み直してもう一度試してください")
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			_on_ntfy_packet(_ws.get_packet().get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSED and _ws_was_open:
		_ws_was_open = false
		if _conns.is_empty() or not _any_connected():
			status_changed.emit("仲介サーバーから切れました。ページを読み込み直してください")


func _any_connected() -> bool:
	return not multiplayer.get_peers().is_empty()


func _on_ntfy_packet(text: String) -> void:
	var ev = JSON.parse_string(text)
	if typeof(ev) != TYPE_DICTIONARY:
		return
	match ev.get("event", ""):
		"open":
			_ws_was_open = true
			_on_signaling_open()
		"message":
			var msg = JSON.parse_string(str(ev.get("message", "")))
			if typeof(msg) == TYPE_DICTIONARY:
				_on_signal_message(msg)


func _on_signaling_open() -> void:
	if is_host:
		status_changed.emit("部屋ができました。合言葉: %s" % room_code)
	else:
		# ホストに接続を申し込む(申し込みは、直接通信の準備ができたら送られる)
		status_changed.emit("仲介サーバーにつながりました。部屋 %s に申し込んでいます…" % room_code)
		var conn := _make_conn(_host_signal_id, 1)
		conn.create_offer()
		_connect_timeout = CONNECT_TIMEOUT


## 相手の話題に書きこむ(順番待ちに入れる)
func _signal_send(dst_topic: String, msg: Dictionary) -> void:
	msg["from"] = _my_topic
	_send_queue.append([dst_topic, JSON.stringify(msg)])
	if not _sending:
		_send_next()


func _send_next() -> void:
	if _send_queue.is_empty():
		_sending = false
		return
	_sending = true
	var item: Array = _send_queue.pop_front()
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
			status_changed.emit("仲介サーバーに送れませんでした(%d/%d)。少し待ってもう一度試してください" % [result, code])
		_send_next())
	req.request(NTFY_POST % item[0], ["Content-Type: text/plain"], HTTPClient.METHOD_POST, item[1])


func _on_signal_message(msg: Dictionary) -> void:
	var type: String = msg.get("type", "")
	var src: String = str(msg.get("from", ""))
	if src == "" or src == _my_topic:
		return
	match type:
		"OFFER":
			if is_host:
				var gid: int = int(msg.get("godot_id", 0))
				if gid < 2 or _conns.has(src):
					return
				status_changed.emit("だれかが入ろうとしています…")
				var conn := _make_conn(src, gid)
				conn.set_remote_description("offer", msg["sdp"])
		"ANSWER":
			if not is_host and _conns.has(src):
				status_changed.emit("ホストから返事が来ました。直接つないでいます…")
				_conns[src]["conn"].set_remote_description("answer", msg["sdp"])
		"CANDIDATE":
			if _conns.has(src):
				_conns[src]["conn"].add_ice_candidate(msg["mid"], int(msg["idx"]), msg["cand"])


## 相手1人ぶんの直接通信を用意する
func _make_conn(remote_signal_id: String, remote_godot_id: int) -> WebRTCPeerConnection:
	var conn := WebRTCPeerConnection.new()
	conn.initialize({"iceServers": ICE_SERVERS})
	conn.session_description_created.connect(func(type: String, sdp: String) -> void:
		conn.set_local_description(type, sdp)
		_signal_send(remote_signal_id, {
			"type": "OFFER" if type == "offer" else "ANSWER",
			"sdp": sdp,
			"godot_id": _my_godot_id,
		}))
	conn.ice_candidate_created.connect(func(mid: String, idx: int, cand: String) -> void:
		_signal_send(remote_signal_id, {"type": "CANDIDATE", "mid": mid, "idx": idx, "cand": cand}))
	_rtc.add_peer(conn, remote_godot_id)
	_conns[remote_signal_id] = {"conn": conn, "godot_id": remote_godot_id}
	return conn
