// terrain.gdshader - the look of every solid tile (level_base.gd sets it on Terrain).
//
// Why: the terrain used to stamp a whole painting shrunk to 32 px into every tile,
// which read as wallpaper pasted over the scene. Now:
//   1. One seamless painted surface (made with texkit `tile`) is drawn in WORLD space,
//      so it runs continuously across tiles at a scale that matches the characters.
//   2. Edges are drawn the black-figure way: a black outline on every exposed side and,
//      on exposed tops, a Greek-key lip, so solid ground reads at a glance.
// Which sides are exposed is not computed here: level_base.gd picks one of 16 marker
// tiles per cell (atlas x = flags: 1 top, 2 left, 4 right, 8 bottom) and the shader reads the
// tile index back from UV. Two texture reads per pixel, WebGL2-safe.
shader_type canvas_item;

// The seamless surface painting, and how many world px one copy of it covers.
uniform sampler2D surface : source_color, repeat_enable, filter_linear_mipmap;
uniform float surface_px = 224.0;
// Multiplies the surface colour (the cave darkens the cliff rock with it).
uniform vec4 tint : source_color = vec4(1.0);
// The Greek-key strip drawn along exposed tops (art/tiles/meander.png).
uniform sampler2D lip : source_color, repeat_enable, filter_linear;
uniform float lip_px = 12.0;
// Thickness of the black outline on exposed sides, px.
uniform float edge_px = 3.0;
uniform vec4 edge_color : source_color = vec4(0.102, 0.078, 0.063, 1.0);
// The marker atlas: how many tiles across, and the size of one tile in px.
uniform float atlas_tiles = 16.0;
uniform float tile_px = 32.0;

// `varying` passes a value from vertex() to fragment(), interpolated per pixel.
varying vec2 world_pos;

void vertex() {
	// MODEL_MATRIX turns the tile layer's local position into world position.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Which marker tile this pixel belongs to, and where inside that tile it is (px).
	float index = floor(UV.x * atlas_tiles);
	vec2 local = vec2(fract(UV.x * atlas_tiles), UV.y) * tile_px;
	// Bit tests done with mod(), since GLSL ES floats have no & operator.
	bool top = mod(index, 2.0) >= 1.0;
	bool left = mod(floor(index / 2.0), 2.0) >= 1.0;
	bool right = mod(floor(index / 4.0), 2.0) >= 1.0;
	bool bottom = mod(floor(index / 8.0), 2.0) >= 1.0;

	vec3 col = texture(surface, world_pos / surface_px).rgb * tint.rgb;

	if (top) {
		if (local.y < edge_px) {
			col = edge_color.rgb;                                   // top outline
		} else if (local.y < edge_px + lip_px) {
			float v = (local.y - edge_px) / lip_px;                 // 0..1 down the lip
			col = texture(lip, vec2(world_pos.x / lip_px, v)).rgb;  // Greek key
		} else if (local.y < edge_px * 2.0 + lip_px) {
			col = edge_color.rgb;                                   // line under the lip
		}
	}
	if ((left && local.x < edge_px) || (right && local.x > tile_px - edge_px)
			|| (bottom && local.y > tile_px - edge_px)) {
		col = edge_color.rgb;                                       // side/bottom outline
	}
	COLOR = vec4(col, 1.0);
}
