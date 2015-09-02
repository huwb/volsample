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
public class AddFireFlies : MonoBehaviour {

	public float delay = 1;
	public Transform prefab;
	public float timer = 0;

	void Update () {
		timer = Mathf.MoveTowards( timer, 0, Mathf.Max(Time.deltaTime,1.0f/30.0f) );
		if( timer == 0 )
		{
			Spawn( Mathf.PI/2.0f );
			Spawn( Mathf.PI/2.0f + CloudsBase.halfFov_horiz_rad );
			Spawn( Mathf.PI/2.0f - CloudsBase.halfFov_horiz_rad );

			timer = delay;
		}
	}

	void Spawn(float theta)
	{
		Transform inst = Instantiate( prefab ) as Transform;

		AdvectedScalesFlatland[] ars = GetComponents<AdvectedScalesFlatland> ();
		foreach (AdvectedScalesFlatland ar in ars) {
			Vector3 pos = transform.position + transform.TransformDirection( ar.View(theta) );
			//float r = drt.sampleR(Mathf.PI/2.0f);
			inst.position = pos; //transform.position + r * transform.forward;
			inst.GetComponent<FireFly> ().viewer = transform;
			return;
		}
	}
}
