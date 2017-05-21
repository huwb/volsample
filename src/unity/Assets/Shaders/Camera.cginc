
// passed in as this shader is run from a post proc camera
//uniform float3 _CamPos;
uniform float3 _CamForward;
uniform float3 _CamRight;
uniform float  _HalfFov;

void computeCamera( in float2 screenPos, out float3 ro, out float3 rd )
{
	float fovH = tan( _HalfFov );
	float fovV = tan( _HalfFov * _ScreenParams.y / _ScreenParams.x );
	float3 camUp = cross( _CamForward.xyz, _CamRight.xyz );
	ro = _WorldSpaceCameraPos;
	rd = normalize( _CamForward.xyz + screenPos.y * fovV * camUp + screenPos.x * fovH * _CamRight.xyz );
}
