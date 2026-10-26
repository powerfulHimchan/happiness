class_name SupplyShopMotion
extends RefCounted

## Display-only event clock. Economic values always come directly from the model.
const ENTER := .42
const PAGE := .30
const QUERY := .22
const SELECT := .26
const SLOT := .30
const WALLET := .45
const PURCHASE := .65
const RESTOCK := .60
const INSPECTOR := .25
var entering := ENTER
var paging := PAGE
var querying := QUERY
var selecting := SELECT
var slotting := SLOT
var wallet_age := WALLET
var purchase_age := PURCHASE
var restock_age := RESTOCK
var inspector_age := INSPECTOR
var direction := 0
var purchase_id := ""
var purchased_cost := 0

func open() -> void:
	entering = 0.0
	paging = PAGE
	querying = QUERY
	selecting = SELECT
	slotting = SLOT
	wallet_age = WALLET
	purchase_age = PURCHASE
	restock_age = RESTOCK
	inspector_age = INSPECTOR
	purchase_id = ""
	purchased_cost = 0

func sync(previous: Dictionary, current: Dictionary) -> void:
	# First load, another rest stop and restored stock must never look like a purchase.
	if previous.is_empty() or not previous.has("stage") or int(previous.stage) != int(current.get("stage",0)): return
	if int(previous.get("coins",0)) != int(current.get("coins",0)): wallet_age = 0.0
	var before: Dictionary = previous.get("ledger",{})
	var after: Dictionary = current.get("ledger",{})
	var spent := int(after.get("spent",0))-int(before.get("spent",0))
	var line_count: int = after.get("lines",[]).size()-before.get("lines",[]).size()
	if spent <= 0 or line_count != 1: return
	if not previous.get("rerolled",false) and current.get("rerolled",false):
		if spent == RunSupplyShop.REROLL_COST: restock_age = 0.0
		return
	# A newly sold item plus a committed ledger increment confirms the transaction.
	for item in current.get("cards",[]):
		if SupplyShopArt.state(item) != "sold" or int(item.cost) != spent: continue
		for old in previous.get("cards",[]):
			if old.id == item.id and SupplyShopArt.state(old) != "sold":
				purchase_id = item.id
				purchased_cost = spent
				purchase_age = 0.0
				return

func page_changed(step: int) -> void:
	direction = clampi(step,-1,1)
	paging = 0.0

func query_changed() -> void:
	querying = 0.0

func selected() -> void:
	selecting = 0.0

func slot_selected() -> void:
	slotting = 0.0

func inspect() -> void:
	inspector_age = 0.0

func tick(delta: float) -> void:
	var dt := maxf(0,delta) if is_finite(delta) else 0.0
	entering = minf(ENTER,entering+dt)
	paging = minf(PAGE,paging+dt)
	querying = minf(QUERY,querying+dt)
	selecting = minf(SELECT,selecting+dt)
	slotting = minf(SLOT,slotting+dt)
	wallet_age = minf(WALLET,wallet_age+dt)
	purchase_age = minf(PURCHASE,purchase_age+dt)
	restock_age = minf(RESTOCK,restock_age+dt)
	inspector_age = minf(INSPECTOR,inspector_age+dt)
	if purchase_age >= PURCHASE:
		purchase_id = ""
		purchased_cost = 0

func is_animating() -> bool:
	return entering < ENTER or paging < PAGE or querying < QUERY or selecting < SELECT or slotting < SLOT or wallet_age < WALLET or purchase_age < PURCHASE or restock_age < RESTOCK or inspector_age < INSPECTOR

static func smooth(value: float) -> float:
	return 1.0-pow(1.0-clampf(value,0,1),3)

func pose(index: int, highlighted: bool) -> Dictionary:
	var delay := clampi(index,0,2)*.045
	var entrance := smooth((entering-delay)/(ENTER-.09))
	var page := smooth(paging/PAGE)
	return {"alpha":.65+.35*minf(entrance,minf(page,smooth(querying/QUERY))),"offset":Vector2(direction*6*(1-page),4*(1-entrance)),"selection":maxf(0,sin(selecting/SELECT*PI)) if highlighted else 0.0}

func purchase_pieces() -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	if purchase_age >= PURCHASE: return pieces
	var t := purchase_age/PURCHASE
	for index in 8:
		var angle := -PI+float(index)/7*PI
		pieces.append({"offset":Vector2(cos(angle)*44*t,sin(angle)*32*t-10*t),"alpha":1-t})
	return pieces
