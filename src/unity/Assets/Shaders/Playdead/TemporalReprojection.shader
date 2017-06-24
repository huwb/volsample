// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Copyright (c) <2015> <Playdead>
// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE.TXT)
// AUTHOR: Lasse Jon Fuglsang Pedersen <lasse@playdead.com>

Shader "Playdead/Post/TemporalReprojection"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	CGINCLUDE
	//--- program begin
	
	#pragma only_renderers ps4 xboxone d3d11 d3d9 xbox360 opengl glcore gles3 metal vulkan
	#pragma target 3.0

	#pragma multi_compile CAMERA_PERSPECTIVE CAMERA_ORTHOGRAPHIC
	#pragma multi_compile MINMAX_3X3 MINMAX_3X3_ROUNDED MINMAX_4TAP_VARYING
	#pragma multi_compile __ UNJITTER_COLORSAMPLES
	#pragma multi_compile __ UNJITTER_NEIGHBORHOOD
	#pragma multi_compile __ UNJITTER_REPROJECTION
	#pragma multi_compile __ USE_YCOCG
	#pragma multi_compile __ USE_CLIPPING
	#pragma multi_compile __ USE_DILATION
	#pragma multi_compile __ USE_MOTION_BLUR
	#pragma multi_compile __ USE_MOTION_BLUR_NEIGHBORMAX
	#pragma multi_compile __ USE_OPTIMIZATIONS

	#include "UnityCG.cginc"
	#include "IncDepth.cginc"
	#include "IncNoise.cginc"

#if SHADER_API_MOBILE
	static const float FLT_EPS = 0.0001f;
#else
	static const float FLT_EPS = 0.00000001f;
