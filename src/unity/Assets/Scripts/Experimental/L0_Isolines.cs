using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class L0_Isolines : MonoBehaviour
{
	void Start () {
	
	}

	float weightKernel( float x, float z )
	{
		return 1.0f - Mathf.Max( Mathf.Abs(x), Mathf.Abs(z) );
	}

	void Update()
	{
		float posX = transform.position.x;
		float fracX = Mathf.Repeat( posX, 1f );
		posX -= fracX;
		float posZ = transform.position.z;
		float fracZ = Mathf.Repeat( posZ, 1f );
		posZ -= fracZ;

		DrawStructure( weightKernel( -fracX, -fracZ ), posX, posZ );
		DrawStructure( weightKernel( 1f-fracX, -fracZ ), posX+1f, posZ );
		DrawStructure( weightKernel( -fracX, 1f-fracZ ), posX, posZ+1f );
		DrawStructure( weightKernel( 1f-fracX, 1f-fracZ ), posX+1f, posZ+1f );

		/*
		float cx = posX + 0.5f;
		float cz = posZ + 0.5f;
		for( float i = 0f; i < 10f; i += 1f )
		{
			float r = i+0.5f;

			// top x
			Debug.DrawLine( new Vector3( cx-r-1f, 0f, cz+r ), new Vector3( cx-r, 0f, cz+r ), new Color(1f,0f,0f,(1f-fracZ)*(1f-fracX)) );
			Debug.DrawLine( new Vector3( cx+r-1f, 0f, cz+r ), new Vector3( cx+r, 0f, cz+r ), new Color(1f,0f,0f,(1f-fracZ)*(1f-fracX)) );
			Debug.DrawLine( new Vector3( cx-r, 0f, cz+r ), new Vector3( cx-r+1f, 0f, cz+r ), new Color(1f,0f,0f,(1f-fracZ)*fracX) );
			Debug.DrawLine( new Vector3( cx+r+1f, 0f, cz+r ), new Vector3( cx+r, 0f, cz+r ), new Color(1f,0f,0f,(1f-fracZ)*fracX) );
			// bottom x
			Debug.DrawLine( new Vector3( cx-r-1f, 0f, cz-r ), new Vector3( cx-r, 0f, cz-r ), new Color(1f,0f,0f,(fracZ)*(1f-fracX)) );
			Debug.DrawLine( new Vector3( cx+r-1f, 0f, cz-r ), new Vector3( cx+r, 0f, cz-r ), new Color(1f,0f,0f,(fracZ)*(1f-fracX)) );
			Debug.DrawLine( new Vector3( cx-r, 0f, cz-r ), new Vector3( cx-r+1f, 0f, cz-r ), new Color(1f,0f,0f,(fracZ)*fracX) );
			Debug.DrawLine( new Vector3( cx+r+1f, 0f, cz-r ), new Vector3( cx+r, 0f, cz-r ), new Color(1f,0f,0f,(fracZ)*fracX) );
			// right z
			Debug.DrawLine( new Vector3( cx+r, 0f, cz+r+1f ), new Vector3( cx+r, 0f, cz+r ), new Color(1f,0f,0f,fracZ*(1f-fracX)) );
			Debug.DrawLine( new Vector3( cx+r, 0f, cz-r-1f ), new Vector3( cx+r, 0f, cz-r ), new Color(1f,0f,0f,(1f-fracZ)*(1f-fracX)) );
			Debug.DrawLine( new Vector3( cx+r, 0f, cz-r ), new Vector3( cx+r, 0f, cz-r+1f ), new Color(1f,0f,0f,(1f-fracZ)*fracX) );
			Debug.DrawLine( new Vector3( cx+r, 0f, cz+r+1f ), new Vector3( cx+r, 0f, cz+r ), new Color(1f,0f,0f,fracZ*(1f-fracX)) );
			// left z
			Debug.DrawLine( new Vector3( cx-r, 0f, cz+r+1f ), new Vector3( cx-r, 0f, cz+r ), new Color(1f,0f,0f,fracZ*(fracX)) );
			Debug.DrawLine( new Vector3( cx-r, 0f, cz-r-1f ), new Vector3( cx-r, 0f, cz-r ), new Color(1f,0f,0f,(1f-fracZ)*(fracX)) );
			Debug.DrawLine( new Vector3( cx-r, 0f, cz+r+1f ), new Vector3( cx-r, 0f, cz+r ), new Color(1f,0f,0f,fracZ*(fracX)) );
			Debug.DrawLine( new Vector3( cx-r, 0f, cz-r ), new Vector3( cx-r, 0f, cz-r+1f ), new Color(1f,0f,0f,(fracZ)*(fracX)) );
		}
		*/
	}

	void DrawStructure(float alpha, float posX, float posZ )
	{
		for( float i = 1f; i < 10f; i++ )
		{
			//Debug.DrawLine( new Vector3( posX-i, 0f, posZ+i ), new Vector3( posX-(i-1f), 0f, posZ+i ), new Color(1f,0f,0f,alpha) );
			Debug.DrawLine( new Vector3( posX-i, 0f, posZ+i ), new Vector3( posX+i, 0f, posZ+i ), new Color(1f,1f,1f,alpha) );

			Debug.DrawLine( new Vector3( posX-i, 0f, posZ-i ), new Vector3( posX+i, 0f, posZ-i ), new Color(1f,1f,1f,alpha) );
			Debug.DrawLine( new Vector3( posX+i, 0f, posZ-i ), new Vector3( posX+i, 0f, posZ+i ), new Color(1f,1f,1f,alpha) );
			Debug.DrawLine( new Vector3( posX-i, 0f, posZ-i ), new Vector3( posX-i, 0f, posZ+i ), new Color(1f,1f,1f,alpha) );
		}
	}
}
