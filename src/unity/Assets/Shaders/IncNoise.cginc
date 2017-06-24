// Copyright (c) <2015> <Playdead>
// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE.TXT)
// AUTHOR: Lasse Jon Fuglsang Pedersen <lasse@playdead.com>

#ifndef __NOISE_CGINC__
#define __NOISE_CGINC__

//====
//note: normalized random, float=[0;1[
float PDnrand( float2 n ) {
	return frac( sin(dot(n.xy, float2(12.9898f, 78.233f)))* 43758.5453f );
}
float2 PDnrand2( float2 n ) {
	return frac( sin(dot(n.xy, float2(12.9898f, 78.233f)))* float2(43758.5453f, 28001.8384f) );
}
float3 PDnrand3( float2 n ) {
	return frac( sin(dot(n.xy, float2(12.9898f, 78.233f)))* float3(43758.5453f, 28001.8384f, 50849.4141f ) );
}
float4 PDnrand4( float2 n ) {
	return frac( sin(dot(n.xy, float2(12.9898f, 78.233f)))* float4(43758.5453f, 28001.8384f, 50849.4141f, 12996.89f) );
}

//====
//note: signed random, float=[-1;1[
float PDsrand( float2 n ) {
	return PDnrand( n ) * 2 - 1;
}
float2 PDsrand2( float2 n ) {
	return PDnrand2( n ) * 2 - 1;
}
float3 PDsrand3( float2 n ) {
	return PDnrand3( n ) * 2 - 1;
}
float4 PDsrand4( float2 n ) {
	return PDnrand4( n ) * 2 - 1;
}

#endif//__NOISE_CGINC__