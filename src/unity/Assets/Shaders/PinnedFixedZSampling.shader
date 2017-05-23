
// Standard raymarching - samples are placed on parallel planes that are orthogonal to the view z axis. Samples
// are stationary in view space (move with the camera).

// An alternative would be Fixed-R sampling (samples placed on concentric spheres emanating from the viewer position).
// This layout works better for camera rotations but breaks down for sideways and up/down camera motion.

Shader "VolSample/Fixed-Z Pinned" {
	Properties{
		_MainTex( "", 2D ) = "white" {}
	}
	
	CGINCLUDE;
	
	#include "UnityCG.cginc"
	
	uniform sampler2D _MainTex;
	uniform sampler2D _CameraDepthTexture;

	#include "RenderSettings.cginc"

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
	
	float4 frag( v2f i ) : SV_Target
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera( p, ro, rd );

		// fixed-Z sampling (instead of fixed-R sampling)
		float3 rdFixedZ = rd / dot( rd, _CamForward );

		// z buffer / scene depth for this pixel
		float depthValue = LinearEyeDepth( tex2Dproj( _CameraDepthTexture, UNITY_PROJ_COORD( i.screenPos ) ).r );

		// march through volume
		float4 clouds = RayMarchFixedZPinned( ro, rdFixedZ, depthValue );

		// add in camera render colours, if not zfar (so we exclude skybox)
		if( depthValue <= 999. )
		{
			float3 bgcol = tex2D( _MainTex, i.screenPos.xy );
			clouds.xyz += (1. - clouds.a) * bgcol;
			// assume zbuffer represents opaque surface
			clouds.a = 1.;
		}
		
		float3 col = combineColors( clouds, ro, rd );

		// post processing
		return postProcessing( col, q );
	}

	ENDCG

	Subshader
	{
		Pass
		{
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
