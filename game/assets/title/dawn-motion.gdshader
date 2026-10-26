shader_type canvas_item;
render_mode unshaded;

// Original image UVs remain stable across cover-cropped landscape ratios.
// One sample; tiny regional offsets keep architecture and menu text still.
uniform float elapsed_s = 0.0;

float ellipse(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.35, 1.0, length((p - center) / radius));
}

void fragment() {
	vec2 uv = UV;
	float phase = elapsed_s * 0.05235987756;
	float sky = (1.0 - smoothstep(0.12, 0.33, uv.y)) * (1.0 - smoothstep(0.70, 0.81, uv.x));
	float flowers = smoothstep(0.78, 0.98, uv.y) * smoothstep(0.36, 0.72, uv.x);
	float fall_a = ellipse(uv, vec2(0.700, 0.598), vec2(0.012, 0.060));
	float fall_b = ellipse(uv, vec2(0.764, 0.617), vec2(0.016, 0.077));
	float falls = max(fall_a, fall_b);
	uv.x += sky * sin(phase + uv.y * 9.0) * 0.003;
	uv.x += flowers * sin(phase * 40.0 + uv.x * 31.0) * 0.0013;
	uv.y += falls * sin(uv.y * 220.0 - phase * 96.0) * 0.0018;
	vec4 paint = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	float mist = ellipse(UV, vec2(0.69 + sin(phase * 2.0) * 0.012, 0.69), vec2(0.20, 0.11));
	float wisp = 0.5 + 0.5 * sin(UV.x * 60.0 + UV.y * 39.0 + phase * 6.0);
	paint.rgb = mix(paint.rgb, vec3(0.83, 0.94, 0.95), mist * wisp * 0.07);
	float dawn = ellipse(UV, vec2(0.67, 0.30), vec2(0.24, 0.35));
	paint.rgb += vec3(1.0, 0.76, 0.33) * dawn * (0.006 + 0.006 * sin(phase * 3.0));
	COLOR = paint;
}
