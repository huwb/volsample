using UnityEngine;
using System.Collections;

public class StructuredSampling3DTest : MonoBehaviour {

    /*
    v 0.000000 1.000000 0.000000
    v 0.723600 -0.447215 0.525720
    v -0.276385 -0.447215 0.850640
    v -0.894425 -0.447215 0.000000
    v -0.276385 -0.447215 -0.850640
    v 0.723600 -0.447215 -0.525720
    */
    Vector3[] dirs = new Vector3[] {
        new Vector3( 0.000000f,  1.000000f,  0.000000f),
        -new Vector3( 0.723600f, -0.447215f,  0.525720f),
        -new Vector3(-0.276385f, -0.447215f,  0.850640f),
        -new Vector3(-0.894425f, -0.447215f,  0.000000f),
        -new Vector3(-0.276385f, -0.447215f, -0.850640f),
        -new Vector3( 0.723600f, -0.447215f, -0.525720f),
    };
    Vector3[] alldirs = new Vector3[] {
        new Vector3( 0.000000f,  1.000000f,  0.000000f),
        new Vector3( 0.723600f, -0.447215f,  0.525720f),
        new Vector3(-0.276385f, -0.447215f,  0.850640f),
        new Vector3(-0.894425f, -0.447215f,  0.000000f),
        new Vector3(-0.276385f, -0.447215f, -0.850640f),
        new Vector3( 0.723600f, -0.447215f, -0.525720f),
        -new Vector3( 0.000000f,  1.000000f,  0.000000f),
        -new Vector3( 0.723600f, -0.447215f,  0.525720f),
        -new Vector3(-0.276385f, -0.447215f,  0.850640f),
        -new Vector3(-0.894425f, -0.447215f,  0.000000f),
        -new Vector3(-0.276385f, -0.447215f, -0.850640f),
        -new Vector3( 0.723600f, -0.447215f, -0.525720f),
    };

    Vector3 _rndDir;

    void Start()
    {
        _rndDir = Random.onUnitSphere;

        float ma = 10000f;

        for( int i = 0; i < dirs.Length; i++ )
        {
            for( int j = i+1; j < dirs.Length; j++ )
            {
                float a;

                a = Vector3.Angle( dirs[i], dirs[j] );
                Debug.Log( i + ", " + j + ": " + a );
                ma = Mathf.Min( ma, a );

                a = Vector3.Angle( dirs[i], -dirs[j] );
                Debug.Log( i + ", -" + j + ": " + a );
                ma = Mathf.Min( ma, a );

                a = Vector3.Angle( -dirs[i], -dirs[j] );
                Debug.Log( "-" + i + ", -" + j + ": " + a );
                ma = Mathf.Min( ma, a );

                a = Vector3.Angle( -dirs[i], dirs[j] );
                Debug.Log( "-" + i + ", " + j + ": " + a );
                ma = Mathf.Min( ma, a );
            }
        }

        Debug.Log( "Min angle: " + ma );
    }

    void Update ()
    {
        _rndDir = Random.onUnitSphere;

        for( int i = 0; i < alldirs.Length; i++ )
        {
            Debug.Log( i + ": " + Vector3.Dot( _rndDir, alldirs[i] ) );
        }

        int[] closestI = new int[] { 0, 1, 2 };
        
        for( int i = 3; i < alldirs.Length; i++ )
        {
            int minInd = 0;
            float minDp = Vector3.Dot( _rndDir, alldirs[closestI[minInd]] );
            for( int j = 1; j < 3; j++ )
            {
                float tdp = Vector3.Dot( _rndDir, alldirs[closestI[j]] );
                if( tdp < minDp )
                {
                    minInd = j;
                    minDp = tdp;
                }
            }

            if( Vector3.Dot( _rndDir, alldirs[i] ) > minDp )
            {
                closestI[minInd] = i;
            }
        }

        float totaldp = 0f;
        for( int i = 0; i < closestI.Length; i++ )
        {
            totaldp += Vector3.Dot( _rndDir, alldirs[closestI[i]] );
        }
        Debug.Log( "TDP: " + totaldp );

        for( int i = 0; i < alldirs.Length; i++ )
        {
            Color col = Color.white;
            for( int j = 0; j < 3; j++ )
            {
                if( closestI[j] == i )
                {
                    col = Color.red;
                    col *= Vector3.Dot( _rndDir, alldirs[closestI[j]] ) / totaldp;
                    //col.a = 1f;
                }
            }

            Debug.DrawRay( transform.position + alldirs[i], alldirs[i], col );
        }

        //float maxAngle = 63.435f;



        //for( int i = 0; i < dirs.Length; i++  )
        //{
        //    Color col;

        //    col = Vector3.Angle( dirs[i], _rndDir ) < maxAngle ? Color.red : Color.white;
        //    Debug.DrawRay( dirs[i] + transform.position, dirs[i], col );

        //    col = Vector3.Angle( -dirs[i], _rndDir ) < maxAngle ? Color.red : Color.white;
        //    Debug.DrawRay( -dirs[i] + transform.position, -dirs[i], col );
        //}

        Debug.DrawRay( transform.position + _rndDir, _rndDir, Color.green );

        ////if( _firstTime )
        //{
        //    for( int i = 0; i < dirs.Length; i++ )
        //    {
        //        float a0 = Vector3.Angle( _rndDir, dirs[i] );
        //        float a1 = Vector3.Angle( _rndDir, -dirs[i] );

        //        float a = Mathf.Min( a0, a1 );

        //        Debug.Log( i.ToString() + ": " + a );
        //    }

        //    _firstTime = false;
        //}
    }
}
