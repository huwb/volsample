using UnityEngine;

[ExecuteInEditMode]
public class FollowSceneCam : MonoBehaviour
{
    public bool _apply = false;
	
	void OnDrawGizmos()
    {
        if( _apply )
        {
            Camera sceneViewCam = Camera.current;
            if( sceneViewCam != null )
            {
                transform.position = sceneViewCam.transform.position;
                transform.rotation = sceneViewCam.transform.rotation;
                //transform.localScale = sceneViewCam.transform.localScale;
            }
        }
    }
}
