
Shader "VolSample/Structured Volume Sampling" {
	Properties {
	}
	
	CGINCLUDE;
	
	#include "UnityCG.cginc"
	
	// the number of volume samples to take
	#define SAMPLE_COUNT 32

	// spacing between samples
	#define SAMPLE_PERIOD 1.
	
	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)
	
	// debug bevel areas
	#define DEBUG_BEVEL 0

	// debug weights
	#define DEBUG_WEIGHTS 0

	struct v2fd {
		float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD1;
		float3 normal0 : TEXCOORD2;
		float3 normal1 : TEXCOORD3;
		float3 normal2 : TEXCOORD4;
		float3 blendWeights : COLOR;
	};

	// passed in as this shader is run from a post proc camera
	//uniform float3 _CamPos;
	uniform float3 _CamForward;
	uniform float3 _CamRight;
	uniform float  _HalfFov;

	uniform sampler2D _CameraDepthTexture;

	#include "Scenes/SceneClouds.cginc"
	//#include "Scenes/SceneFogCube.cginc"

	#include "RayMarchCore.cginc"

	float3 DecodeNormalFromUV(float2 uv)
	{
		float2 fEnc = uv * 4 - 2;
		float f = dot(fEnc, fEnc);
		float g = sqrt(1 - f / 4);
		return float3(fEnc * g, 1 - f / 2);
	}
	
	v2fd vert(appdata_full v )
	{
		v2fd o;

		// place the mesh camera-centered.
		o.pos = mul( UNITY_MATRIX_VP, float4(100.0 * v.vertex.xyz + _WorldSpaceCameraPos, v.vertex.w) );

		o.screenPos = ComputeScreenPos(o.pos);

		// decode sampling plane normals from the UV channels
		o.normal0 = DecodeNormalFromUV(v.texcoord.xy);
		o.normal1 = DecodeNormalFromUV(v.texcoord1.xy);
		o.normal2 = DecodeNormalFromUV(v.texcoord2.xy);

		// pass on the blend weights from the color channel
		o.blendWeights = v.color.rgb;
		return o;
	}

	void computeCamera(in float2 screenPos, out float3 ro, out float3 rd)
	{
		float fovH = tan(_HalfFov);
		float fovV = tan(_HalfFov * _ScreenParams.y / _ScreenParams.x);
		float3 camUp = cross(_CamForward.xyz, _CamRight.xyz);
		ro = _WorldSpaceCameraPos;
		rd = normalize(_CamForward.xyz + screenPos.y * fovV * camUp + screenPos.x * fovH * _CamRight.xyz);
	}

	float3 combineColors(in float4 clouds, in float3 ro, in float3 rd)
	{
		float3 col = clouds.rgb;

		// check if any obscurance < 1
		if( clouds.a < 0.99 )
		{
			// let some of the sky light through
			col += skyColor( ro, rd ) * (1. - clouds.a);
		}

		return col;
	}
	
	float4 frag( v2fd i, in const int RAYS ) : SV_Target
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera( p, ro, rd );

		// march through volume
		float4 clouds = DoRaymarch( ro, rd, i.normal0, i.normal1, i.normal2, i.blendWeights, RAYS );

		// combine with background
		float3 col = combineColors( clouds, ro, rd );

		// post processing
		return postProcessing( col, q );
	}

	// fragment shaders for 1, 2 and 3 rays
	float4 frag1( v2fd i ) : SV_Target { return frag( i, 1 ); }
	float4 frag2( v2fd i ) : SV_Target { return frag( i, 2 ); }
	float4 frag3( v2fd i ) : SV_Target { return frag( i, 3 ); }

	ENDCG
	
Subshader {

	Tags { "Queue" = "Transparent-1" }

	// Pass 0: One blend weight
	Pass {
		ZTest Always Cull Off ZWrite Off

		CGPROGRAM
		#pragma target 3.0   
		#pragma vertex vert
		#pragma fragment frag1
		ENDCG
	}

	// Pass 1: Two blend weights
	Pass {
		ZTest Always Cull Off ZWrite Off

		CGPROGRAM
		#pragma target 3.0   
		#pragma vertex vert
		#pragma fragment frag2
		ENDCG
	}

	// Pass 2: Three blend weights
	Pass {
		ZTest Always Cull Off ZWrite Off

		CGPROGRAM
		#pragma target 3.0   
		#pragma vertex vert
		#pragma fragment frag3
		ENDCG
	}
}

Fallback off
	
} // shader