#endif

	uniform float4 _JitterUV;// frustum jitter uv deltas, where xy = current frame, zw = previous

	uniform sampler2D _MainTex;
	uniform float4 _MainTex_TexelSize;

	uniform sampler2D_half _VelocityBuffer;
	uniform sampler2D _VelocityNeighborMax;

	uniform sampler2D _PrevTex;
	uniform float _FeedbackMin;
	uniform float _FeedbackMax;
	uniform float _MotionScale;

	struct v2f
	{
		float4 cs_pos : SV_POSITION;
		float2 ss_txc : TEXCOORD0;
	};

	v2f vert(appdata_img IN)
	{
		v2f OUT;

	#if UNITY_VERSION < 540
		OUT.cs_pos = UnityObjectToClipPos(IN.vertex);
	#else
		OUT.cs_pos = UnityObjectToClipPos(IN.vertex);
	#endif
	#if UNITY_SINGLE_PASS_STEREO
		OUT.ss_txc = UnityStereoTransformScreenSpaceTex(IN.texcoord.xy);
	#else
		OUT.ss_txc = IN.texcoord.xy;
	#endif

		return OUT;
	}

	// https://software.intel.com/en-us/node/503873
	float3 RGB_YCoCg(float3 c)
	{
		// Y = R/4 + G/2 + B/4
		// Co = R/2 - B/2
		// Cg = -R/4 + G/2 - B/4
		return float3(
			 c.x/4.0 + c.y/2.0 + c.z/4.0,
			 c.x/2.0 - c.z/2.0,
			-c.x/4.0 + c.y/2.0 - c.z/4.0
		);
	}

	// https://software.intel.com/en-us/node/503873
	float3 YCoCg_RGB(float3 c)
	{
		// R = Y + Co - Cg
		// G = Y + Cg
		// B = Y - Co - Cg
		return saturate(float3(
			c.x + c.y - c.z,
			c.x + c.z,
			c.x - c.y - c.z
		));
	}

	float4 sample_color(sampler2D tex, float2 uv)
	{
	#if USE_YCOCG
		float4 c = tex2D(tex, uv);
		return float4(RGB_YCoCg(c.rgb), c.a);
	#else
		return tex2D(tex, uv);
	#endif
	}

	float4 resolve_color(float4 c)
	{
	#if USE_YCOCG
		return float4(YCoCg_RGB(c.rgb).rgb, c.a);
	#else
		return c;
	#endif
	}

	float4 clip_aabb(float3 aabb_min, float3 aabb_max, float4 p, float4 q)
	{
	#if USE_OPTIMIZATIONS
		// note: only clips towards aabb center (but fast!)
		float3 p_clip = 0.5 * (aabb_max + aabb_min);
		float3 e_clip = 0.5 * (aabb_max - aabb_min) + FLT_EPS;

		float4 v_clip = q - float4(p_clip, p.w);
		float3 v_unit = v_clip.xyz / e_clip;
		float3 a_unit = abs(v_unit);
		float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

		if (ma_unit > 1.0)
			return float4(p_clip, p.w) + v_clip / ma_unit;
		else
			return q;// point inside aabb
	#else
		float4 r = q - p;
		float3 rmax = aabb_max - p.xyz;
		float3 rmin = aabb_min - p.xyz;

		const float eps = FLT_EPS;

		if (r.x > rmax.x + eps)
			r *= (rmax.x / r.x);
		if (r.y > rmax.y + eps)
			r *= (rmax.y / r.y);
		if (r.z > rmax.z + eps)
			r *= (rmax.z / r.z);

		if (r.x < rmin.x - eps)
			r *= (rmin.x / r.x);
		if (r.y < rmin.y - eps)
			r *= (rmin.y / r.y);
		if (r.z < rmin.z - eps)
			r *= (rmin.z / r.z);

		return p + r;
	#endif
	}

	float2 sample_velocity_dilated(sampler2D tex, float2 uv, int support)
	{
		float2 du = float2(_MainTex_TexelSize.x, 0.0);
		float2 dv = float2(0.0, _MainTex_TexelSize.y);
		float2 mv = 0.0;
		float rmv = 0.0;

		int end = support + 1;
		for (int i = -support; i != end; i++)
		{
			for (int j = -support; j != end; j++)
			{
				float2 v = tex2D(tex, uv + i * dv + j * du).xy;
				float rv = dot(v, v);
				if (rv > rmv)
				{
					mv = v;
					rmv = rv;
				}
			}
		}

		return mv;
	}

	float4 sample_color_motion(sampler2D tex, float2 uv, float2 ss_vel)
	{
		const float2 v = 0.5 * ss_vel;
		const int taps = 3;// on either side!

		float srand = PDsrand(uv + _SinTime.xx);
		float2 vtap = v / taps;
		float2 pos0 = uv + vtap * (0.5 * srand);
		float4 accu = 0.0;
		float wsum = 0.0;

		[unroll]
		for (int i = -taps; i <= taps; i++)
		{
			float w = 1.0;// box
			//float w = taps - abs(i) + 1;// triangle
			//float w = 1.0 / (1 + abs(i));// pointy triangle
			accu += w * sample_color(tex, pos0 + i * vtap);
			wsum += w;
		}

		return accu / wsum;
	}

	float4 temporal_reprojection(float2 ss_txc, float2 ss_vel, float vs_dist)
	{
		// read texels
	#if UNJITTER_COLORSAMPLES
		float4 texel0 = sample_color(_MainTex, ss_txc - _JitterUV.xy);
	#else
		float4 texel0 = sample_color(_MainTex, ss_txc);
	#endif
		float4 texel1 = sample_color(_PrevTex, ss_txc - ss_vel);

		// calc min-max of current neighbourhood
	#if UNJITTER_NEIGHBORHOOD
		float2 uv = ss_txc - _JitterUV.xy;
	#else
		float2 uv = ss_txc;
	#endif

	#if MINMAX_3X3 || MINMAX_3X3_ROUNDED

		float2 du = float2(_MainTex_TexelSize.x, 0.0);
		float2 dv = float2(0.0, _MainTex_TexelSize.y);

		float4 ctl = sample_color(_MainTex, uv - dv - du);
		float4 ctc = sample_color(_MainTex, uv - dv);
		float4 ctr = sample_color(_MainTex, uv - dv + du);
		float4 cml = sample_color(_MainTex, uv - du);
		float4 cmc = sample_color(_MainTex, uv);
		float4 cmr = sample_color(_MainTex, uv + du);
		float4 cbl = sample_color(_MainTex, uv + dv - du);
		float4 cbc = sample_color(_MainTex, uv + dv);
		float4 cbr = sample_color(_MainTex, uv + dv + du);

		float4 cmin = min(ctl, min(ctc, min(ctr, min(cml, min(cmc, min(cmr, min(cbl, min(cbc, cbr))))))));
		float4 cmax = max(ctl, max(ctc, max(ctr, max(cml, max(cmc, max(cmr, max(cbl, max(cbc, cbr))))))));

		#if MINMAX_3X3_ROUNDED || USE_YCOCG || USE_CLIPPING
			float4 cavg = (ctl + ctc + ctr + cml + cmc + cmr + cbl + cbc + cbr) / 9.0;
		#endif

		#if MINMAX_3X3_ROUNDED
			float4 cmin5 = min(ctc, min(cml, min(cmc, min(cmr, cbc))));
			float4 cmax5 = max(ctc, max(cml, max(cmc, max(cmr, cbc))));
			float4 cavg5 = (ctc + cml + cmc + cmr + cbc) / 5.0;
			cmin = 0.5 * (cmin + cmin5);
			cmax = 0.5 * (cmax + cmax5);
			cavg = 0.5 * (cavg + cavg5);
		#endif

	#elif MINMAX_4TAP_VARYING// this is the method used in v2 (PDTemporalReprojection2)

		const float _SubpixelThreshold = 0.5;
		const float _GatherBase = 0.5;
		const float _GatherSubpixelMotion = 0.1666;

		float2 texel_vel = ss_vel / _MainTex_TexelSize.xy;
		float texel_vel_mag = length(texel_vel) * vs_dist;
		float k_subpixel_motion = saturate(_SubpixelThreshold / (FLT_EPS + texel_vel_mag));
		float k_min_max_support = _GatherBase + _GatherSubpixelMotion * k_subpixel_motion;

		float2 ss_offset01 = k_min_max_support * float2(-_MainTex_TexelSize.x, _MainTex_TexelSize.y);
		float2 ss_offset11 = k_min_max_support * float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y);
		float4 c00 = sample_color(_MainTex, uv - ss_offset11);
		float4 c10 = sample_color(_MainTex, uv - ss_offset01);
		float4 c01 = sample_color(_MainTex, uv + ss_offset01);
		float4 c11 = sample_color(_MainTex, uv + ss_offset11);

		float4 cmin = min(c00, min(c10, min(c01, c11)));
		float4 cmax = max(c00, max(c10, max(c01, c11)));

		#if USE_YCOCG || USE_CLIPPING
			float4 cavg = (c00 + c10 + c01 + c11) / 4.0;
		#endif

	#else
		#error "missing keyword MINMAX_..."
	#endif

		// shrink chroma min-max
	#if USE_YCOCG
		float2 chroma_extent = 0.25 * 0.5 * (cmax.r - cmin.r);
		float2 chroma_center = texel0.gb;
		cmin.yz = chroma_center - chroma_extent;
		cmax.yz = chroma_center + chroma_extent;
		cavg.yz = chroma_center;
	#endif

		// clamp to neighbourhood of current sample
	#if USE_CLIPPING
		texel1 = clip_aabb(cmin.xyz, cmax.xyz, clamp(cavg, cmin, cmax), texel1);
	#else
		texel1 = clamp(texel1, cmin, cmax);
	#endif

		// feedback weight from unbiased luminance diff (t.lottes)
	#if USE_YCOCG
		float lum0 = texel0.r;
		float lum1 = texel1.r;
	#else
		float lum0 = Luminance(texel0.rgb);
		float lum1 = Luminance(texel1.rgb);
	#endif
		float unbiased_diff = abs(lum0 - lum1) / max(lum0, max(lum1, 0.2));
		float unbiased_weight = 1.0 - unbiased_diff;
		float unbiased_weight_sqr = unbiased_weight * unbiased_weight;
		float k_feedback = lerp(_FeedbackMin, _FeedbackMax, unbiased_weight_sqr);

		// output
		return lerp(texel0, texel1, k_feedback);
	}

	struct f2rt
	{
		fixed4 buffer : SV_Target0;
		fixed4 screen : SV_Target1;
	};

	f2rt frag(v2f IN)
	{
		f2rt OUT;

	#if UNJITTER_REPROJECTION
		float2 uv = IN.ss_txc - _JitterUV.xy;
	#else
		float2 uv = IN.ss_txc;
	#endif

	#if USE_DILATION
		//--- 3x3 norm (sucks)
		//float2 ss_vel = sample_velocity_dilated(_VelocityBuffer, uv, 1);
		//float vs_dist = depth_sample_linear(uv);

		//--- 5 tap nearest (decent)
		//float3 c_frag = find_closest_fragment_5tap(uv);
		//float2 ss_vel = tex2D(_VelocityBuffer, c_frag.xy).xy;
		//float vs_dist = depth_resolve_linear(c_frag.z);

		//--- 3x3 nearest (good)
		float3 c_frag = find_closest_fragment_3x3(uv);
		float2 ss_vel = tex2D(_VelocityBuffer, c_frag.xy).xy;
		float vs_dist = depth_resolve_linear(c_frag.z);
	#else
		float2 ss_vel = tex2D(_VelocityBuffer, uv).xy;
		float vs_dist = depth_sample_linear(uv);
	#endif

		// temporal resolve
		float4 color_temporal = temporal_reprojection(IN.ss_txc, ss_vel, vs_dist);

		// prepare outputs
		float4 to_buffer = resolve_color(color_temporal);
		
	#if USE_MOTION_BLUR
		#if USE_MOTION_BLUR_NEIGHBORMAX
			ss_vel = _MotionScale * tex2D(_VelocityNeighborMax, IN.ss_txc).xy;
		#else
			ss_vel = _MotionScale * ss_vel;
		#endif

		float vel_mag = length(ss_vel * _MainTex_TexelSize.zw);
		const float vel_trust_full = 2.0;
		const float vel_trust_none = 15.0;
		const float vel_trust_span = vel_trust_none - vel_trust_full;
		float trust = 1.0 - clamp(vel_mag - vel_trust_full, 0.0, vel_trust_span) / vel_trust_span;

		#if UNJITTER_COLORSAMPLES
			float4 color_motion = sample_color_motion(_MainTex, IN.ss_txc - _JitterUV.xy, ss_vel);
		#else
			float4 color_motion = sample_color_motion(_MainTex, IN.ss_txc, ss_vel);
		#endif

		float4 to_screen = resolve_color(lerp(color_motion, color_temporal, trust));
	#else
		float4 to_screen = resolve_color(color_temporal);
	#endif

		//// NOTE: velocity debug
		//to_screen.g += 100.0 * length(ss_vel);
		//to_screen = float4(100.0 * abs(ss_vel), 0.0, 0.0);

		// add noise
		float4 noise4 = PDsrand4(IN.ss_txc + _SinTime.x + 0.6959174) / 510.0;
		OUT.buffer = saturate(to_buffer + noise4);
		OUT.screen = saturate(to_screen + noise4);

		// done
		return OUT;
	}

	//--- program end
	ENDCG

	SubShader
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			ENDCG
		}
	}

	Fallback off
}