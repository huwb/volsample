
# volsample

MIT-licensed volume rendering research framework.

![Teaser](https://raw.githubusercontent.com/huwb/volsample/master/img/teaser.jpg)  
Teaser video [here](https://raw.githubusercontent.com/huwb/volsample/master/img/volrender_800x450_30fps.mp4).

Shadertoy volume rendering demo: [Mt3GWs](https://www.shadertoy.com/view/Mt3GWs)  
Shadertoy sampling diagram: [ll3GWs](https://www.shadertoy.com/view/ll3GWs)

Contacts: Huw Bowles (@hdb1 , huw dot bowles at gmail dot com), Daniel Zimmermann (daniel dot zimmermann at studiogobo dot com), Beibei Wang (bebei dot wang at gmail dot com)

Retweet to support this work: https://twitter.com/hdb1/status/769615284672028672  


## Introduction

Volume rendering in real-time applications is expensive, and sample counts are typically low. When the camera is inside the volume, the volume samples typically move around with the camera which can cause severe aliasing. This repository provides a new, fast, efficient and simple algorithm for eliminating aliasing for this camera-in-volume case.

This repos started as the source code for the course titled *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, in the *Advances in Real-Time Rendering in Games* course at SIGGRAPH 2015 [1]. The full presentation PPT is available for download from the course page [here][ADVANCES2015]. While this is useful reading, the latest implementation takes a new approach which completely replaces most of the approaches introduced in the talk.

The latest approach, Structured Sampling, works by placing samples on a set of world-space planes, constraining their motion and eliminating noticeable aliasing. A "flatland" version of this approach is implemented  on Shadertoy:

Shadertoy volume rendering demo: [Mt3GWs](https://www.shadertoy.com/view/Mt3GWs)  
Shadertoy sampling diagram: [ll3GWs](https://www.shadertoy.com/view/ll3GWs)


## Running

This is implemented as a Unity 5 project (last run on 5.6) and should "just work" without requiring any set up steps. It should be very easily ported to other Unity versions as well.

The main scene is *main.unity*. The cloud render should already work in the editor. Press play and the Animator component on the camera will play our test animation if it is enabled.

Two volume samplers are supported, selectable from the on screen GUI in Play mode. The fixed Z sampler is standard raymarching and is defined in *FixedZVolumeSampling.shader*. The new structured sampling technique is defined in *StructuredVolumeSampling.shader*.

The volume that is rendered depends on which scene shader is included in these two shaders. The default scene is *Scenes/SceneClouds.cginc* which corresponds to the screenshot above.


## Algorithm

The latest approach, Structured Sampling, works by placing samples on a set of world-space planes, constraining their motion and eliminating noticeable aliasing. A "flatland" version of this approach is implemented  on Shadertoy:

Shadertoy volume rendering demo: [Mt3GWs](https://www.shadertoy.com/view/Mt3GWs)  
Shadertoy sampling diagram: [ll3GWs](https://www.shadertoy.com/view/ll3GWs)

In the Shadertoys the planes are shown as lines (rendered from top down). For the non-flatland full 3D case we need planes that cover the full hemisphere of possible ray directions around the viewer. We choose planes parallel to the faces of a dodecahedron which has a nice distribution of faces. Too few planes would make perspective distortion visible - the planar shape becomes visible. Too many planes would lead to more data and larger blend regions between planes (more info below).

We generate a dodecahedron at run time around the camera, and rasterize it to seed the volume render. Each ray places its samples on the intersection of the ray and the set of equidistributed world space planes that are parallel to the dodecahedron face. We bevel the dodecahedron slightly, and the bevelled regions are where blending is required to blend from one plane to another. The corners of the dodecahedron are the intersections of 3 planes and require three rays to be blended. This is 3 times the rendering expense (although we march the rays in parallel and the cost is hopefully amortised by coherent texture samples). We use small bevels to minimize these expensive cases, in our tests less than 14% of pixels required raymarching against 2 planes, and less than 1% required raymarching against all 3.

For understanding it may help to enable the define *DEBUG_BEVEL* and play with the Bevel amount on the Platonic Solid Blend script. Doing a GPU trace capture in unity can also be helpful to see the dodecahedron.

We hope to publish a full description of this technique soon. Stay tuned!


## Bugs and improvement directions

* The adaptive sampling method published [here][ADVANCES2015] should be compatible with the new approach and could be reinstated.


## References

[ADVANCES2015]: http://advances.realtimerendering.com/s2015/index.html "Advances in Real-Time Rendering - SIGGRAPH 2015"

[1] Bowles H. and Zimmermann D., *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, Advances in Real-Time Rendering in Games course, SIGGRAPH 2015. [Course page][ADVANCES2015].
