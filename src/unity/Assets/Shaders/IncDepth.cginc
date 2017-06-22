// Copyright (c) <2015> <Playdead>
// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE.TXT)
// AUTHOR: Lasse Jon Fuglsang Pedersen <lasse@playdead.com>

#ifndef __DEPTH_CGINC__
#define __DEPTH_CGINC__

#include "UnityCG.cginc"

uniform sampler2D_float _CameraDepthTexture;
uniform float4 _CameraDepthTexture_TexelSize;

#if UNITY_REVERSED_Z
#define ZCMP_GT(a, b) (a < b)
#else
#define ZCMP_GT(a, b) (a > b)
#endif

float depth_resolve_linear(float z)
{
#if CAMERA_ORTHOGRAPHIC
	#if UNITY_REVERSED_Z
		return (1.0 - z) * (_ProjectionParams.z - _ProjectionParams.y) + _ProjectionParams.y;
	#else
		return z * (_ProjectionParams.z - _ProjectionParams.y) + _ProjectionParams.y;
	#endif
#else
	return LinearEyeDepth(z);
#endif
}

float depth_sample_linear(float2 uv)
{
	return depth_resolve_linear(tex2D(_CameraDepthTexture, uv).x);
}

float3 find_closest_fragment_3x3(float2 uv)
{
	float2 dd = abs(_CameraDepthTexture_TexelSize.xy);
	float2 du = float2(dd.x, 0.0);
	float2 dv = float2(0.0, dd.y);

	float3 dtl = float3(-1, -1, tex2D(_CameraDepthTexture, uv - dv - du).x);
	float3 dtc = float3( 0, -1, tex2D(_CameraDepthTexture, uv - dv).x);
	float3 dtr = float3( 1, -1, tex2D(_CameraDepthTexture, uv - dv + du).x);

	float3 dml = float3(-1, 0, tex2D(_CameraDepthTexture, uv - du).x);
	float3 dmc = float3( 0, 0, tex2D(_CameraDepthTexture, uv).x);
	float3 dmr = float3( 1, 0, tex2D(_CameraDepthTexture, uv + du).x);

	float3 dbl = float3(-1, 1, tex2D(_CameraDepthTexture, uv + dv - du).x);
	float3 dbc = float3( 0, 1, tex2D(_CameraDepthTexture, uv + dv).x);
	float3 dbr = float3( 1, 1, tex2D(_CameraDepthTexture, uv + dv + du).x);

	float3 dmin = dtl;
	if (ZCMP_GT(dmin.z, dtc.z)) dmin = dtc;
	if (ZCMP_GT(dmin.z, dtr.z)) dmin = dtr;

	if (ZCMP_GT(dmin.z, dml.z)) dmin = dml;
	if (ZCMP_GT(dmin.z, dmc.z)) dmin = dmc;
	if (ZCMP_GT(dmin.z, dmr.z)) dmin = dmr;

	if (ZCMP_GT(dmin.z, dbl.z)) dmin = dbl;
	if (ZCMP_GT(dmin.z, dbc.z)) dmin = dbc;
	if (ZCMP_GT(dmin.z, dbr.z)) dmin = dbr;

	return float3(uv + dd.xy * dmin.xy, dmin.z);
}

/* UNUSED: tested slower than branching
float2 find_closest_fragment_3x3_packed(in float2 uv)
{
	float2 dd = abs(_CameraDepthTexture_TexelSize.xy);
	float2 du = float2(dd.x, 0.0);
	float2 dv = float2(0.0, dd.y);

	const float s = 100000.0;
	float dtl = trunc(s * tex2D(_CameraDepthTexture, uv - dv - du).x) + 0.1010;// -+-+
	float dtc = trunc(s * tex2D(_CameraDepthTexture, uv - dv).x)      + 0.0010;
	float dtr = trunc(s * tex2D(_CameraDepthTexture, uv - dv + du).x) + 0.0110;
	float dml = trunc(s * tex2D(_CameraDepthTexture, uv - du).x)      + 0.1000;
	float dmc = trunc(s * tex2D(_CameraDepthTexture, uv).x)           + 0.0000;
	float dmr = trunc(s * tex2D(_CameraDepthTexture, uv + du).x)      + 0.0100;
	float dbl = trunc(s * tex2D(_CameraDepthTexture, uv + dv - du).x) + 0.1001;
	float dbc = trunc(s * tex2D(_CameraDepthTexture, uv + dv).x)      + 0.0001;
	float dbr = trunc(s * tex2D(_CameraDepthTexture, uv + dv + du).x) + 0.0101;
	float enc = frac(min(dtl, min(dtc, min(dtr, min(dml, min(dmc, min(dmr, min(dbl, min(dbc, dbr)))))))));

	float ru = 0.0;
	float rv = 0.0;

	enc *= 10.0;
	ru -= trunc(enc);
	enc = frac(enc);

	enc *= 10.0;
	ru += trunc(enc);
	enc = frac(enc);

	enc *= 10.0;
	rv -= trunc(enc);
	enc = frac(enc);

	enc *= 10.0;
	rv += trunc(enc);
	enc = frac(enc);

	return uv + dd * float2(ru, rv);
}*/

float3 find_closest_fragment_5tap(float2 uv)
{
	float2 dd = abs(_CameraDepthTexture_TexelSize.xy);
	float2 du = float2(dd.x, 0.0);
	float2 dv = float2(0.0, dd.y);

	float2 tl = -dv - du;
	float2 tr = -dv + du;
	float2 bl =  dv - du;
	float2 br =  dv + du;

	float dtl = tex2D(_CameraDepthTexture, uv + tl).x;
	float dtr = tex2D(_CameraDepthTexture, uv + tr).x;
	float dmc = tex2D(_CameraDepthTexture, uv).x;
	float dbl = tex2D(_CameraDepthTexture, uv + bl).x;
	float dbr = tex2D(_CameraDepthTexture, uv + br).x;

	float dmin = dmc;
	float2 dif = 0.0;

	if (ZCMP_GT(dmin, dtl)) { dmin = dtl; dif = tl; }
	if (ZCMP_GT(dmin, dtr)) { dmin = dtr; dif = tr; }
	if (ZCMP_GT(dmin, dbl)) { dmin = dbl; dif = bl; }
	if (ZCMP_GT(dmin, dbr)) { dmin = dbr; dif = br; }

	return float3(uv + dif, dmin);
}

#endif//__DEPTH_CGINC__