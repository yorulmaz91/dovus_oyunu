// =============================================================================
// hit_flash.gdshader  —  Vurus parlamasi
// NEREYE: Bir Sprite2D'nin "Material" alanina yeni bir ShaderMaterial yapip
//         bu shader'i sec. (Su an gerekmiyor - Fighter.flash() modulate ile
//         ayni isi yapiyor. Bu, gercek sprite'lara gectiginde daha guzel
//         gorunen yukseltme surumu.)
// Compatibility (OpenGL3) icin guvenlidir: ekran okumaz, sadece doku okur.
// =============================================================================
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	COLOR = c * COLOR;
}
