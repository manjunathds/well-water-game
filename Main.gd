extends Node2D

# ---------------------------------------------------------
# WELL WATER FETCHER - core game loop
# States: IDLE -> LOWERING -> FILLING -> RAISING -> CARRYING -> (loop)
# ---------------------------------------------------------

enum State { IDLE, LOWERING, FILLING, RAISING, CARRYING, GAME_OVER }
var state: int = State.IDLE

# --- well / bucket mechanics ---
var depth: float = 0.0            # 0 = top of well, MAX_DEPTH = bottom
const MAX_DEPTH: float = 400.0
const WATER_ZONE_START: float = 280.0
const WATER_ZONE_END: float = 340.0
const LOWER_SPEED: float = 160.0  # px/sec while auto-lowering
var lower_dir: int = 1            # 1 = going down, -1 = bounced back up

var fill_amount: float = 0.0      # 0..1
const FILL_TIME: float = 1.4

var rope_stress: float = 0.0      # 0..1, 1 = snaps
const STRESS_DECAY_PER_TAP: float = 0.16
const STRESS_GROWTH_IDLE: float = 0.25  # per second while raising w/o tapping
const RAISE_PER_TAP: float = 34.0
const RAISE_DRIFT_DOWN: float = 22.0    # per second, rope slips if you stop tapping

var stamina: float = 1.0          # 0..1
const STAMINA_COST_PER_TRIP: float = 0.14

var balance: float = 0.0          # -1..1, 0 = centered
var balance_velocity: float = 0.55
const CARRY_TIME: float = 4.0
var carry_timer: float = 0.0

var trips_completed: int = 0
var score: float = 0.0

# --- node refs ---
var sky: ColorRect
var ground: ColorRect
var well_shaft_bg: ColorRect
var water_zone_marker: ColorRect
var bucket_marker: ColorRect
var fill_bar_bg: ColorRect
var fill_bar_fg: ColorRect
var stress_bar_bg: ColorRect
var stress_bar_fg: ColorRect
var stamina_bar_bg: ColorRect
var stamina_bar_fg: ColorRect
var balance_track: ColorRect
var balance_marker: ColorRect
var tap_button: ColorRect
var tap_label: Label
var state_label: Label
var score_label: Label
var toast_label: Label
var toast_timer: float = 0.0

func _ready() -> void:
	randomize()
	_build_ui()
	_update_labels()

func _build_ui() -> void:
	sky = _rect(Color(0.55, 0.75, 0.92), Vector2(720, 700), Vector2(0, 0))
	ground = _rect(Color(0.45, 0.33, 0.2), Vector2(720, 580), Vector2(0, 700))

	well_shaft_bg = _rect(Color(0.15, 0.12, 0.1), Vector2(80, MAX_DEPTH), Vector2(320, 120))
	water_zone_marker = _rect(Color(0.2, 0.55, 0.95, 0.6), Vector2(80, WATER_ZONE_END - WATER_ZONE_START), Vector2(320, 120 + WATER_ZONE_START))
	bucket_marker = _rect(Color(0.8, 0.65, 0.2), Vector2(60, 24), Vector2(330, 120))

	state_label = _label("Tap START to lower the bucket", Vector2(30, 60), 26)
	score_label = _label("Trips: 0   Score: 0", Vector2(30, 20), 22)
	toast_label = _label("", Vector2(30, 560), 24)

	fill_bar_bg = _rect(Color(0.2,0.2,0.2), Vector2(300, 26), Vector2(60, 560))
	fill_bar_fg = _rect(Color(0.2, 0.6, 1.0), Vector2(0, 26), Vector2(60, 560))
	_label_static("Fill", Vector2(60, 590))

	stress_bar_bg = _rect(Color(0.2,0.2,0.2), Vector2(300, 26), Vector2(60, 630))
	stress_bar_fg = _rect(Color(0.9, 0.2, 0.2), Vector2(0, 26), Vector2(60, 630))
	_label_static("Rope stress", Vector2(60, 660))

	stamina_bar_bg = _rect(Color(0.2,0.2,0.2), Vector2(300, 26), Vector2(60, 700))
	stamina_bar_fg = _rect(Color(0.3, 0.9, 0.3), Vector2(0, 26), Vector2(60, 700))
	_label_static("Stamina", Vector2(60, 730))

	balance_track = _rect(Color(0.2,0.2,0.2), Vector2(400, 20), Vector2(160, 950))
	balance_marker = _rect(Color(1,1,0.3), Vector2(20, 40), Vector2(340, 940))
	balance_track.visible = false
	balance_marker.visible = false

	tap_button = _rect(Color(0.9, 0.4, 0.2), Vector2(220, 220), Vector2(250, 1020))
	tap_label = _label("START", Vector2(315, 1110), 30)

