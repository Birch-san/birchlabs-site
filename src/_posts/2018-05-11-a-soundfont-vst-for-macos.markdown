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

# C++ is hard

I assumed I'd be okay. I had some grounding in C, and hoped also that my experiences in higher-level languages would count for something.

Reality hit, though.

## It's not like C

Pointer arithmetic mostly disappears, since containers know the length of strings and vectors, and since iterators hide some details.

Moreover, C++ replaces a lot of pointer use-cases with _references_ — which have a more constrained semantic.

C++ is object-oriented. No more need for malloc; declare some class members, and the constructor will allocate memory for you.

## It's not like Java

C++ has no formal "interface". But you get a similar effect using multiple inheritance and dynamic binding. Caveats: interface-like classes need a virtual destructor, and derived classes must re-declare any methods they intend to override.

## New responsibilities

In C++, you are responsible for ownership of memory. You need to think about who will destroy an object when it's no longer needed.

There's a maxim to help you keep on top of this: SBRM ([Scope-Bound Resource Management](https://stackoverflow.com/questions/2321511/what-is-meant-by-resource-acquisition-is-initialization-raii)). Rely on the fact that C++ will invoke the destructor of any object which goes out-of-scope. Ensure that your classes release all their resources during destruction, and at no other time.

If you wish to transfer memory out of the scope in which it was created — for example, returning a heap-allocated object from a factory method — you need a plan to ensure that said object gets destroyed when it leaves its _new_ scope. One approach here is to use the standard library's [smart pointers](https://stackoverflow.com/questions/395123/raii-and-smart-pointers-in-c).

Passing objects around requires some awareness, since you risk accidentally incurring unnecessary copy operations. In [special cases](https://en.wikipedia.org/wiki/Copy_elision#Return_value_optimization), the compiler may save you a copy.

## Wacky syntax