## sim_ai_client.gd - dev-only headless check (scene: tools/sim_ai_client.tscn).
## AIClient failure paths, with no real Worker needed: an unroutable address (it hangs
## or fails fast, depending on the network), a local server that accepts the connection
## but never answers (only our own timer can end it), a closed local port (refused), and
## a malformed URL (fails before it starts). Each must emit `completed` exactly once with
## ok=false and empty data, never synchronously inside request(), and must free its
## HTTPRequest node afterwards. Two requests in flight at once must not mix up.
## A tiny local HTTP server then plays the Worker: a 200 with an image gives ok=true and
## the test room turns it into the F10 debug sprite; a 429 refusal and a 200 with a body
## that is not JSON both give ok=false.
extends Node

## Nothing answers here (reserved private range): the connect hangs until our timeout.
const UNROUTABLE_URL: String = "http://10.255.255.1"
## Port 1 on this machine: nothing listens, so the connection is refused.
const REFUSED_URL: String = "http://127.0.0.1:1"
## Not a URL at all: HTTPRequest.request() refuses to start. The engine prints one
## "Invalid URL scheme" error line for it; that line is expected.
const BAD_URL: String = "not a url"
const SHORT_TIMEOUT_S: float = 0.5
## Longest any one case may take before the sim calls it hung (s).
const GUARD_S: float = 10.0
## Extra wait after the first emit, to catch a second (duplicate) emit.
const DUPLICATE_WAIT_S: float = 1.0
## HTTP ends its header block with an empty line: CR LF CR LF.
const HEADERS_END: String = "\r\n\r\n"

var _failures: int = 0
## Every `completed` emit seen, as {endpoint, ok, data}.
var _events: Array[Dictionary] = []


