// Alpha-tested variant (railings, bars, foliage): the same shader, holes where alpha < 0.5.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
#define CUTOUT
#include "res://render/ps1.gdshaderinc"
