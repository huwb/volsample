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

namespace UnityStandardAssets.ImageEffects
{
	[AddComponentMenu ("Image Effects/Clouds")]
	public class Clouds : CloudsBase
	{
		public float m_samplesCurvature = 0.6f;

		[ImageEffectOpaque]
		void OnRenderImage( RenderTexture source, RenderTexture destination )
		{
			if( CheckResources() == false )
			{
				Graphics.Blit( source, destination );
				return;
			}

			cloudsMaterial.SetFloat( "_ForwardIntegrator", m_distTravelledForward );

			Vector4 camPos = new Vector4( transform.position.x, transform.position.y, transform.position.z, 0.0f );
			cloudsMaterial.SetVector( "_CamPos", camPos );
			
			Vector4 camForward = new Vector4( transform.forward.x, transform.forward.y, transform.forward.z, 0.0f );
			cloudsMaterial.SetVector( "_CamForward", camForward );
			Vector4 camRight = new Vector4( transform.right.x, transform.right.y, transform.right.z, 0.0f );
			cloudsMaterial.SetVector( "_CamRight", camRight );

			/*
			Vector4 spherePos = Vector4.zero;
			if( sphere )
				spherePos.Set( sphere.position.x, sphere.position.y, sphere.position.z, 0.0f );
			cloudsMaterial.SetVector( "_SphereCenter", spherePos );
			*/

			cloudsMaterial.SetTexture( "_NoiseTex", noiseTexture );

			Graphics.Blit( source, destination, cloudsMaterial, 0 );

			cloudsMaterial.SetFloat( "_SamplesCurvature", m_samplesCurvature );
			//cloudsMaterial.SetFloat( "_CenterOfRot",  centerOfRot );

			float fov = Mathf.Max( Camera.main.aspect, 1.0f ) * Camera.main.fieldOfView * Mathf.Deg2Rad;
			cloudsMaterial.SetFloat( "_HalfFov", fov/2.0f );
		}
	}
}
