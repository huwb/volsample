// approximates a spotlight with shadow. no attenuation of light by volume.
// it should be possible to use standard unity functionality to do this. it was easier for now to just implement it here.

float4x4 _ShadowCameraViewMatrix;
float4x4 _ShadowCameraProjMatrix;
uniform sampler2D _ShadowCameraDepths;

float Spotlight( in float3 pos )
{
	// transform point to view space
	float4 posShadowV = mul( _ShadowCameraViewMatrix, float4(pos, 1.) );

	// check if point is behind spot
	if( posShadowV.z >= 0. ) return 0.;

	// project point
	float4 posShadowP = mul( _ShadowCameraProjMatrix, posShadowV );
	posShadowP /= posShadowP.w;

	// outside spotlight cone?
	if( dot( posShadowP.xy, posShadowP.xy ) >= 1. )
		return 0.;

	// NDC to UV
	posShadowP.xy = .5 * posShadowP.xy + .5;
	float zSurf = -tex2Dlod( _ShadowCameraDepths, float4(posShadowP.xy, 0., 0.) );

	// hacky way to try to soften shadows
	return smoothstep( SAMPLE_PERIOD*4., -SAMPLE_PERIOD*4., zSurf - posShadowV.z );
}
