---
layout: post
title:  "A soundfont VST for macOS"
date:   2018-05-11 22:00:00 -0000
categories: blog Alex juicysfplugin synth cpp
syntax_highlight: true
author: Alex Birch
---

Soundfonts are great for making music quickly. With no learning or configuration, you can play samples from a variety of instruments and not-instruments.

I wanted to make soundfont music on FL Studio Mac.

There was a nice soundfont plugin for FL Studio Windows, but the (third-party) source code was lost, and would not be ported.  

So, I made my own plugin.

[juicysfplugin](https://github.com/Birch-san/juicysfplugin) - a soundfont VST for macOS

<img width="436" height="362" src="{{ "/assets/posts/2018-05-11-a-soundfont-vst-for-macos/demo.png" | relative_url }}">

juicysfplugin is an AU/VST/VST3 audio plugin written in [JUCE framework](https://juce.com/).  
You can run it inside a plugin host (GarageBand, FL Studio, Sibelius, …), or it can self-host as a .app.

It's my first C++ program.

I'd like to say I made a synthesizer, but really [fluidsynth](http://www.fluidsynth.org/) does the synthesis for me.  
So, this is a story of software integration.

<figure>
  <audio controls preload="none">
    <source src="{{ "/assets/posts/2018-05-11-a-soundfont-vst-for-macos/TheBox_compressed_less.mp3" | relative_url }}" type="audio/mpeg">
  </audio>
  <figcaption>demo track (with Soundgoodizer compressor)</figcaption>
</figure>

## How juicysfplugin works

JUCE have [good docs](https://docs.juce.com/master/tutorial_create_projucer_basic_plugin.html) for making audio plugins like this one.

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

