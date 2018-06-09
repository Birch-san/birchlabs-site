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

<img width="436" height="362" src="{{ relative }}demo.png">

juicysfplugin is an AU/VST/VST3 audio plugin written in [JUCE framework](https://juce.com/).  
You can run it inside a plugin host (GarageBand, FL Studio, Sibelius, …), or it can self-host as a .app.

It's my first C++ program.

I'd like to say I made a synthesizer, but really [fluidsynth](http://www.fluidsynth.org/) does the synthesis for me.  
So, this is a story of software integration.

<figure>
  <audio controls preload="none">
    <source src="{{ relative }}TheBox_compressed_less.mp3" type="audio/mpeg">
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

## Integrating fluidsynth

I needed to dynamically link the fluidsynth library into my executable. Basic linker flags suffice:  
`-lfluidsynth -L/usr/local/lib` (that's the brew libraries directory).

But this creates a non-portable release.

<!-- nominally 800x400 -->
<object
width="800"
height="400"
data="{{ relative }}unbundled.svg"
type="image/svg+xml"></object>

Open juicysfplugin.app on another computer, and you get [this error](https://stackoverflow.com/a/19230699/5257399):

```
dyld: Library not loaded: /usr/local/lib/libfluidsynth.1.7.2.dylib
  Referenced from: ~/juicysfplugin.app/Contents/MacOS/juicysfplugin
  Reason: image not found
```

The fluidsynth library doesn't exist on their system. They never brew-installed it.

Rather than tell users to prepare their environment, let's _bundle_ the library into our .app.  
We copy libfluidsynth into `juicysfplugin.app/Contents/Frameworks` (using a shell script, or XCode's "copy files" build phase).

We need to relink our binary to use the bundled libfluidsynth.

### Relinking

Where does `juicysfplugin.app/Contents/MacOS/juicysfplugin` currently look for libfluidsynth?

```bash
otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  /usr/local/lib/libfluidsynth.1.7.2.dylib (compatibility version 1.0.0, current version 1.7.2)
  …
```

Let's rewrite that link, to search relative to `@loader_path`:

```bash
install_name_tool -change \
/usr/local/lib/libfluidsynth.1.7.2.dylib         `# rewrite this link` \
@loader_path/../Frameworks/libfluidsynth.1.7.2.dylib `# to this` \
~/juicysfplugin.app/Contents/MacOS/juicysfplugin `# in this object file`

# @loader_path points to our binary's location:
# juicysfplugin.app/Contents/MacOS/juicysfplugin
```

<object
width="800"
height="400"
data="{{ relative }}bundled1.svg"
type="image/svg+xml"></object>

We read the object file again to verify that we successfully relinked:

```bash
otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  @loader_path/../Frameworks/libfluidsynth.1.7.2.dylib (compatibility version 1.0.0, current version 1.7.2)
  …
```

### It goes deeper

We run our relinked .app on another computer. The first error is gone, but we're onto a new error:

```
dyld: Library not loaded: /usr/local/opt/glib/lib/libglib-2.0.0.dylib
  Referenced from: ~/juicysfplugin.app/Contents/Frameworks/libfluidsynth.1.7.2.dylib
  Reason: image not found
```

fluidsynth needs glib. glib doesn't exist on their system. They never brew-installed it.

We need to find all of fluidsynth's dependencies, copy them into our .app, and relink fluidsynth.  
We do this recursively.

Tedious.

I automated it. So did openage and KeePassXC.