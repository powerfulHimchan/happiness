class_name TaskBoardMotion
extends RefCounted

## Short, menu-only effects. Drawing never advances time or changes a task.
const OPEN := 0.42
const PAGE := 0.32
const QUERY := 0.24
const SELECT := 0.28
const FILL := 0.48
const READY := 1.20
const GLINT := 0.85
const CLAIM := 0.72
const PRESS := 0.25
const STAGGER := 0.025
var opening := OPEN
var paging := PAGE
var querying := QUERY
var selecting := SELECT
var filling := FILL
var ready_age := READY
var glint_age := GLINT
var claim_age := CLAIM
var press_age := PRESS
var direction := 0
var press_position := Vector2.ZERO
var claim_coins := 0
var starts := {}
var targets := {}

func open(cards: Array) -> void:
	opening = 0.0
	paging = PAGE
	querying = QUERY
	selecting = SELECT
	filling = 0.0
	ready_age = 0.0
	glint_age = 0.0
	claim_age = CLAIM
	press_age = PRESS
	claim_coins = 0
	starts.clear()
	targets.clear()
	for card in cards:
		starts[card.id] = 0.0
		targets[card.id] = fraction(card)

static func fraction(card: Dictionary) -> float:
	return clampf(float(card.get("fraction",float(card.progress)/maxf(1,float(card.target)))),0,1)

func sync(previous: Array, incoming: Array) -> void:
	var known := {}
	for card in previous: known[card.id] = card
	var next_targets := {}
	var next_starts := {}
	var changed := false
	var earned := 0
	for card in incoming:
		var goal := fraction(card)
		next_targets[card.id] = goal
		next_starts[card.id] = displayed(card.id,goal)
		if not is_equal_approx(float(targets.get(card.id,goal)),goal): changed = true
		if known.has(card.id) and not known[card.id].claimed and card.claimed:
			earned += int(card.coins)
	if changed:
		starts = next_starts
		filling = 0.0
	targets = next_targets
	if earned > 0:
		claim_age = 0.0
		claim_coins = earned
		glint_age = 0.0

func page_changed(step: int) -> void:
	direction = clampi(step,-1,1)
	paging = 0.0
	selecting = SELECT
	ready_age = 0.0
	glint_age = 0.0

func query_changed() -> void:
	querying = 0.0
	selecting = SELECT
	ready_age = 0.0
	glint_age = 0.0

func selected() -> void:
	selecting = 0.0

func pressed(position: Vector2) -> void:
	press_position = position
	press_age = 0.0

func tick(delta: float) -> void:
	var dt := maxf(0,delta) if is_finite(delta) else 0.0
	opening = minf(OPEN,opening+dt)
	paging = minf(PAGE,paging+dt)
	querying = minf(QUERY,querying+dt)
	selecting = minf(SELECT,selecting+dt)
	filling = minf(FILL,filling+dt)
	ready_age = minf(READY,ready_age+dt)
	glint_age = minf(GLINT,glint_age+dt)
	claim_age = minf(CLAIM,claim_age+dt)
	press_age = minf(PRESS,press_age+dt)
	if claim_age >= CLAIM: claim_coins = 0

func is_animating() -> bool:
	return opening < OPEN or paging < PAGE or querying < QUERY or selecting < SELECT or filling < FILL or ready_age < READY or glint_age < GLINT or claim_age < CLAIM or press_age < PRESS

static func ease_out(value: float) -> float:
	return 1.0-pow(1.0-clampf(value,0,1),3)

func displayed(id: String, fallback: float) -> float:
	return lerpf(float(starts.get(id,fallback)),float(targets.get(id,fallback)),ease_out(filling/FILL))

func pose(card: Dictionary, index: int, highlighted: bool) -> Dictionary:
	var delay := clampi(index,0,5)*STAGGER
	var enter := ease_out((opening-delay)/(OPEN-5*STAGGER))
	var page := ease_out((paging-delay)/(PAGE-5*STAGGER))
	var query := ease_out(querying/QUERY)
	var pulse := maxf(0,sin(selecting/SELECT*PI)) if highlighted else 0.0
	return {"alpha":0.55+0.45*minf(enter,minf(page,query)),
		"offset":Vector2(float(direction)*8*(1-page),5*(1-enter)),
		"selection":pulse,"fraction":displayed(card.id,fraction(card)),
		"ready":pow(sin(ready_age/READY*PI),2) if card.ready else 0.0,
		"glint":maxf(0,sin(glint_age/GLINT*PI)) if not card.claimed else 0.0,
		"query":1-query}

func header_alpha() -> float:
	return 0.55+0.45*ease_out(opening/OPEN)

func particles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if claim_age >= CLAIM: return result
	var progress := clampf(claim_age/CLAIM,0,1)
	for index in 10:
		var angle := -PI+float(index)/9.0*PI
		result.append({"offset":Vector2(cos(angle)*56*progress,sin(angle)*42*progress-18*progress),"alpha":1-progress,"radius":2.0+float(index%3)})
	return result
