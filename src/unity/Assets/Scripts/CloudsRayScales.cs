/*
The MIT License (MIT)

Copyright (c) 2015 Huw Bowles & Daniel Zimmermann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

using System;
using UnityEngine;

public class CloudsRayScales : CloudsBase
{
	[Tooltip("Change curve for adaptive sampling (in depth), big values concentrate samples near viewer")]
	[Range(0,3)] public float m_samplesAdaptivity = 0.1f;

	[Tooltip("Target raymarch total distance (not working well right now!)")]
	[Range(0.1f,256)] public float m_distMax = 128.0f;

	[Tooltip("Adaptive sampling - how quick to fade in new samples. Higher values means samples will fade in faster and therefore contribute to render sooner, at the possible cost of being noticeable")]
	[Range(1.0f,10.0f)] public float m_fadeSpeed = 1.0f;


	protected virtual void RenderSetupInternal()
	{
		cloudsMaterial.SetFloat( "_ForwardIntegrator", m_distTravelledForward );
		
		Vector4 camPos = new Vector4( transform.position.x, transform.position.y, transform.position.z, 0.0f );
		cloudsMaterial.SetVector( "_CamPos", camPos );
		
		Vector4 camForward = new Vector4( transform.forward.x, transform.forward.y, transform.forward.z, 0.0f );
		cloudsMaterial.SetVector( "_CamForward", camForward );
		Vector4 camRight = new Vector4( transform.right.x, transform.right.y, transform.right.z, 0.0f );
		cloudsMaterial.SetVector( "_CamRight", camRight );
		
		cloudsMaterial.SetTexture( "_NoiseTex", noiseTexture );
		
		cloudsMaterial.SetFloat( "_HalfFov", halfFov_horiz_rad );
		
		cloudsMaterial.SetFloat( "_SamplesAdaptivity", m_samplesAdaptivity*2 );
		cloudsMaterial.SetFloat( "_DistMax", m_distMax );
		
		
		// upload normalization constants for pdf, just because its easy to do so here
		float sa = m_samplesAdaptivity;
		//sa = (Mathf.Exp(sa) - 1.0f)/Mathf.Exp(1.0f);
		sa *= sa;
		float pdfNorm = (sa/Mathf.Log(1.0f + sa*m_distMax));
		if( sa <= Mathf.Epsilon )
			pdfNorm = 1.0f / m_distMax; // singularity when adaptivity == 0 (integral is invalid)
		cloudsMaterial.SetFloat( "_PdfNorm", pdfNorm );
		
		
		cloudsMaterial.SetFloat( "_FadeSpeed", m_fadeSpeed );
		
		
		// upload info needed to interpolate ray scales during ray march
		float radius0 = 10;
		float oneOverRadiusDiff = 50;
		AdvectedScales[] ars = GetComponents<AdvectedScales>();
		if( ars.Length > 0 )
		{
			if( ars.Length == 1 )
			{
				radius0 = ars[0].m_radius;
				oneOverRadiusDiff = 0;
			}
			else
			{
				radius0 = ars[0].m_radiusIndex < ars[1].m_radiusIndex ? ars[0].m_radius : ars[1].m_radius;
				float radius1 = ars[0].m_radiusIndex > ars[1].m_radiusIndex ? ars[0].m_radius : ars[1].m_radius;
				if( radius0 == radius1 )
					oneOverRadiusDiff = 0;
				else
					oneOverRadiusDiff = 1.0f / ( radius1 - radius0 );
			}
			
			cloudsMaterial.SetVector( "_SampleRadii", new Vector4( radius0, oneOverRadiusDiff, 0, 0 ) );
		}
		
		
		// this will be the ray scale at the center of the screen, used to do forward pinning properly
		cloudsMaterial.SetFloat( "_ForwardPinScale", m_forwardPinScale );
	}


	[ImageEffectOpaque]
	void OnRenderImage( RenderTexture source, RenderTexture destination )
	{
		if( CheckResources() == false )
		{
			Debug.LogError("Check resources failed");

			Graphics.Blit( source, destination );
			return;
		}

		RenderSetupInternal();

		// render!
		Graphics.Blit( source, destination, cloudsMaterial, 0 );
	}
}
