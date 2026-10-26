shader_type spatial;
// Player 2's coat: tints only the white-ish parts of the texture (the lab coat),
// skin, hair and shoes keep their colour.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 coat_tint : source_color = vec4(0.55, 0.7, 1.0, 1.0);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.3333));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float coat = smoothstep(0.5, 0.72, lum) * (1.0 - smoothstep(0.08, 0.2, sat));
	ALBEDO = mix(c, c * coat_tint.rgb, coat);
	ROUGHNESS = 0.8;
}
