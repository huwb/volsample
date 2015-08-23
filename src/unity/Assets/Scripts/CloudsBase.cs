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

using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent (typeof (Camera))]
public abstract class CloudsBase : UnityStandardAssets.ImageEffects.PostEffectsBase
{
	[HideInInspector]
	public float m_distTravelledForward = 0;

	public Shader cloudsShader;
	protected Material cloudsMaterial = null;
	public Texture2D noiseTexture;

	[Tooltip("We repeat (mod) the raymarch offset applied, this is the period which needs to be larger than any ray march step to avoid pops")]
	public float m_largestPosRayStep = 128;

	[HideInInspector]
	public float m_forwardPinScale = 1;

	Vector3 lastPos;
	
	void LateUpdate()
	{
		if( AdvectedScalesSettings.instance.integrateForwardsMotion )
		{
			// this is a little bit awkward. we need to compute dist travelled based on the ray (radius) scale, otherwise it is meaningless.
			// however different rays have different scales. in this case we just pick the radius at the center. its possible that this could
			// be the average radius, i dont recall if i tried this.
			
			AdvectedScales[] ars = GetComponents<AdvectedScales>();
			AdvectedScales rVals = null;
			for (int i = 0; i < ars.Length; i++) {
				if( ars[i].radiusIndex == 0 )
				{
					rVals = ars[i];
					break;
				}
			}
			
			if (rVals != null)
			{
				// need to know how fast samples will move forwards/backwards under pinning, so that we can hold them stationary.
				// we take the middle scale. this is assumed in the advection code as well, and the advection will then compensate
				// for non-uniform scale for different rays.
				m_forwardPinScale = rVals.sampleR(Mathf.PI/2.0f)/rVals.radius;

				m_distTravelledForward += Vector3.Dot( transform.position - lastPos, transform.forward ) / m_forwardPinScale;
				
				// this is actually a bit of a fudge for an issue in the shader where the OnBoundary() function seems to fail
				// when the integrator is negative (?), so this keeps it positive
				m_distTravelledForward = Mathf.Repeat( m_distTravelledForward, m_largestPosRayStep );
			}
		}
		
		// heuristic to compute curvature, based on trading error of translational motion vs rotational motion
		//float r = 5.0f; // radius at which to measure rot error
		//float theta = Mathf.PI/4.0f;
		//targetCurv = 1.0f/(vx*vx/(omega*omega*r*r*Mathf.Tan(theta)*Mathf.Tan(theta)) + 1.0f);
		
		lastPos = transform.position;
	}

	public override bool CheckResources()
	{
		CheckSupport( true );
		
		cloudsMaterial = CheckShaderAndCreateMaterial( cloudsShader, cloudsMaterial );
		
		SetCameraFlag();
		
		if( !isSupported )
			ReportAutoDisable();

		// not really sure why this happens but it can and it kills the render and causes confusion
		if( float.IsNaN( m_distTravelledForward ) )
			m_distTravelledForward = 0;

		return isSupported;
	}
	
	void OnEnable()
	{
		SetCameraFlag();
	}
	
	void SetCameraFlag()
	{
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
	}
	
	public static float halfFov_rad
	{
		get
		{
			return Camera.main.aspect * Camera.main.fieldOfView * Mathf.Deg2Rad / 2.0f;
		}
	}
}


// to visualise the curvature energy, use this in my graphing shader https://www.shadertoy.com/view/Msl3Ws
/*
float r = 5.;
float omega = 3.;
float theta = PI/4.;
float vx = 10.;

// error term
bool fn1( float x, out float y, out vec4 col )
{
	col = vec4(1.,0.7,0.,1.);
	
	if( x < 0. ) { y = 0.; return true; }
    

    float k = x;
    
    // optimal k
    float mink = 1./(vx*vx/(omega*omega*r*r*tan(theta)*tan(theta)) + 1.);
    
    if( abs(k-mink)<0.01 )
        col = vec4(1.,0.,0.,1.);
    
    float vterm = vx*cos(theta)*k;
    vterm *= vterm;
    
    float wterm = omega*r*sin(theta)*(1.-k);
    wterm *= wterm;
    
	y = vterm + wterm;
    
    y /= 100.;
    
	return true;
}
*/
