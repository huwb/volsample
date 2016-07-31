using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class L0_Isolines : MonoBehaviour
{
	public bool lockLines = false;
	public bool diagOnly = true;

	float mposX, mposZ;

	void Start()
	{
		float posX = transform.position.x;
		float fracX = Mathf.Repeat( posX, 1f );
		posX -= fracX;
		
		float posZ = transform.position.z;
		float fracZ = Mathf.Repeat( posZ, 1f );
		posZ -= fracZ;
	}

	void computePosition2()
	{
		float posX = transform.position.x;
		float fracX = Mathf.Repeat( posX, 1f );
		posX -= fracX;
		
		float posZ = transform.position.z;
		float fracZ = Mathf.Repeat( posZ, 1f );
		posZ -= fracZ;

		// if corners not visible, just move
		if( Mathf.Max( Mathf.Abs(transform.forward.x), Mathf.Abs(transform.forward.z) ) > 0.95f )
		{
			mposX = posX;
			mposZ = posZ;
		}
		else
		{
			Vector3 moveDir = new Vector3( Mathf.Sign( transform.forward.x ), 0f, Mathf.Sign( transform.forward.z ) );

			Vector3 curPos = new Vector3( mposX, 0f, mposZ );
			Vector3 desPos = new Vector3(  posX, 0f,  posZ );

			float dot = Vector3.Dot( desPos - curPos, moveDir.normalized );
			if( Mathf.Abs(dot) > 1f/Mathf.Sqrt(2f) )
			{
				mposX += moveDir.x * Mathf.Sign( dot );
				mposZ += moveDir.z * Mathf.Sign( dot );
			}
		}
	}

	float weightKernel( float x, float z )
	{
		return 1.0f - Mathf.Max( Mathf.Abs(x), Mathf.Abs(z) );
	}

	void Update()
	{
		if( !lockLines )
			computePosition2();

		//DrawStructure( 1f, mposX, mposZ );

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
		for( float i = 1f; i < 20f; i++ )
		{
			//Debug.DrawLine( new Vector3( posX-i, 0f, posZ+i ), new Vector3( posX-(i-1f), 0f, posZ+i ), new Color(1f,0f,0f,alpha) );
			Debug.DrawLine( new Vector3( posX-i, 0f, posZ+i ), new Vector3( posX+i, 0f, posZ+i ), new Color(1f,1f,1f,alpha) );

			Debug.DrawLine( new Vector3( posX-i, 0f, posZ-i ), new Vector3( posX+i, 0f, posZ-i ), new Color(1f,1f,1f,alpha) );
			Debug.DrawLine( new Vector3( posX+i, 0f, posZ-i ), new Vector3( posX+i, 0f, posZ+i ), new Color(1f,1f,1f,alpha) );
			Debug.DrawLine( new Vector3( posX-i, 0f, posZ-i ), new Vector3( posX-i, 0f, posZ+i ), new Color(1f,1f,1f,alpha) );
		}
	}
}
