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

I went to the FL Studio forums to petition that a soundfont plugin be written for macOS. I received encouragement from a fellow user:

> You know how to code? […] Well enough to know both what's easy and rewarding? If so, then consider [making it yourself].

I have now finished.

[juicysfplugin](https://github.com/Birch-san/juicysfplugin) - a soundfont VST for macOS

<img width="436" height="362" src="{{ "/assets/posts/2018-05-11-a-soundfont-vst-for-macos/demo.png" | relative_url }}">

juicysfplugin is an AU/VST/VST3 audio plugin written in [JUCE framework](https://juce.com/).  
You can run it inside a plugin host (GarageBand, FL Studio, Sibelius, …), or it can self-host as a .app.

It's my first C++ program.

I did not need to write a _synthesizer_ — I was able to delegate the backend to [fluidsynth](http://www.fluidsynth.org/).  
As such, this was not an audio programming challenge. Instead it was a software integration challenge.

Findings:

- C++ is hard
- Linking binaries is hard (on macOS)

<figure>
  <video width="583" height="285" controls>
    <!-- https://en.wikipedia.org/wiki/HTML5_video -->
    <!-- brew install MP4Box -->
    <!-- https://stackoverflow.com/a/48991053/5257399 -->
    <!-- ffmpeg -i trimmed.mov -vcodec copy -acodec copy trimmed.mp4 -->
    <!-- ffmpeg -i trimmed.mov -c:v libvpx -crf 10 -b:v 1M -c:a libvorbis trimmed.webm -->
    <!-- I've put webm first solely to save bandwidth in this case. ordinarily I'd prefer to use webm as the _fallback_. -->
    <source src="{{ "/assets/posts/2018-05-11-a-soundfont-vst-for-macos/trimmed.webm" | relative_url }}" type='video/webm; codecs="vp8.0, vorbis"'>
    <source src="{{ "/assets/posts/2018-05-11-a-soundfont-vst-for-macos/trimmed.mp4" | relative_url }}" type='video/mp4; codecs="avc1.4D0020,mp4a.40.2"'>
  </video>
  <figcaption>juicysfplugin hosted in FL Studio</figcaption>
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

