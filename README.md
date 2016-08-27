
# volsample

Research on sampling methods for real-time volume rendering.

![Teaser](https://raw.githubusercontent.com/huwb/volsample/master/img/teaser.jpg)

Shadertoy volume rendering demo: [Mt3GWs](https://www.shadertoy.com/view/Mt3GWs)  
Shadertoy sampling diagram: [ll3GWs](https://www.shadertoy.com/view/ll3GWs)

Contacts: Huw Bowles (huw dot bowles at gmail dot com), Daniel Zimmermann (daniel dot zimmermann at studiogobo dot com), Beibei Wang (beibei dot wang at gmail dot com)


## Intro

Volume rendering in real-time applications is expensive, and sample counts are typically low. When the camera is inside the volume, the volume samples typically move around with the camera which can cause severe aliasing. This repository provides a new, fast, efficient and simple algorithm for eliminating aliasing for this camera-in-volume case.

This repos started as the source code for the course titled *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, in the *Advances in Real-Time Rendering in Games* course at SIGGRAPH 2015 [1]. The full presentation PPT is available for download from the course page [here][ADVANCES2015]. While this is useful reading, the latest implementation takes a new approach which completely replaces most of the approaches introduced in the talk.

The latest approach, Structured Sampling, works by placing samples on grid lines, constraining their motion to one dimension which is densely sampled by the set of pixel rays and robust against aliasing. Right now We are in the process of working out the details, extending the method to 3D, and writing up an article. 

Shadertoy volume rendering demo: [Mt3GWs](https://www.shadertoy.com/view/Mt3GWs)  
Shadertoy sampling diagram: [ll3GWs](https://www.shadertoy.com/view/ll3GWs)


## Running

This is implemented as a Unity 5 project (last run on 5.3.5) and should "just work" without requiring any set up steps.

The main scene is *CloudsStructured.unity*. The cloud render should already work in the editor. Press play and the Animator component on the camera will play our test animation if it is enabled.

There is also a ShaderToy running here: https://www.shadertoy.com/view/Mt3GWs


## Algorithm

Article coming soon.

In the meantime there is a diagram shader here: https://www.shadertoy.com/view/ll3GWs


## Troubleshooting

You may run into the following:

* If you see just the standard sky box render in the camera view, re-enable the *CloudsStructured* script on the camera. if it auto disables itself when you enable it, it is likely because the shader is not building. look in the console log for shader build errors. if you don't see any you may have already cleared them - perhaps try touching the shader file or reopening Unity.


## Bugs and improvement directions

* The render breaks down when the camera is raised above the clouds etc. It would be valuable to polish this and make it work for all camera angles.
Or to add another scene where the volume completely envelops the camera.



## References

[ADVANCES2015]: http://advances.realtimerendering.com/s2015/index.html "Advances in Real-Time Rendering - SIGGRAPH 2015"

[1] Bowles H. and Zimmermann D., *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, Advances in Real-Time Rendering in Games course, SIGGRAPH 2015. [Course page][ADVANCES2015].
