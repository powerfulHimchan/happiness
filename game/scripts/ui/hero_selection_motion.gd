class_name HeroSelectionMotion
extends RefCounted

## Portrait-only mesh motion. No gameplay state, RNG, timers or save writes.
## Roan: steady breathing, then a grateful nod. Lumi: heel sway, then two happy hops.
const REACTION_SECONDS := 1.55
const COLUMNS := 10
const ROWS := 16
var elapsed_s := 0.0
var reaction_s := REACTION_SECONDS
var selected_id := ""
# Canvas commands reference mesh RIDs until rendering finishes. Keep both alive.
var _meshes: Dictionary = {}

func reset() -> void:
	elapsed_s = 0.0
	reaction_s = REACTION_SECONDS
	selected_id = ""

func select(character: String) -> void:
	selected_id = character
	reaction_s = 0.0

func tick(delta: float) -> void:
	var step := maxf(0.0, delta)
	elapsed_s = fposmod(elapsed_s + step, 120.0)
	reaction_s = minf(REACTION_SECONDS, reaction_s + step)

func snapshot(character: String, area: Rect2) -> Dictionary:
	var texture := PrototypeCharacters.texture(character)
	# Keep generous space for Lumi's hop and the silhouette's sway.
	var rect := SupplyShopArt.fitted(texture, area.grow(-area.size.y * .025))
	var phase := elapsed_s * (TAU / 4.0 if character == "roan" else TAU / 3.0)
	var p := reaction_s / REACTION_SECONDS
	var active := selected_id == character and p < 1.0
	var nod := pow(sin(PI * clampf((p - .12) / .62, 0, 1)), 2) if active and character == "roan" else 0.0
	var hop := 0.0
	if active and character == "lumi":
		hop = sin(PI * clampf((p - .12) / .28, 0, 1)) * .034
		hop += sin(PI * clampf((p - .48) / .26, 0, 1)) * .026
	var lean := sin(phase) * (.003 if character == "roan" else .009)
	lean += nod * .038 if character == "roan" else sin(p * TAU * 2) * .022 * sin(p * PI) if active else 0.0
	return {"rect": rect, "foot": Vector2(rect.get_center().x, rect.end.y), "rotation": lean,
		"breath": sin(phase) * (.005 if character == "roan" else .0035),
		"hop": hop * rect.size.y, "nod": nod, "phase": phase,
		"reaction": sin(PI * p) if active else 0.0, "character": character}

func draw(ui: Control, character: String, area: Rect2, alpha: float) -> void:
	var state := snapshot(character, area)
	var rect: Rect2 = state.rect
	var foot: Vector2 = state.foot
	var texture: AtlasTexture = PrototypeCharacters.texture(character)
	# Use the actual atlas region; the 80px transparent margin stays transparent.
	var visible := rect.size * texture.region.size / texture.get_size()
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in ROWS + 1:
		for column in COLUMNS + 1:
			var uv := Vector2(float(column) / COLUMNS, float(row) / ROWS)
			var point := rect.position + visible * uv
			var above_feet := rect.end.y - point.y
			point.y -= above_feet * float(state.breath)
			# Smooth head/shoulder motion without cut-out seams or detached joints.
			var head_weight := 1.0 - smoothstep(.25, .52, uv.y)
			point += Vector2(.012, .018) * rect.size * float(state.nod) * head_weight
			var edge_weight := smoothstep(.20, .48, absf(uv.x - .5))
			var cape_weight := sin(PI * clampf((uv.y - .35) / .65, 0, 1))
			point.x += sin(float(state.phase) + uv.y * 3.0) * rect.size.x * .008 * edge_weight * cape_weight
			point = foot + (point - foot).rotated(state.rotation) - Vector2(0, state.hop)
			points.append(point)
			uvs.append((texture.region.position + texture.region.size * uv) / texture.atlas.get_size())
	for row in ROWS:
		for column in COLUMNS:
			var a := row * (COLUMNS + 1) + column
			indices.append_array(PackedInt32Array([a, a + 1, a + COLUMNS + 1, a + 1, a + COLUMNS + 2, a + COLUMNS + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	_meshes[character] = mesh
	ui.draw_mesh(mesh, texture.atlas, Transform2D.IDENTITY, Color(1, 1, 1, alpha))
	# A restrained greeting glint follows each one-shot reaction and fades away.
	if state.reaction > .01:
		for index in (1 if character == "roan" else 2):
			var center := rect.position + rect.size * Vector2(.76 + index * .14, .20 - index * .05)
			center.y -= float(state.hop)
			var radius := rect.size.y * .014 * float(state.reaction)
			var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * .45, 0), center + Vector2(0, radius), center - Vector2(radius * .45, 0)])
			ui.draw_colored_polygon(diamond, Color(1.0, .88, .50, alpha * state.reaction))
