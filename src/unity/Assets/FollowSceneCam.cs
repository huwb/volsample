using UnityEngine;

[ExecuteInEditMode]
public class FollowSceneCam : MonoBehaviour
{
    public bool _apply = false;
	
    bool LiveUpdating {
        get {
            return
#if UNITY_EDITOR
                UnityEditor.EditorApplication.isPlaying && !UnityEditor.EditorApplication.isPaused
#else
            true
#endif
                ;
        }
    }

	void LateUpdate()
    {
        if( LiveUpdating )
        {
            Apply();
        }
    }

    void OnDrawGizmos()
    {
        if( !LiveUpdating )
        {
            Apply();
        }
    }

    void Apply()
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