func _ready() -> void:
	AIClient.completed.connect(func(endpoint: String, ok: bool, data: Dictionary) -> void:
		_events.append({"endpoint": endpoint, "ok": ok, "data": data}))
	_check("base_url defaults to Balance.WORKER_URL", AIClient.base_url == Balance.WORKER_URL)
	var real_url: String = AIClient.base_url

	await _test_unroutable()
	await _test_silent_server_timeout()
	await _test_refused()
	await _test_bad_url()
	await _test_concurrent()
	await _test_success_and_debug_sprite()
	await _test_refusal_429()
	await _test_garbage_body()

	AIClient.base_url = real_url
	print("sim_ai_client: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _test_unroutable() -> void:
	_events.clear()
	AIClient.base_url = UNROUTABLE_URL
	AIClient.request("/test", {}, SHORT_TIMEOUT_S)
	_check("unroutable: no emit inside request()", _events.is_empty())
	await _wait_for_events(1)
	await _settle()
	_check("unroutable: exactly one emit", _events.size() == 1)
	_check_failed_event("unroutable", "/test")
	_check("unroutable: HTTPRequest freed", _http_children() == 0)


## A TCPServer that listens but never calls take_connection(): the OS still completes
## the connection, HTTPRequest sends its POST and waits for an answer that never comes.
## So the only way out is AIClient's own timer, which this case times.
func _test_silent_server_timeout() -> void:
	_events.clear()
	var server := TCPServer.new()
	# Port 0 asks the OS for any free port; get_local_port() says which one it picked.
	var listen_err: Error = server.listen(0, "127.0.0.1")
	_check("silent server: listening", listen_err == OK)
	if listen_err != OK:
		return
	AIClient.base_url = "http://127.0.0.1:%d" % server.get_local_port()
	var start_ms: int = Time.get_ticks_msec()
	AIClient.request("/test", {}, SHORT_TIMEOUT_S)
	await _wait_for_events(1)
	var elapsed_s: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	await _settle()
	server.stop()
	_check("silent server: exactly one emit", _events.size() == 1)
	_check_failed_event("silent server", "/test")
	# Loose bounds on purpose: a SceneTreeTimer adds up frame deltas, and the first delta
	# can include time from before request() was called, so it may fire a frame or so
	# early by the wall clock. Without the timer this request would hang until GUARD_S.
	_check("silent server: ended by the 0.5 s timeout (took %.2f s)" % elapsed_s,
			elapsed_s >= SHORT_TIMEOUT_S * 0.5 and elapsed_s < SHORT_TIMEOUT_S + 1.0)
	_check("silent server: HTTPRequest freed", _http_children() == 0)


func _test_refused() -> void:
	_events.clear()
	AIClient.base_url = REFUSED_URL
	AIClient.request("/test", {}, GUARD_S - 1.0)
	await _wait_for_events(1)
	await _settle()
	_check("refused: exactly one emit", _events.size() == 1)
	_check_failed_event("refused", "/test")
	_check("refused: HTTPRequest freed", _http_children() == 0)


func _test_bad_url() -> void:
	_events.clear()
	AIClient.base_url = BAD_URL
	AIClient.request("/test", {}, SHORT_TIMEOUT_S)
	_check("bad url: no emit inside request()", _events.is_empty())
	await _wait_for_events(1)
	# Wait past the timeout too: the timer must not add a second emit.
	await get_tree().create_timer(SHORT_TIMEOUT_S + DUPLICATE_WAIT_S).timeout
	_check("bad url: exactly one emit", _events.size() == 1)
	_check_failed_event("bad url", "/test")
	_check("bad url: HTTPRequest freed", _http_children() == 0)


## One slow request and one fast one at the same time: each gets its own emit.
func _test_concurrent() -> void:
	_events.clear()
	AIClient.base_url = REFUSED_URL
	AIClient.request("/fast", {"n": 1}, GUARD_S - 1.0)
	AIClient.base_url = UNROUTABLE_URL
	AIClient.request("/slow", {"n": 2}, SHORT_TIMEOUT_S)
	_check("concurrent: two HTTPRequest nodes in flight", _http_children() == 2)
	await _wait_for_events(2)
	await _settle()
	var endpoints: Array = _events.map(func(e: Dictionary) -> String: return e.endpoint)
	endpoints.sort()
	_check("concurrent: one emit per request", endpoints == ["/fast", "/slow"])
	_check("concurrent: both failed", _events.all(func(e: Dictionary) -> bool: return not e.ok and e.data.is_empty()))
	_check("concurrent: both HTTPRequests freed", _http_children() == 0)


## Fake Worker answers 200 with a 4x2 PNG, like the real POST /test.
func _test_success_and_debug_sprite() -> void:
	_events.clear()
	var image := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	image.fill(Balance.COLOR_GOLD)
	var b64: String = Marshalls.raw_to_base64(image.save_png_to_buffer())
	var body: String = JSON.stringify({"ok": true, "image": b64, "mime": "image/png"})
	var server: TCPServer = _start_fake_worker("200 OK", body)
	AIClient.request("/test", {}, GUARD_S - 1.0)
	await _wait_for_events(1)
	await _settle()
	server.stop()
	_check("success: exactly one emit", _events.size() == 1)
	var e: Dictionary = _events[0] if not _events.is_empty() else {}
	_check("success: ok=true with the Worker's JSON", e.get("ok", false) == true 			and (e.get("data", {}) as Dictionary).get("image", "") == b64)
	_check("success: HTTPRequest freed", _http_children() == 0)
	if e.is_empty():
		return

	# The test room's F10 handler, fed the same answer. instantiate() without add_child
	# builds the room but never runs its _ready, which is all this needs.
	var room: Node = load("res://scenes/test_room.tscn").instantiate()
	var before: int = room.get_child_count()
	room._on_ai_completed("/test", false, {})
	_check("debug sprite: ok=false adds nothing", room.get_child_count() == before)
	room._on_ai_completed("/test", true, e.data)
	var sprite: Sprite2D = room._ai_debug_sprite
	_check("debug sprite: made from the PNG", sprite != null and sprite.texture != null 			and sprite.texture.get_width() == 4 and sprite.texture.get_height() == 2)
	_check("debug sprite: longest side scaled to AI_DEBUG_SPRITE_SIZE", sprite != null 			and is_equal_approx(sprite.scale.x * 4.0, Balance.AI_DEBUG_SPRITE_SIZE))
	_check("debug sprite: unknown mime ignored", room._texture_from_base64(b64, "image/gif") == null)
	room.free()


## Refusals and rate limits come back non-2xx with {fallback:true}: that is a failure.
func _test_refusal_429() -> void:
	_events.clear()
	var server: TCPServer = _start_fake_worker("429 Too Many Requests", JSON.stringify({"fallback": true}))
	AIClient.request("/test", {}, GUARD_S - 1.0)
	await _wait_for_events(1)
	await _settle()
	server.stop()
	_check("429: exactly one emit", _events.size() == 1)
	_check_failed_event("429", "/test")


func _test_garbage_body() -> void:
	_events.clear()
	var server: TCPServer = _start_fake_worker("200 OK", "<html>not json</html>")
	AIClient.request("/test", {}, GUARD_S - 1.0)
	await _wait_for_events(1)
	await _settle()
	server.stop()
	_check("garbage body: exactly one emit", _events.size() == 1)
	_check_failed_event("garbage body", "/test")


# ---------------------------------------------------------------------------

## Listen on a free local port, point AIClient at it, and answer the first request with
## `status` and `body`. The answering runs in the background (see _answer_once).
func _start_fake_worker(status: String, body: String) -> TCPServer:
	var server := TCPServer.new()
	server.listen(0, "127.0.0.1")
	AIClient.base_url = "http://127.0.0.1:%d" % server.get_local_port()
	# Calling an async function WITHOUT `await` starts it and returns at its first
	# `await`; it then carries on by itself on later frames while we wait for the emit.
	_answer_once(server, status, body)
	return server


func _answer_once(server: TCPServer, status: String, body: String) -> void:
	var deadline_ms: int = Time.get_ticks_msec() + int(GUARD_S * 1000.0)
	while not server.is_connection_available():
		if Time.get_ticks_msec() > deadline_ms or not server.is_listening():
			return
		await get_tree().process_frame
	var peer: StreamPeerTCP = server.take_connection()
	# Read the request until the blank line that ends its headers (HEADERS_END), then
	# give the small JSON body a few frames to arrive and throw it away.
	var request_text: String = ""
	while not request_text.contains(HEADERS_END) and Time.get_ticks_msec() < deadline_ms:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var n: int = peer.get_available_bytes()
		if n > 0:
			request_text += peer.get_utf8_string(n)
		await get_tree().process_frame
	for i in 3:
		await get_tree().process_frame
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() > 0:
			peer.get_data(peer.get_available_bytes())
	var bytes: PackedByteArray = body.to_utf8_buffer()
	var head: String = "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close" \
			% [status, bytes.size()] + HEADERS_END
	peer.put_data(head.to_utf8_buffer() + bytes)
	# Keep the connection open a moment so HTTPRequest reads it all, then hang up.
	for i in 10:
		await get_tree().process_frame
	peer.disconnect_from_host()


## Wait (frame by frame) until `count` emits have arrived, or GUARD_S passes.
func _wait_for_events(count: int) -> void:
	var deadline_ms: int = Time.get_ticks_msec() + int(GUARD_S * 1000.0)
	while _events.size() < count and Time.get_ticks_msec() < deadline_ms:
		await get_tree().process_frame


## Give a duplicate emit time to show up, and queue_free time to finish.
func _settle() -> void:
	await get_tree().create_timer(DUPLICATE_WAIT_S).timeout
	await get_tree().process_frame


func _http_children() -> int:
	return AIClient.get_children().filter(func(n: Node) -> bool:
		return n is HTTPRequest and not n.is_queued_for_deletion()).size()


func _check_failed_event(label: String, endpoint: String) -> void:
	var e: Dictionary = _events[0] if not _events.is_empty() else {}
	_check("%s: endpoint echoed, ok=false, data empty" % label,
			e.get("endpoint", "") == endpoint and e.get("ok", true) == false and (e.get("data", {"x": 1}) as Dictionary).is_empty())


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
