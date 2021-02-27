
# Structured Volume Sampling

MIT-licensed implementation of Structured Volume Sampling technique, along with simple framework for comparing other techniques.

![Teaser](https://raw.githubusercontent.com/huwb/volsample/master/img/teaser.jpg)  
Teaser video [here](https://raw.githubusercontent.com/huwb/volsample/master/img/volrender_800x450_30fps.mp4).

**Draft slides describing latest approach [here](https://raw.githubusercontent.com/huwb/volsample/master/doc/volsample.pptx).**

Shadertoy volume rendering demo: [Mt3GWs](https://www.shadertoy.com/view/Mt3GWs)  
Shadertoy sampling diagram: [ll3GWs](https://www.shadertoy.com/view/ll3GWs)

Impressive application of this technique by Felix Westin: https://twitter.com/FewesW , in particular https://twitter.com/FewesW/status/1364935000790102019

Alternative implementation: https://github.com/gokselgoktas/structured-volume-sampling

Contacts: Huw Bowles (@hdb1 , huw dot bowles at gmail dot com), Daniel Zimmermann (daniel dot zimmermann at studiogobo dot com), Beibei Wang (bebei dot wang at gmail dot com)

Retweet to support this work: https://twitter.com/hdb1/status/769615284672028672  

<br/>

## Introduction

Volume rendering in real-time applications is expensive, and sample counts are typically low. When the camera is inside the volume, the volume samples typically move around with the camera which can cause severe aliasing. This repository provides a new, fast, efficient and simple algorithm for eliminating aliasing for this camera-in-volume case.

This repos started as the source code for the course titled *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, in the *Advances in Real-Time Rendering in Games* course at SIGGRAPH 2015 [1]. The full presentation PPT is available for download from the course page [here][ADVANCES2015]. While this is useful reading, the latest implementation takes a new approach which completely replaces most of the approaches introduced in the talk.

The latest approach, *Structured Volume Sampling*, works differently. See the Algorithm section below.

<br/>

## Running

This is implemented as a Unity 5 project (last run on 5.6) and should "just work" without requiring any set up steps. It should be very easily ported to other Unity versions as well.

Find the current test scenes in the *Scenes/* folder. A few volume sampling schemes are implemented for comparison and can be selected via the on screen GUI.

All volume sampling methods and volumetric scenes are implemented into *VolumeRender.shader*, as shader features. This is a quick and dirty way to associate shader code with unity scenes, and at the same time support different volume sampling approaches, without requiring a ton of shader code duplication.

<br/>

## Algorithm

![Overview](https://raw.githubusercontent.com/huwb/volsample/master/img/overview.png)  

**Draft slides describing latest approach [here](https://raw.githubusercontent.com/huwb/volsample/master/doc/volsample.pptx).**

For further understanding it may help to enable the define *DEBUG_BEVEL* and play with the Bevel amount on the Platonic Solid Blend script. Doing a GPU trace capture in unity can also be helpful to see the dodecahedron.

We hope to publish a full description of this technique soon. Stay tuned!

<br/>

## Bugs and improvement directions

* The adaptive sampling method published [here][ADVANCES2015] should be compatible with the new approach and could be reinstated.

<br/>

## References

[ADVANCES2015]: http://advances.realtimerendering.com/s2015/index.html "Advances in Real-Time Rendering - SIGGRAPH 2015"

[1] Bowles H. and Zimmermann D., *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, Advances in Real-Time Rendering in Games course, SIGGRAPH 2015. [Course page][ADVANCES2015].
