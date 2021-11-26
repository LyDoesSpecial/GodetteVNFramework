# GodetteVN, A Visual Novel Framework for Godot Users

## Refactoring almost done. Getting ready to push out more related content.

## Goal and Vision: Bringing the theatrical experience into your story, right in the Godot Engine.

### Keypoints: (subject to change...)

1. Actor Editor: any 2d customization doable in Godot should be applicable to actors. (In progress...)
2. Script Editor: script should be similar to that of a play in the traditional setting, but formatted in a more programmatic language. (In progress...)
3. Rich template libraries for "commonly" used components, e.g. timed choices, parallax, weather, etc. (In progress...) 
4. Key components should be callable programmatically and should be functional without others. (Not started yet...)
5. Strong unit testing support, instantenous display for the event in your script. (Not started yet...)


-------------------------------------------------------------------------------------------------------------

## Every journey starts with a single step.

For basic dialog for RPG games, then [Dialogic](https://github.com/coppolaemilio/dialogic) might be a better addon than this, 
because this framework is solely focused on the making of Visual/Graphic Novel. Renpy is also a good 
alternative if your game doesn't require features that are easier to make in Godot. Programming knowledge is highly recommended to
make full use of the framework.

In the folder res://GodetteVN/ , you can find sample projects to run.

Before you run your own sample scene, make sure your character is created via the 
actor editor and saved as a scene. Moreover, you have to register your characters
in characterManager.gd (this file can be found in the singleton folder.) This may change in the future.

There are 3 core components in this framework.
1. An actor editor (WIP, mostly stable for written functions) 
2. A script editor (WIP, mostly stable for written functions)
3. A core dialog system (basically a json interpreter, mostly stable)  

Transition system is integrated from eh-jogos's project. You can find it [here](https://github.com/eh-jogos/eh_Transitions)

Shaders are taken from Godot Asset Library, [here](https://godotengine.org/asset-library/asset/122) and
 [here](https://godotshaders.com/shader/glitch-effect-shader/) @arlez80. Not all shaders are implemented yet.

Video Showcases (Possibly outdated):

[Parallax and Sprite Sheet Animation](https://www.youtube.com/watch?v=sG7tDFsk4HE)

[General Gameplay](https://www.youtube.com/watch?v=uODpTQz6Vu0&t=43s)

[Floating Text](https://www.youtube.com/watch?v=2KSO_qQ8pqw)

Other examples like timed choice, investigation scene, can be found in the folder /GodetteVN/

Projects done with this template:

[My O2A2 entry](https://tqqq.itch.io/o2a2-elegy-of-a-songbird)
[Remake of the above](https://youtu.be/BArw1Qwrz10)

More in the making ~

------------------------------------------------------------------------------------------------------------------------------

### Known issues:

1. Mac export will be considered corrupted. Most likely you will need to do the command line trick to run it.


### Documentations

Documentation will be in the VNScript editor in the framework.


------------------------------------------------------------------------------------------------------------------------------

### Future Plans:

1. Side Picture correspondence. (Already has everything needed. Just need to create an interface.)

2. Simplify the whole process.

3. More builtin templates. (Like a customizable phone screen template, liteDialogNode, etc.)

------------------------------------------------------------------------------------------------------------------------------

### You can contact me on Discord for any questions.

Discord: T.Q#8863