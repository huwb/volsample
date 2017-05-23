// Shared shader code for pixel view rays, given screen pos and camera frame vectors.

// sun direction
#define SUN_DIR float3(-0.70710678,0.,-.70710678)

// structured sampling - debug bevel areas
#define DEBUG_BEVEL 0

// structured sampling - debug weights
#define DEBUG_WEIGHTS 0

// scene
//#include "Scenes/SceneClouds.cginc"
#include "Scenes/SceneFogCube.cginc"
//#include "Scenes/SceneFogSpotlight.cginc"
