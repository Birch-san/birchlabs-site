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

<img src="{{ "/assets/posts/2018-05-11-a-soundfont-vst-for-macos/demo.png" | relative_url }}">

<figure>
  <video width="583" controls>
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

juicysfplugin is an AU/VST/VST3 audio plugin written in [JUCE framework](https://juce.com/).  
You can run it inside a plugin host (GarageBand, FL Studio, Sibelius, …), or it can self-host as a .app.

It's my first C++ program.

I did not need to write a _synthesizer_ — I was able to delegate the backend to [fluidsynth](http://www.fluidsynth.org/).  
As such, this was not an audio programming challenge. Instead it was a software integration challenge.

Findings:

- C++ is hard
- Linking binaries is hard (on macOS)


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

## C++ is hard

I assumed I'd be okay. I had some grounding in C, and hoped also that my experiences in higher-level languages would count for something.

Reality hit, though.

### It's not like C

Pointer arithmetic mostly disappears, since containers know the length of strings and vectors, and since iterators hide some details.

Moreover, C++ replaces a lot of pointer use-cases with _references_ — which have a more constrained semantic.

C++ is object-oriented. No more need for malloc; declare some class members, and the constructor will allocate memory for you.

C++'s complexity partially [stems from](https://youtu.be/RT46MpK39rQ?t=29m51s) its goal of maintaining compatibility with C.

### It's not like Java

C++ has no formal "interface". But you get a similar effect using multiple inheritance and dynamic binding. Caveats: interface-like classes need a virtual destructor, and derived classes must re-declare any methods they intend to override.

### It's your memory now

In C++, you are responsible for ownership of memory. You need to think about who will destroy an object when it's no longer needed.

There's a maxim to help you keep on top of this: SBRM ([Scope-Bound Resource Management](https://stackoverflow.com/questions/2321511/what-is-meant-by-resource-acquisition-is-initialization-raii)). Rely on the fact that C++ will invoke the destructor of any object which goes out-of-scope. Ensure that your classes release all their resources during destruction, and at no other time.

If you wish to transfer memory out of the scope in which it was created — for example, returning a heap-allocated object from a factory method — you need a plan to ensure that said object gets destroyed when it leaves its _new_ scope. One approach here is to use the standard library's [smart pointers](https://stackoverflow.com/questions/395123/raii-and-smart-pointers-in-c).

Passing objects around requires some awareness, since you risk accidentally incurring unnecessary copy operations. In [special cases](https://en.wikipedia.org/wiki/Copy_elision#Return_value_optimization), the compiler may save you a copy.

### It's a big language

In languages like Java 7 or ES5, I feel reasonably comfortable saying, "I've used most of the language's features". I would also believe a fellow professional if they told me the same. But C++ is _vast_.

C++ has many features, and you may not use everything. For example, [proxy classes](https://stackoverflow.com/questions/994488/what-is-proxy-class-in-c#994925) and [expression templates](https://en.wikipedia.org/wiki/Expression_templates) may be more interesting to library developers, as they hide complexity from callers. [Variants](https://bitbashing.io/std-visit.html) are interesting if you're building an unmarshaller. [SFINAE](http://en.cppreference.com/w/cpp/language/sfinae) is interesting if you're [building a marshaller](https://jguegant.github.io/blogs/tech/sfinae-introduction.html) or a language runtime.

I was exposed to ideas I hadn't thought of before. Like overloading on _the run-time value_ of arguments ([SFINAE](http://en.cppreference.com/w/cpp/language/sfinae), Substitution Failure Is Not An Error):

```cpp
template <int I> void div(char(*)[I % 2 == 0] = 0) {
    // this overload is selected when I is even
}
template <int I> void div(char(*)[I % 2 == 1] = 0) {
    // this overload is selected when I is odd
}
```

The most arcane thing I've seen so far involves variadic templates, variadic `using` declarations (C++17), and user-defined template deduction (C++17, Clang 5):

```cpp
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
```

It creates a class whose constructor accepts a list of [_function objects_](https://stackoverflow.com/questions/356950/c-functors-and-their-uses), and copies each of their declared `operator()` overloads. Useful for [making visitors](https://bitbashing.io/std-visit.html) (C++17). Explained in detail [here](https://stackoverflow.com/questions/46604950/what-does-operator-mean-in-code-of-c).

### Lots of gotchas

Many things happen implicitly. Narrowing conversions, 

#### Wacky syntax



###