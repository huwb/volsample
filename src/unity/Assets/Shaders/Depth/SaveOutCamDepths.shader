
Shader "Custom/Save Out Camera Depths"
{
	SubShader
	{
		Tags{ "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _CameraDepthTexture;

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 scrPos:TEXCOORD1;
			};

			v2f vert( appdata_base v )
			{
				v2f o;
				o.pos = UnityObjectToClipPos( v.vertex );
				o.scrPos = ComputeScreenPos( o.pos );
				return o;
			}

			float frag( v2f i ) : COLOR
			{
				float depthValue = LinearEyeDepth( tex2Dproj( _CameraDepthTexture, UNITY_PROJ_COORD( i.scrPos ) ).r );
				return depthValue;
			}
			ENDCG
		}
	}

	FallBack "VertexLit"
}
