
// Standard raymarching - samples are placed on parallel planes that are orthogonal to the view z axis. Samples
// are stationary in view space (move with the camera).

// An alternative would be Fixed-R sampling (samples placed on concentric spheres emanating from the viewer position).
// This layout works better for camera rotations but breaks down for sideways and up/down camera motion.

Shader "VolSample/Fixed-Z Volume Sampling" {
	Properties{
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

	uniform sampler2D _CameraDepthTexture;

	#include "Scenes/SceneClouds.cginc"
	//#include "Scenes/SceneFogCube.cginc"

	#include "RayMarchCore.cginc"
	#include "Camera.cginc"

	struct v2fd
	{
		float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD1;
	};

	v2fd vert( appdata_full v )
	{
		v2fd o;

		// place the mesh camera-centered.
		o.pos = mul( UNITY_MATRIX_VP, float4(100.0 * v.vertex.xyz + _WorldSpaceCameraPos, v.vertex.w) );
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
	
	float4 frag( v2fd i ) : SV_Target
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera( p, ro, rd );

		// fixed-Z sampling (instead of fixed-R sampling)
		float3 rdFixedZ = rd / dot( rd, _CamForward );

		// march through volume
		float4 clouds = RayMarchFixedZ( ro, rdFixedZ );

		// combine with background
		float3 col = combineColors( clouds, ro, rd );

		// post processing
		return postProcessing( col, q );
	}

	ENDCG

	Subshader
	{

		Tags{ "Queue" = "Transparent-1" }

			// There are three passes here just like the structured sampling case. Each pass represents a component of a bevelled dodecahedron.
			// For this Fixed-Z sampling, the geometry is irrelevant and the same pass is used for each component. A full screen quad/triangle would
			// be more officient but it is left like this for simplicity.

			Pass{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
			Pass{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
			Pass{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma target 3.0   
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
	}

	Fallback off

} // shader
