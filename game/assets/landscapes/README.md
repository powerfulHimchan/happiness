# Regional landscapes (GP-512–514 / GP-545–547)

Original SVG scenery in the existing cartoon/vector style:

- `windmill.svg`: meadow windmill, cloth sails, cottage door and fence.
- `inverted_grove.svg`: upward roots, hanging crowns and a woodland shrine.
- `star_observatory.svg`: broken pillars, armillary clock and constellations.
- `clockwork_foundry.svg`: abandoned workshop, stopped gears, pipes and chimney.
- `festival_carousel.svg`: carousel horses, observation wheel and ticket kiosk.
- `smiling_city_gate.svg`: white watchtowers, welcome clock and open archway.

`RegionalLandscapeArt` draws the sky, distant silhouettes, landmarks and surface
ornaments into the world's cached canvas. The SVGs are 800×640; the same imported
textures are reused at each landmark. Nothing creates physics bodies, collision
shapes, animation timers, particles, random state or save data. Colors remain
muted behind combat actors and the existing attack warnings.

`meadow` shares the `wind` artwork. The city gate retains its welcoming residents
and dialogue. The city core, heart arena and free combat keep their existing artwork. Region section changes refresh both the root background and
the terrain canvas; moving platform art uses the live platform rectangles.

Manual rendered QA:

```sh
LANDSCAPE_RENDER_DIR=/absolute/output godot --path game \
  --script res://tests/regional_landscape_render_test.gd
```

Requires a graphical display. The test captures 60 scenery views across six
routes, both sections where available, battle/platform views and three viewport
shapes. It also captures six combat HUDs and a diagnostic reset (67 images).
Festival platforms are captured after moving; forced redraws must preserve
checkpoint state and all platform geometry. The wheel and carousel in the SVG
are static scenery; real moving platforms retain their existing visible supports.
