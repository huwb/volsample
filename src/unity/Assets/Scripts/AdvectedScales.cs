using UnityEngine;
using System.Collections;

public class AdvectedScales : MonoBehaviour
{
	[Tooltip("Used to differentiate/sort the two advection computations")]
	public int m_radiusIndex = 0;
	
	[Tooltip("The radius of this sample slice. Advection is performed at this radius")]
	public float m_radius = 10.0f;

	public virtual float MiddleScaleValue
	{
		get { return m_radius; }
	}
}
