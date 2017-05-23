// test shadow receiver.
// based on: http://answers.unity3d.com/questions/180298/how-do-i-sample-a-shadowmap-in-a-custom-shader.html
// needed fallback: https://forum.unity3d.com/threads/light_attenuation-i-not-working-with-directional-lights.27126/

Shader "Unlit/ReceiveShadow"
{
	Properties
	{
		_MainTex( "Texture", 2D ) = "white" {}
	}

	CGINCLUDE
	#include "UnityCG.cginc"
	#include "AutoLight.cginc"
	#include "Lighting.cginc"
	ENDCG


	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Lighting On
			Tags{ "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			

			//#include "UnityCG.cginc"

			struct VSOut
			{
				float4 pos        : SV_POSITION;
				float2 uv        : TEXCOORD0;
				LIGHTING_COORDS( 3, 4 )
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			VSOut vert ( appdata_tan v )
			{
				VSOut o;
				o.pos = UnityObjectToClipPos( v.vertex );
				o.uv = v.texcoord.xy;
				TRANSFER_VERTEX_TO_FRAGMENT( o );
				return o;
			}
			
			fixed4 frag ( VSOut i) : SV_Target
			{
				float3 lightColor = _LightColor0.rgb;
				float3 lightDir = _WorldSpaceLightPos0;
				float4 colorTex = tex2D( _MainTex, i.uv.xy * (float2)5.0 );
				float  atten = LIGHT_ATTENUATION( i );

				float3 N = float3(0.0, 1.0, 0.0);

				float  NL = saturate( dot( N, lightDir ) );
				float3 color = colorTex.rgb * lightColor * NL * atten;
				return float4(color, colorTex.a); 
			}
			ENDCG
		}
	}

	Fallback "VertexLit", 2
}
