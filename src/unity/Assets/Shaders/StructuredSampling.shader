// New technique - samples are placed on fixed world-space planes

Shader "VolSample/Structured Sampling" {
	Properties {
	}
	
	CGINCLUDE;
	
	uniform sampler2D _MainTex;
	uniform sampler2D _CameraDepthTexture;

	#include "UnityCG.cginc"
	
	#include "RenderSettings.cginc"

	#include "RayMarchCore.cginc"
	#include "Camera.cginc"

	struct v2fd {
		float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD1;
		float3 normal0 : TEXCOORD2;
		float3 normal1 : TEXCOORD3;
		float3 normal2 : TEXCOORD4;
		float3 blendWeights : COLOR;
	};

	float3 DecodeNormalFromUV(float2 uv)
	{
		float2 fEnc = uv * 4.0 - 2.0;
		float f = dot(fEnc, fEnc);
		float g = sqrt(1 - f / 4.0);
		return float3(fEnc * g, 1 - f / 2.0);
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

		// z buffer / scene depth for this pixel
		float depthValue = LinearEyeDepth( tex2Dproj( _CameraDepthTexture, UNITY_PROJ_COORD( i.screenPos ) ).r );

		// march through volume
		float4 clouds = RaymarchStructured( ro, rd, i.normal0, i.normal1, i.normal2, i.blendWeights, depthValue, RAYS );

		// add in camera render colours, if not zfar (so we exclude skybox)
		if( depthValue <= 999. )
		{
			float3 bgcol = tex2D( _MainTex, q );
			clouds.xyz += (1. - clouds.a) * bgcol;
			// assume zbuffer represents opaque surface
			clouds.a = 1.;
		}

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
