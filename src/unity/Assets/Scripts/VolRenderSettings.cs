using UnityEngine;

/// <summary>
/// Render settings singleton.
/// </summary>
[ExecuteInEditMode]
public class VolRenderSettings : MonoBehaviour
{
    [Tooltip( "Slow down unity time" )]
    [Range( 0.0001f, 4f )]
    public float timeScale = 1.0f;

	void Update()
	{
		Time.timeScale = Mathf.Max(0.00001f, timeScale);
	}

    static VolRenderSettings m_inst; public static VolRenderSettings instance { get { return m_inst ? m_inst : (m_inst = FindObjectOfType<VolRenderSettings>()); } }

}
