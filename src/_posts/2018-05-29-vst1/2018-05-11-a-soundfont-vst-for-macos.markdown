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
  <figcaption class="centered">demo track (with Soundgoodizer compressor)</figcaption>
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

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>dyld: <span class="ne">Library not loaded:</span> <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span>
  Referenced from: ~/juicysfplugin.app/Contents/MacOS/juicysfplugin
  Reason: image not found
</code></pre>
  </div>
</div>

The fluidsynth library doesn't exist on their system. They never brew-installed it.

Rather than tell users to prepare their environment, let's _bundle_ the library into our .app.  
We copy libfluidsynth into `juicysfplugin.app/Contents/Frameworks` (using a shell script, or XCode's "copy files" build phase).

**We need to relink our binary to use the bundled libfluidsynth.**

### Relinking

Where does `juicysfplugin.app/Contents/MacOS/juicysfplugin` currently look for libfluidsynth?

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>

Let's rewrite that link, to search relative to `@loader_path`:

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>install_name_tool <span class="nt">-change</span> <span class="se">\</span>
<span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span>         <span class="sb">`</span><span class="c"># rewrite this link</span><span class="sb">` \</span>
<span class="nb">@loader_path/../Frameworks/</span><span class="k">libfluidsynth.1.7.2.dylib</span> <span class="sb">`</span><span class="c"># to this</span><span class="sb">` \</span>
~/juicysfplugin.app/Contents/MacOS/juicysfplugin     <span class="sb">`</span><span class="c"># in this obj file</span><span class="sb">`</span>

<span class="c"># @loader_path points to our binary's location:</span>
<span class="c"># juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
</code></pre>
  </div>
</div>

<object
width="800"
height="400"
data="{{ relative }}bundled1.svg"
type="image/svg+xml"></object>

We read the object file again to verify that we successfully relinked:

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  <span class="nb">@loader_path/../Frameworks/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>

### It goes deeper

We run our relinked .app on another computer. The first error is gone, but we're onto a new error:

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>dyld: <span class="ne">Library not loaded:</span> <span class="err">/usr/local/opt/glib/lib/</span><span class="k">libglib-2.0.0.dylib</span>
  Referenced from: ~/juicysfplugin.app/Contents/Frameworks/libfluidsynth.1.7.2.dylib
  Reason: image not found
</code></pre>
  </div>
</div>

fluidsynth needs glib. glib doesn't exist on their system. They never brew-installed it.

<object
width="800"
height="400"
data="{{ relative }}part_bundled.svg"
type="image/svg+xml"></object>

The bundle & relink dance must be done for all dependencies, _recursively_.

<object
width="800"
height="400"
data="{{ relative }}bundled_again.svg"
type="image/svg+xml"></object>

[I automated it](https://github.com/Birch-san/juicysfplugin/blob/74012df2ed8bb5423f3bcc76bff054ac02823596/Builds/MacOSX/relink-build-for-distribution.sh). I am [not the only one](https://github.com/essandess/matryoshka-name-tool).

 <!-- Others have wondered [the same problem](https://stackoverflow.com/questions/9263256/why-is-install-name-tool-and-otool-necessary-for-mach-o-libraries-in-mac-os-x). -->

The chain of brew dependencies can go pretty deep. For example, libsndfile (which adds support for [SF3 soundfonts](https://musescore.org/en/node/151611)) introduces this many links:

```
juicysfplugin
  libsndfile
    libFLAC
    libogg
    libvorbis
      libogg
    libvorbisenc
      libvorbis
      libogg
```

<!--
Full list:

juicysfplugin
  libgthread
    libglib…
  libglib
    libiconv
    libpcre
    libintl…
  libintl
    libiconv
  libsndfile
    libFLAC
    libogg
    libvorbis
      libogg
    libvorbisenc
      libvorbis…
      libogg
-->

### Don't mess up

When relinking a library with `install_name_tool [-change old new] file`, beware: you must match **exactly**.

To find the link matching `/usr/local/Cellar/glib/2.56.1/lib/libglib-2.0.0.dylib` and rewrite it…

- You cannot match on leaf name `libglib-2.0.0.dylib` or library name, `glib`.
- You cannot match on an equivalent symlink path `/usr/local/opt/glib/lib/libglib-2.0.0.dylib`

If your command matches nothing: there is no error message, and the exit code says success as usual.

If you are automating this in a parameterised way, don't be tempted to re-use absolute paths; fluidsynth and gthread disagree on whether glib lives in `/usr/local/opt` or `/usr/local/Cellar`.

#### There's no debugger

There used to be a [helpful environment variable](https://nickdesaulniers.github.io/blog/2016/11/20/static-and-dynamic-libraries/), `LD_DEBUG`, which let you watch runtime link resolution.  
Unfortunately, [Apple removed it](https://www.reddit.com/r/C_Programming/comments/5kypa9/ld_preload_support_removed_from_osx_10122s/). Probably [at source-level](https://stackoverflow.com/questions/17106383/ld-debug-on-freebsd).

There is _some_ tracing you can enable in the runtime linker. You can see how it expands the variable @rpath, and whether that succeeded.

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="k">DYLD_PRINT_RPATHS=1</span> …/juicysfplugin.app/Contents/MacOS/juicysfplugin
<span class="nb">RPATH successful expansion of @rpath/lib/libfluidsynth.dylib</span>
…
<span class="k">DYLD_PRINT_LIBRARIES=1</span> …/juicysfplugin.app/Contents/MacOS/juicysfplugin
<span class="nb">dyld: loaded: …/juicysfplugin.app/Contents/MacOS/juicysfplugin
dyld: loaded: …/juicysfplugin.app/Contents/MacOS/../lib/libfluidsynth.dylib</span>
…
</code></pre>
  </div>
</div>

It will tell you which expansions of @rpath fail (here I deliberately wrote in a link to a non-existent file):

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="k">DYLD_PRINT_RPATHS=1</span> …/juicysfplugin.app/Contents/MacOS/juicysfplugin
<span class="ne">RPATH failed to expanding     @rpath/lib/</span><span class="err">notlibfluidsynth.dylib</span>
dyld: Library not loaded: @rpath/lib/notlibfluidsynth.dylib
  Referenced from: …/juicysfplugin.app/Contents/MacOS/juicysfplugin
  Reason: image not found
</code></pre>
  </div>
</div>

You can get _some_ feedback regarding how it searches _fallback locations_.  
I copied `notlibfluidsynth.dylib` into `~/tmp` (a directory I specify as a fallback location), and it succeeds, and tells you which location it used:

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>DYLD_PRINT_LIBRARIES=1 <span class="se">\</span>
<span class="k">DYLD_FALLBACK_LIBRARY_PATH="$HOME/tmp:$DYLD_FALLBACK_LIBRARY_PATH"</span> <span class="se">\</span>
…/juicysfplugin.app/Contents/MacOS/juicysfplugin
dyld: loaded: …/juicysfplugin.app/Contents/MacOS/juicysfplugin
<span class="nb">dyld: loaded: ~/tmp/notlibfluidsynth.dylib</span>
</code></pre>
  </div>
</div>

The linker provides other `DYLD_PRINT_*` variables, like `DYLD_PRINT_STATISTICS_DETAILS`, `DYLD_PRINT_ENV`, `DYLD_PRINT_OPTS`. I recommend you check them out in `man dyld`. You can see the environment and options with which your process is launched, or read statistics of how it spent its time before calling `main()`.

##### DTrace won't help here

I wanted to trace the dylib lookups using [DTrace](http://dtrace.org/blogs/brendan/2011/10/10/top-10-dtrace-scripts-for-mac-os-x/).:

```bash
sudo dtrace 2>/dev/null -n '
// print lookups and opens of filepaths matching "dylib"
// attempted by processes "juicysfplugin" or "dyld"
syscall::*stat*:entry,
syscall::open:entry,
syscall::open_nocancel:entry,
syscall::open_extended:entry
/(execname == "dyld" || execname == "juicysfplugin") && strstr(copyinstr(arg0), "dylib") > 0/
{
  printf("%s %s", execname, copyinstr(arg0));
}' -c '…/juicysfplugin.app/Contents/MacOS/juicysfplugin'
```

But sadly, dtrace doesn't seem to start tracing until after the process launches. Moreover, we cannot attach to dyld. Not just because of [System Integrity Protection](https://stackoverflow.com/questions/33476432/is-there-a-workaround-for-dtrace-cannot-control-executables-signed-with-restri), but also because dyld is not a user-land process. We do not see it in pgrep, nor is it a short-lived process that we can observe using execsnoop.

And all of this is modulated by the fact that dyld has a cache, so it may not do syscalls. We can turn this off with `DYLD_SHARED_REGION=avoid`, but passing that environment to the dtrace cmd is difficult; `dtrace -c` is [very broken on macOS](https://8thlight.com/blog/colin-jones/2017/02/02/dtrace-gotchas-on-osx.html).

## Alternatives to manually rewriting dynamic links

Trawling the dependency list and relinking all non-system libraries with `install_name_tool` is manual and non-scalable.  
For this small project, it was a [local optimum](https://en.wikipedia.org/wiki/Local_optimum) of effort/reward.

But if you want to distribute your macOS application without using `install_name_tool`, there are some other routes you could try.

### Provide an installer

Users could run an installer, to copy dependencies to `/usr/local/Cellar`, like brew does (or the installer could properly brew install them). No relinking required.

### Distribute application via brew

Brew already provides a distribution mechanism and semantics for expressing dependencies. You could take advantage of that if users are comfortable with command-line installation.

### Statically link

Static linking burns a library into your executable. This means there's no possibility for the library to be in the wrong place or missing.

That said, static linking is fiddly. You would compile the source of libfluidsynth, libsndfile **and so on** into object files. Then you would collect them into one big archive, libfluidsynth.a. Then you would compile the source of juicysfplugin, and statically link its object code to libfluidsynth.a.

The problem is the "and so on". Eventually there's a dependency in the tree which **cannot be statically linked**. macOS [does not provide static versions of libSystem.dylib](https://stackoverflow.com/questions/844819/how-to-static-link-on-os-x#846194). GNU libc [is not designed to be statically linked](https://stackoverflow.com/a/26306630/5257399).

Mercifully, the user is guaranteed to have system libraries, so we can link to those dynamically. But for anything else: we would have to change the way we build objects in libfluidsynth.a (i.e. omit unused dependencies, or configure alternatives which can be statically linked).

Supposing you succeed, you still have a new problem: licensing. By statically linking, you've created a derivative work in your name, instead of distributing the original artefact.  
If you statically link to a GPL library, you must release under GPL license: the source for both your work and the library. Statically linking to LGPL: you may instead release just the compiled object code for your work.  
Note: I am not a lawyer, and I inferred the above from [this discussion](https://stackoverflow.com/questions/10130143/gpl-lgpl-and-static-linking).

### Provide a runtime fallback for dynamic linking

Don't actually do this, but you can abuse the dynamic linker, [dyld](https://www.unix.com/man-page/osx/1/dyld/).

> The dynamic linker uses the following environment variables. They affect any program that uses the dynamic linker.  
> 
> **DYLD_FALLBACK_LIBRARY_PATH**  
> &nbsp;&nbsp;It is used as the default location for libraries not found in their install path. By default, it is set to `$(HOME)/lib:/usr/local/lib:/lib:/usr/lib.`

When resolution fails for `/usr/local/Cellar/glib/2.56.1/lib/libglib-2.0.0.dylib`, dyld will search for the leaf name `libglib-2.0.0.dylib` under each of those fallback library paths.

So, you could provide a folder of libs and instruct the user to add that folder to their DYLD_FALLBACK_LIBRARY_PATH.

```bash
# add to your .profile or similar
export DYLD_FALLBACK_LIBRARY_PATH="$HOME/Downloads/juicysfplugin/lib:$DYLD_FALLBACK_LIBRARY_PATH"
```

### Fix the install name of the dependency before you link to it



<!--
https://github.com/conda/conda-build/issues/279
https://stackoverflow.com/questions/9263256/why-is-install-name-tool-and-otool-necessary-for-mach-o-libraries-in-mac-os-x
https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/100-Articles/UsingDynamicLibraries.html
https://stackoverflow.com/questions/10363687/xcode-4-dylib-install-name-tool?rq=1
https://stackoverflow.com/questions/27506450/clang-change-dependent-shared-library-install-name-at-link-time
https://stackoverflow.com/questions/10021428/macos-how-to-link-a-dynamic-library-with-a-relative-path-using-gcc-ld
https://stackoverflow.com/questions/194485/how-do-i-create-a-dynamic-library-dylib-with-xcode
-->

## Reflection

Maybe there's a more idiomatic way to do this. But I've seen [others](https://stackoverflow.com/questions/17535604/deploying-cocoa-application-and-its-c-dylib-how-to-pack-them) do [the same](https://stackoverflow.com/questions/637081/how-can-i-link-a-dynamic-library-in-xcode).

I get the impression that "bundling software for distribution" is not well-supported on macOS.





