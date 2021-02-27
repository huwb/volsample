// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE)

// Standard raymarching - samples are placed on parallel planes that are orthogonal to the view z axis. Samples
// are stationary in view space (move with the camera). This exhibits heavy aliasing when the camera moves as
// the samples sweep through the voluem. An alternative would be Fixed-R sampling (samples placed on concentric
// spheres emanating from the viewer position). This layout works better for camera rotations but breaks down
// for sideways and up/down camera motion.

// Structured volume sampling places samples on world aligned planes that are parallel to pentagons of a
// dodecahedron. Illustrations: https://raw.githubusercontent.com/huwb/volsample/master/doc/volsample.pptx.
// With this setup the only motion of samples is parallel to the sampling planes, which are densely sampled
// an aliasing is not an issue.

Shader "VolSample/Volume Render"
{
	Properties {
		_MainTex( "", 2D ) = "white" {}
	}
	
	CGINCLUDE;

	// different sampling types implemented as shader options
	#pragma shader_feature STRUCTURED_SAMPLING
	#pragma shader_feature FIXEDZ_PINSAMPLES

	// also select scene in this way.. :(
	#pragma shader_feature SCENE_CLOUDS
	#pragma shader_feature SCENE_SPONZA


	uniform sampler2D _MainTex;
	uniform sampler2D _CameraDepthTexture;

	#include "UnityCG.cginc"

	// Shared shader code for pixel view rays, given screen pos and camera frame vectors.

	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)

	// structured sampling - debug bevel areas
	#define DEBUG_BEVEL 0

	// structured sampling - debug weights
	#define DEBUG_WEIGHTS 0

	// strutured sampling - only intersection samples with planes orthogonal to z axis
	#define Z_PLANES_ONLY 0

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

	#if defined( STRUCTURED_SAMPLING )

	struct v2f
	{
		float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD1;
		float3 normal0 : TEXCOORD2;
		float3 normal1 : TEXCOORD3;
		float3 normal2 : TEXCOORD4;
		float3 blendWeights : COLOR;
	};

	// mesh uvs are vector2s so we unpack 3d normal 2 components
	float3 DecodeNormalFromUV( float2 uv )
	{
		float2 fEnc = uv * 4.0 - 2.0;
		float f = dot( fEnc, fEnc );
		float g = sqrt( 1 - f / 4.0 );
		return float3(fEnc * g, 1 - f / 2.0);
	}

	// vertex shader executed for the verts of the bevelled dodec. passes sampling plane normals
	// and weights to fragment shader.
	v2f vert( appdata_full v )
	{
		v2f o;

		// place the mesh camera-centered, and scale up to be clear of near plane
		o.pos = mul( UNITY_MATRIX_VP, float4(100.0 * v.vertex.xyz + _WorldSpaceCameraPos, v.vertex.w) );

		o.screenPos = ComputeScreenPos( o.pos );

		// decode sampling plane normals from the UV channels
		o.normal0 = DecodeNormalFromUV( v.texcoord.xy );
		o.normal1 = DecodeNormalFromUV( v.texcoord1.xy );
		o.normal2 = DecodeNormalFromUV( v.texcoord2.xy );

		// pass on the blend weights from the color channel
		o.blendWeights = v.color.rgb;

		#if Z_PLANES_ONLY
		// debug mode - only intersection with a single plane orientation - orthogonal to z axis
		o.normal0 = o.normal1 = o.normal2 = float3(0., 0., 1.);
		o.blendWeights = float3(1., 0., 0.);
		#endif

		return o;
	}

	#else // STRUCTURED_SAMPLING

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

	#endif // STRUCTURED_SAMPLING

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
		
		#if STRUCTURED_SAMPLING

		// structured sampling - samples lie on world space planes
		float4 clouds = RaymarchStructured( ro, rd, i.normal0, i.normal1, i.normal2, i.blendWeights, depthValue, RAYS );

		#else // STRUCTURED_SAMPLING

		// fixed-Z sampling
		float3 rdFixedZ = rd / dot( rd, _CamForward );
		#if FIXEDZ_PINSAMPLES
		// samples pinned to eliminated camera forward motion
		float4 clouds = RayMarchFixedZPinned( ro, rdFixedZ, depthValue );
		#else
		// samples move with camera
		float4 clouds = RayMarchFixedZ( ro, rdFixedZ, depthValue );
		#endif

		#endif // STRUCTURED_SAMPLING

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
		// Pass 0: One blend weight. Executed on bevelled dodecahedron pentagons.
		Pass
		{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag1
			ENDCG
		}

		// Pass 1: Two blend weights. Executed on bevelled dodecahedron rectangles.
		Pass
		{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag2
			ENDCG
		}

		// Pass 2: Three blend weights. Executed on bevelled dodecahedron triangles (corners).
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
