
// Standard raymarching - samples are placed on parallel planes that are orthogonal to the view z axis. Samples
// are stationary in view space (move with the camera).

// An alternative would be Fixed-R sampling (samples placed on concentric spheres emanating from the viewer position).
// This layout works better for camera rotations but breaks down for sideways and up/down camera motion.

Shader "VolSample/Naive Volume Render" {
	Properties{
		_MainTex( "", 2D ) = "white" {}
	}
	
	CGINCLUDE;
	// different sampling types implemented as shader options
	#pragma shader_feature TAA


	// also select scene in this way.. :(
	#pragma shader_feature SCENE_CLOUDS
	#pragma shader_feature SCENE_SPONZA


	uniform sampler2D _MainTex;
	uniform sampler2D _CameraDepthTexture;
	//uniform sampler2D _NoiseTex;

	#include "UnityCG.cginc"

	// Shared shader code for pixel view rays, given screen pos and camera frame vectors.

	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)

	// structured sampling - debug bevel areas
	#define DEBUG_BEVEL 0

	// structured sampling - debug weights
	#define DEBUG_WEIGHTS 0

	// scene
	#if SCENE_CLOUDS
	#include "Scenes/SceneClouds.cginc"
	#elif SCENE_SPONZA
	#include "Scenes/SceneFogSpotlight.cginc"
	#else
	#include "Scenes/SceneFogCube.cginc"
	#endif

	#include "RayMarchCore.cginc"
	#include "Camera.cginc"


	struct v2f
	{
		float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD1;
	};

	v2f vert( appdata_base v )
	{
		v2f o;
		o.pos = UnityObjectToClipPos( v.vertex );
		o.screenPos = ComputeScreenPos( o.pos );
		return o;
	}


	float3 combineColors( in float4 clouds, in float3 ro, in float3 rd )
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
	
	float4 frag( v2f i, in const int RAYS ) : SV_Target
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera( p, ro, rd );

		// z buffer / scene depth for this pixel
		float depthValue = LinearEyeDepth( tex2Dproj( _CameraDepthTexture, UNITY_PROJ_COORD( i.screenPos ) ).r );

		// march through volume

		// fixed-Z sampling
		float3 rdFixedZ = rd / dot( rd, _CamForward );

	#if TAA
		// samples move with camera
		float4 clouds = RayMarchWithJitter( ro, rdFixedZ, depthValue, _NoiseTex, i.screenPos.xy );
	#else
		float4 clouds = RayMarchFixedZ( ro, rdFixedZ, depthValue );
	#endif

		// add in camera render colours, if not zfar (so we exclude skybox)
		if( depthValue <= 999. )
		{
			float3 bgcol = tex2Dlod( _MainTex, float4(q, 0., 0.) );
			clouds.xyz += (1. - clouds.a) * bgcol;
			// assume zbuffer represents opaque surface
			clouds.a = 1.;
		}
		
		float3 col = combineColors( clouds, ro, rd );

		// post processing
		return postProcessing( col, q );
	}

	// fragment shaders for 1, 2 and 3 rays
	float4 frag1( v2f i ) : SV_Target{ return frag( i, 1 ); }
	float4 frag2( v2f i ) : SV_Target{ return frag( i, 2 ); }
	float4 frag3( v2f i ) : SV_Target{ return frag( i, 3 ); }

	ENDCG

	Subshader
	{
		// Pass 0: One blend weight
		Pass
		{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag1
			ENDCG
		}

		// Pass 1: Two blend weights
		Pass
		{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag2
			ENDCG
		}

		// Pass 2: Three blend weights
		Pass
		{
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
