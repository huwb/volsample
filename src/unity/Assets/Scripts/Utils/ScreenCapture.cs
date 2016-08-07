using UnityEngine;

public class ScreenCapture : MonoBehaviour
{
	public bool on = false;

	int screenShotNumber = 0;

	void OnPostRender()
	{
		if (on)
		{
			Application.CaptureScreenshot ("C:/Unity-Capture/Screenshot" + screenShotNumber.ToString ("D3") + ".png");
			++screenShotNumber;
		}
	}
}