func _rect(color: Color, size: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = pos
	add_child(r)
	return r

func _label(text: String, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l

func _label_static(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 18)
	add_child(l)

# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------
func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true

	if pressed:
		_on_tap()

func _on_tap() -> void:
	match state:
		State.IDLE:
			state = State.LOWERING
			depth = 0.0
			lower_dir = 1
			rope_stress = 0.0
		State.LOWERING:
			if depth >= WATER_ZONE_START and depth <= WATER_ZONE_END:
				state = State.FILLING
				fill_amount = 0.0
				_toast("Nice! Bucket is in the water.")
			else:
				rope_stress = min(1.0, rope_stress + 0.22)
				_toast("Missed the water! Try again.")
				if rope_stress >= 1.0:
					_snap_rope()
		State.FILLING:
			pass # filling is automatic, tapping does nothing
		State.RAISING:
			depth = max(0.0, depth - RAISE_PER_TAP)
			rope_stress = max(0.0, rope_stress - STRESS_DECAY_PER_TAP)
			if depth <= 0.0:
				state = State.CARRYING
				carry_timer = CARRY_TIME
				balance = 0.0
				_toast("Bucket's up! Now carry it home steady.")
		State.CARRYING:
			balance -= sign(balance) * 0.35 if balance != 0.0 else 0.0
			balance = clamp(balance - balance_velocity * 0.12 * sign(balance_velocity), -1.0, 1.0)
		State.GAME_OVER:
			_reset_game()

# ---------------------------------------------------------
# PER-FRAME LOGIC
# ---------------------------------------------------------
func _process(delta: float) -> void:
	match state:
		State.LOWERING:
			depth += LOWER_SPEED * delta * lower_dir
			if depth >= MAX_DEPTH:
				depth = MAX_DEPTH
				lower_dir = -1
				rope_stress = min(1.0, rope_stress + 0.15)
				_toast("Hit the bottom! Bouncing back up.")
			elif depth <= 0.0 and lower_dir == -1:
				depth = 0.0
				lower_dir = 1
		State.FILLING:
			fill_amount += delta / FILL_TIME
			if fill_amount >= 1.0:
				fill_amount = 1.0
				state = State.RAISING
				_toast("Full! Tap fast to raise the bucket.")
		State.RAISING:
			depth += RAISE_DRIFT_DOWN * delta
			rope_stress = min(1.0, rope_stress + STRESS_GROWTH_IDLE * delta * 0.4)
			if depth >= MAX_DEPTH:
				depth = MAX_DEPTH
			if rope_stress >= 1.0:
				_snap_rope()
		State.CARRYING:
			balance_velocity = clamp(balance_velocity, -1.4, 1.4)
			balance += balance_velocity * delta
			if balance > 1.0:
				balance = 1.0
				balance_velocity = -abs(balance_velocity)
			elif balance < -1.0:
				balance = -1.0
				balance_velocity = abs(balance_velocity)
			if abs(balance) > 0.75:
				fill_amount = max(0.0, fill_amount - delta * 0.5)
			carry_timer -= delta
			if carry_timer <= 0.0:
				_complete_trip()

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.text = ""

	_update_visuals()
	_update_labels()

func _complete_trip() -> void:
	trips_completed += 1
	score += fill_amount * 100.0
	stamina = max(0.0, stamina - STAMINA_COST_PER_TRIP)
	_toast("Delivered! +%d points" % int(fill_amount * 100.0))
	if stamina <= 0.0:
		state = State.GAME_OVER
		state_label.text = "Exhausted! Tap to start a new day. Final score: %d" % int(score)
	else:
		state = State.IDLE
		depth = 0.0
		fill_amount = 0.0
		rope_stress = 0.0

func _snap_rope() -> void:
	_toast("Rope snapped! Bucket fell back down.")
	state = State.LOWERING
	depth = 0.0
	lower_dir = 1
	fill_amount = 0.0
	rope_stress = 0.0

func _reset_game() -> void:
	trips_completed = 0
	score = 0.0
	stamina = 1.0
	state = State.IDLE
	depth = 0.0
	fill_amount = 0.0
	rope_stress = 0.0

func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_timer = 1.6

# ---------------------------------------------------------
# VISUAL / LABEL UPDATES
# ---------------------------------------------------------
func _update_visuals() -> void:
	bucket_marker.position.y = 120 + depth
	fill_bar_fg.size.x = 300 * fill_amount
	stress_bar_fg.size.x = 300 * rope_stress
	stamina_bar_fg.size.x = 300 * stamina

	var carrying: bool = state == State.CARRYING
	balance_track.visible = carrying
	balance_marker.visible = carrying
	if carrying:
		balance_marker.position.x = 340 + (balance * 190.0) + 190.0 - 20.0

func _update_labels() -> void:
	score_label.text = "Trips: %d   Score: %d   Day stamina left: %d%%" % [trips_completed, int(score), int(stamina * 100)]
	match state:
		State.IDLE:
			state_label.text = "Tap the button to lower the bucket"
			tap_label.text = "LOWER"
		State.LOWERING:
			state_label.text = "Tap when the bucket reaches the blue water zone!"
			tap_label.text = "STOP"
		State.FILLING:
			state_label.text = "Filling..."
			tap_label.text = "..."
		State.RAISING:
			state_label.text = "Tap fast and steady to pull the bucket up!"
			tap_label.text = "PULL"
		State.CARRYING:
			state_label.text = "Tap to steady the bucket on the way home!"
			tap_label.text = "BALANCE"
		State.GAME_OVER:
			tap_label.text = "RESTART"
