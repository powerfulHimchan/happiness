# Regional landscapes (GP-512–514)

Original SVG scenery in the existing cartoon/vector style:

- `windmill.svg`: meadow windmill, cloth sails, cottage door and fence.
- `inverted_grove.svg`: upward roots, hanging crowns and a woodland shrine.
- `star_observatory.svg`: broken pillars, armillary clock and constellations.

`RegionalLandscapeArt` draws the sky, distant silhouettes, landmarks and surface
ornaments into the world's cached canvas. The SVGs are 800×640; the same imported
textures are reused at each landmark. Nothing creates physics bodies, collision
shapes, animation timers, particles, random state or save data. Colors remain
muted behind combat actors and the existing attack warnings.

`meadow` shares the `wind` artwork. Other routes and free combat keep their
existing artwork. Region section changes refresh both the root background and
the terrain canvas; moving platform art uses the live platform rectangles.

Manual rendered QA:

```sh
LANDSCAPE_RENDER_DIR=/absolute/output godot --path game \
  --script res://tests/regional_landscape_render_test.gd
```

Requires a graphical display; the test captures the three regions, both sections,
battle/platform views and three viewport shapes, plus the three combat HUDs
and diagnostic reset.
