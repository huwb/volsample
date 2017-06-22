// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE)

using UnityEngine;

public class TestMotion : MonoBehaviour
{
	public bool testRotate = false;
	public float testRotateY = 0.5f;
	public bool testTranslate = false;
	public float testTranslateX = 2.0f;
	public float testTranslateZ = 0.0f;
	
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
