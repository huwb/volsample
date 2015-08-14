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

public class TestMotion : MonoBehaviour {

	public bool testRotate = false;
	public float testRotateY = 0.5f;
	public bool testTranslate = false;
	public float testTranslateX = 2.0f;
	public float testTranslateZ = 0.0f;
	
	// Use this for initialization
	void Start () {
	
	}
	
	// Update is called once per frame
	void Update()
	{
		#if UNITY_EDITOR
		if( UnityEditor.EditorApplication.isPlaying )
		{
			if( testTranslate )
			{
				transform.position += (testTranslateX * transform.right + testTranslateZ * transform.forward) * Time.deltaTime;
			}
			
			if( testRotate )
			{
				transform.rotation *= Quaternion.AngleAxis( Mathf.Rad2Deg*testRotateY * Time.deltaTime, Vector3.up );
			}
		}
		#endif
	}

}
