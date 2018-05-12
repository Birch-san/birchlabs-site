---
layout: post
title:  "A soundfont VST for macOS"
date:   2018-05-11 22:00:00 -0000
categories: blog Alex juicysfplugin synth cpp
syntax_highlight: true
author: Alex Birch
---

Soundfonts are great for making music quickly. Violins, drums, game beeps. You can explore their many instruments for ideas. Good sound, no learning or configuration required.

I enjoyed soundfonts on FL Studio Windows. Mac version coming soon. Brilliant!

No soundfont plugin.

I went to the FL Studio forums. There was an argument, started by me. A gauntlet was thrown down:

> You know how to code? […] Well enough to know both what's easy and rewarding? If so, then consider [making it yourself].

I have now finished.

[juicysfplugin](https://github.com/Birch-san/juicysfplugin) - a soundfont VST for macOS

<img src="{{ "/assets/experiments/Juicysfplugin.png" | relative_url }}">

This was my first C++ program.

I did not need to write a _synthesizer_ — I was able to delegate the backend to [fluidsynth](http://www.fluidsynth.org/).  
As such, this was not an audio programming challenge. Instead it was a software integration challenge.

Findings:

- C++ is hard
- Linking binaries is hard
- Linking binaries **on Mac** is hard
- Async programming is hard in an unfamiliar language
- UI programming is hard when you have to manage memory
- JUCE is a nice application framework
- Licenses create a lot of work even if you're already GPL
- Standard library has some neat stuff
- C++ is pretty fun
- C++ tooling is not as great as I'd expected
- Applications can be really small if you don't use Electron

A brief overview of how juicysfplugin works:

