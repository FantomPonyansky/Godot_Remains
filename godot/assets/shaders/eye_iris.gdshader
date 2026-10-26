shader_type canvas_item;

// zrak (Obj.setColor 3) is the gray iris. The pupil is black and the sclera is white.
// Only the neutral mid-gray is multiplied by the eye color.
uniform vec3 iris_mul = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mx = max(tex.r, max(tex.g, tex.b));
	float mn = min(tex.r, min(tex.g, tex.b));
	bool iris = tex.a > 0.04 && mx >= 0.12 && mx <= 0.82 && (mx - mn) <= 0.05;
	if (iris) {
		COLOR = vec4(tex.rgb * iris_mul, tex.a);
	} else {
		COLOR = tex;
	}
}
