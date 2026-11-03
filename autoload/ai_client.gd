## ai_client.gd (autoload "AIClient")
## Purpose: the one place the game talks to the Cloudflare AI Worker. Call
## request(endpoint, payload, timeout_s) and listen to `completed`. Every request ends
## with exactly ONE `completed` emit: ok=true with the Worker's JSON on success, or
## ok=false with an empty Dictionary on ANY failure (network error, non-2xx such as a
## 429 rate limit or a {fallback:true} refusal, unparsable JSON, or timeout). Callers
## treat ok=false as "use the non-AI fallback" and never show an error (no-text rule).
## Callers still check their own Features flag before calling.
## Never prints request or response bodies.
extends Node

## Emitted once per request() call, after the request finished, failed or timed out.
## `endpoint` is the same string passed to request(), so one listener can tell several
## kinds of request apart.
signal completed(endpoint: String, ok: bool, data: Dictionary)

## Where requests go. Defaults to the Balance const; the headless sim points it at
## unreachable test addresses instead of editing Balance. Game code leaves it alone.
var base_url: String = Balance.WORKER_URL


## POST `payload` as JSON to base_url + endpoint. Returns at once; the answer arrives
## later through `completed`. Safe to call many times at once: each call gets its own
## HTTPRequest node (one HTTPRequest can only run one request at a time).
func request(endpoint: String, payload: Dictionary, timeout_s: float) -> void:
	var http := HTTPRequest.new()
	# HTTPRequest has its own `timeout` property, but we keep it at 0 (off) and run our
	# own timer below, so the time limit covers connecting as well and behaves the same
	# on desktop and web.
	add_child(http)

	# GDScript lambdas copy local variables when they are created, so a plain `var done
	# := false` flipped inside one lambda would not be seen by the other. A Dictionary is
	# passed by reference, so all the lambdas below share this one and see each other's
	# changes. The HTTPRequest lives in it too, instead of being captured directly: the
	# timer can fire after the node is freed, and Godot logs an error when a lambda that
	# captured a freed node is called.
	var state: Dictionary = {"done": false, "http": http}

	# The single exit: whichever of "answer arrived" or "timer ran out" happens first
	# calls this; the second caller finds done == true and does nothing.
	var finish := func(ok: bool, data: Dictionary) -> void:
		if state.done:
			return
		state.done = true
		# queue_free deletes the node at the end of this frame, so it is safe to call
		# from inside the node's own signal.
		(state.http as HTTPRequest).queue_free()
		completed.emit(endpoint, ok, data)

	# The answer arrived (or the connection failed). `result` is the transport outcome
	# (connected, TLS ok, ...); `code` is the HTTP status. Only a 2xx with a JSON object
	# body counts as success; a 429 or a {fallback:true} refusal is non-2xx, so it fails.
	var on_done := func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var data: Variant = null
		if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
			data = _parse_object(body)
		if data == null:
			finish.call(false, {})
		else:
			finish.call(true, data)
	http.request_completed.connect(on_done)

	# Time ran out first: stop the download and report failure. SceneTree.create_timer
	# makes a one-shot timer that frees itself, so no Timer node is needed.
	var on_timeout := func() -> void:
		if state.done:
			return
		(state.http as HTTPRequest).cancel_request()
		finish.call(false, {})
	get_tree().create_timer(timeout_s).timeout.connect(on_timeout)

	var headers := PackedStringArray(["Content-Type: application/json"])
	# OS.has_feature("web") is true only in a browser build. Browsers add the Origin header
	# themselves (and forbid scripts from setting it); desktop runs must add it by hand or
	# the Worker's origin allowlist turns them away.
	if not OS.has_feature("web"):
		headers.append("Origin: " + Balance.AI_DESKTOP_ORIGIN)

	var err: Error = http.request(base_url + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		# The request never started (bad URL, etc.). call_deferred runs finish on the next
		# idle moment, so `completed` still arrives after request() has returned, just like
		# every other outcome; callers can rely on that order.
		finish.call_deferred(false, {})


## The body as a Dictionary, or null if it is not valid JSON or not a JSON object.
## (A `Variant` return type lets one function return either a Dictionary or null.)
func _parse_object(body: PackedByteArray) -> Variant:
	# A JSON instance (instead of the static JSON.parse_string) reports a bad body through
	# its return code without printing an engine error to the console.
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return null
	return json.data if json.data is Dictionary else null
