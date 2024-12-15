#ifndef DEBUG_OVERLAY_SHADER_BASE_H
#define DEBUG_OVERLAY_SHADER_BASE_H
render_mode unshaded;

instance uniform vec4 color : source_color;

void vertex() {
	#ifdef POINT
	POINT_SIZE = 4.0;
	#endif
}

void fragment() {
	ALBEDO.rgb = color.rgb;
	ALPHA = color.a;
}
#endif