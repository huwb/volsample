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
public class FireFly : MonoBehaviour {

	public Transform viewer;
	public float lifeTime = 5;

	Vector3 lastViewerPos;

	void Start () {
		lastViewerPos = viewer.position;
	}
	
	void LateUpdate() {
		transform.position += Vector3.Dot( viewer.position - lastViewerPos, viewer.forward ) * viewer.forward;
		lastViewerPos = viewer.position;

		float dt = Mathf.Max( Time.deltaTime, 1.0f/30.0f );

		lifeTime = Mathf.MoveTowards( lifeTime, 0, dt );

		if( lifeTime == 0 )
			DestroyImmediate( gameObject );
	}
}
