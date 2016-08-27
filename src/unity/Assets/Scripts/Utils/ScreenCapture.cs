using UnityEngine;

public class ScreenCapture : MonoBehaviour
{
	public bool on = false;

    public int _maxScreenshots = -1;

	int screenShotNumber = 0;

    int _lastCapturedFrameCount = -1;

    string _folderName = "C:/Unity-Capture";

    void Start()
    {
        if( !System.IO.Directory.Exists( _folderName ) )
        {
            System.IO.Directory.CreateDirectory( _folderName );
            Debug.Log( "Created screenshot folder: " + _folderName );
        }
    }

	void OnPostRender()
	{
		if( on && Time.frameCount != _lastCapturedFrameCount )
		{
            _lastCapturedFrameCount = Time.frameCount;

            string screenName = _folderName + "/Screenshot" + screenShotNumber.ToString( "D5" ) + ".png";
            Application.CaptureScreenshot( screenName );
            Debug.Log( "Saved screenshot: " + screenName );

			++screenShotNumber;

            if( screenShotNumber == _maxScreenshots )
            {
                on = false;
            }
		}
	}
}
