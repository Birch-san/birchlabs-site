---
layout: post
title:  "A soundfont VST for macOS"
date:   2018-05-11 22:00:00 -0000
categories: blog Alex juicysfplugin synth cpp
syntax_highlight: true
author: Alex Birch
---

Soundfonts are great for making music quickly. With no learning or configuration, you can play samples from a variety of instruments and not-instruments.

I enjoyed soundfonts on FL Studio Windows. Mac version coming soon. Brilliant!

No soundfont plugin.

I went to the FL Studio forums. There was an argument, started by me. A user encouraged me:

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

In this article, I'll expand on the interesting parts of this project.

# How juicysfplugin works

We have a responsibility to output (for example) 44.1 thousand samples of audio every second.
We promise to deliver this in 512-sample blocks. To keep up with the demand, we have to render a block every 11.6ms. This also means we run at a latency of 11.6ms behind real-time.

Additionally, we're given a buffer of MIDI messages each time this happens. In order:

1. Audio plugin host invokes our `processBlock()` callback
  - input param: MidiBuffer
  - output param: AudioBuffer
  - must return within ~11.6ms
2. We send the MidiBuffer to the JUCE Synthesiser (not fluidsynth)
  - informs each note's "voice" of state changes
  - our voice implementation passes `startNote()`, `stopNote()` to fluidsynth
3. We ask fluidsynth to output 512 samples of audio into AudioBuffer
  - fluidsynth has its own clock, so it knows this block starts where the previous one ended
  - fluidsynth has its own sample rate, which we keep updated

Summary:  
MIDI messages go in. We render the MIDI messages through the fluidsynth synthesiser. Then we output audio.

