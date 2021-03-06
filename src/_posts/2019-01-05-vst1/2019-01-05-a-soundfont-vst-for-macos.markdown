---
layout: post
title:  "A soundfont VST for macOS"
date:   2019-01-05 19:00:00 -0000
categories: blog Alex juicysfplugin synth cpp
syntax_highlight: true
author: Alex Birch
---

{::nomarkdown}
<input class="toggler" type="checkbox" id="diagramoverflow">
<!-- <input class="toggler" type="checkbox" id="snippetwrap"> -->
{:/}

<style>
{% capture blogstyle %}
  @charset 'utf-8';
  @import 'marx/variables';
  .diagram-container {
    max-width: 100%;
    /*height: 400px;*/
    overflow-x: auto;
    overflow-x: overlay;
  }
  
  $center-col-pad: $md-pad;
  $center-col-max-wid: $large-breakpoint - $center-col-pad * 2;
  $diagram-width: 800px;
  $right-overflow: $diagram-width - $center-col-max-wid;
  $diagram-wider-noscroll: $large-breakpoint + $right-overflow * 2;
  /*$diagram-wider-noscroll: 878px;*/

  .highlighter-rouge div.highlight {
    background: initial;
  }

  .highlighter-rouge pre.highlight {
    display: inline-block;
    margin-top: 0px;
    min-width: 100%;
    word-break: break-all;
  }
  
  /* if diagram fits without scrollbar, hide toggles and turn off scrollbar */
  @media screen and (min-width: $diagram-wider-noscroll + 1px) {
    .diagram-container {
      overflow-x: visible;
    }
    /* if we are in full desktop width, snippet is at planned size, so it has intended wrapping already */
    div.highlighter-rouge pre.highlight {
      white-space: pre-wrap !important;
      margin-top: $md-pad;
      word-break: initial;
    }
    label[for="diagramoverflow"] {
      display: none;
    }
  }
  
  input.toggler {
    display: none;
  }
  input.toggler ~ label {
    cursor: pointer;
    /*background-size: cover;*/
    font-size: 0.8em;
  }
  /*input.toggler + label:hover {
    text-decoration: underline;
  }*/
  input.toggler#diagramoverflow:checked ~ label[for="diagramoverflow"] + div.diagram-container {
    overflow-x: visible;
  }
  input.toggler#diagramoverflow:checked ~ label[for="diagramoverflow"] {
    background-image: url({{ relative }}glyph_contract.svg);
  }
  input.toggler#diagramoverflow:checked ~ label[for="diagramoverflow"] + div.highlighter-rouge pre {
    white-space: pre;
    overflow: initial;
  }
  input.toggler#diagramoverflow:checked ~ label[for="diagramoverflow"] {
    background-image: url({{ relative }}glyph_contract.svg);
  }
  input.toggler ~ label {
    background-image: url({{ relative }}glyph_expand.svg);
  }
  input.toggler ~ label:after {
    content: "     ";
    white-space: pre-wrap;
  }
  /*input.toggler:checked ~ label:after {
    content: "Make Narrow";
  }
  input.toggler ~ label:after {
    content: "Make Wide";
  }*/
{% endcapture %}
{{ blogstyle | scssify }}
</style>

Soundfonts are great for making music quickly. With no learning or configuration, you can play samples from a variety of instruments.

I wanted to make soundfont music on [FL Studio](https://www.image-line.com/flstudio/) Mac.

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
  - updates the state of each 'voice' (for example: release the C key)
  - our voice implementation passes `startNote()`, `stopNote()` to fluidsynth
3. We ask fluidsynth to output 512 samples of audio into AudioBuffer
  - fluidsynth has its own clock, so it knows this block starts where the previous block ended
  - fluidsynth has its own sample rate, which we keep updated

MIDI messages go in. We render the MIDI messages through the fluidsynth synthesiser. Then we output audio.

## Integrating fluidsynth

I needed to dynamically link the fluidsynth library into my executable. Basic linker flags suffice:  
`-lfluidsynth -L/usr/local/lib` (that's the brew libraries directory).

But this creates a non-portable release:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="diagram-container">
<!-- nominally 800x400 -->
<object
width="800"
height="400"
data="{{ relative }}unbundled.svg"
type="image/svg+xml"></object>
</div>
{:/}

Open juicysfplugin.app on another computer, and you get [this error](https://stackoverflow.com/a/19230699/5257399):

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>dyld: <span class="ne">Library not loaded:</span> <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span>
  Referenced from: ~/juicysfplugin.app/Contents/MacOS/juicysfplugin
  Reason: image not found
</code></pre>
  </div>
</div>
{:/}

The fluidsynth library doesn't exist on their system. They never brew-installed it.

Rather than tell users to prepare their environment, let's _bundle_ the library into our .app.  
We copy libfluidsynth into `juicysfplugin.app/Contents/lib` during XCode's "copy files" build phase.

**Next, we must relink our binary to use the bundled libfluidsynth.**

### Relinking

Where does `juicysfplugin.app/Contents/MacOS/juicysfplugin` currently look for libfluidsynth?

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<span class="gu">otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>
{:/}

Let's rewrite the `/usr/local` link, to search relative to `@loader_path`:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>install_name_tool <span class="nt">-change</span> <span class="se">\</span>
<span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span>         <span class="sb">`</span><span class="c"># rewrite this link</span><span class="sb">` \</span>
<span class="nb">@loader_path/../lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span>    <span class="sb">`</span><span class="c"># to this</span><span class="sb">` \</span>
~/juicysfplugin.app/Contents/MacOS/juicysfplugin <span class="sb">`</span><span class="c"># in this obj file</span><span class="sb">`</span>

<span class="c"># @loader_path points to our binary's directory:</span>
<span class="c"># juicysfplugin.app/Contents/MacOS</span>
</code></pre>
  </div>
</div>
{:/}

Our linkage now looks like this:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="diagram-container">
<object
width="800"
height="400"
data="{{ relative }}bundled1.svg"
type="image/svg+xml"></object>
</div>
{:/}

Let's read the object file again to verify that we successfully relinked:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  <span class="nb">@loader_path/../lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>
{:/}

### It goes deeper

We run our relinked .app on another computer. The first error is gone, but we're onto a new error:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>dyld: <span class="ne">Library not loaded:</span> <span class="err">/usr/local/opt/glib/lib/</span><span class="k">libglib-2.0.0.dylib</span>
  Referenced from: ~/juicysfplugin.app/Contents/lib/libfluidsynth.1.7.2.dylib
  Reason: image not found
</code></pre>
  </div>
</div>
{:/}

fluidsynth needs glib. glib doesn't exist on their system. They never brew-installed it:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="diagram-container">
<object
width="800"
height="400"
data="{{ relative }}part_bundled.svg"
type="image/svg+xml"></object>
</div>
{:/}

The bundle & relink dance must be done for all dependencies, _recursively_:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="diagram-container">
<object
width="800"
height="400"
data="{{ relative }}bundled_again.svg"
type="image/svg+xml"></object>
</div>
{:/}

[Something like this](https://github.com/Birch-san/juicysfplugin/blob/f8b354d1585dd2f615f2842079b384fd92c325e3/Builds/MacOSX/relink-build-for-distribution.sh). Tedious.

 <!-- Others have wondered [the same problem](https://stackoverflow.com/questions/9263256/why-is-install-name-tool-and-otool-necessary-for-mach-o-libraries-in-mac-os-x). -->

<!--
The chain of brew dependencies can go pretty deep. For example, libsndfile (which adds support for [SF3 soundfonts](https://musescore.org/en/node/151611)) introduces this many links:

<div class="language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">juicysfplugin</span>
  <span class="k">libsndfile</span>
    libFLAC
    libogg
    libvorbis
      libogg
    libvorbisenc
      libvorbis
      libogg
</code></pre>
  </div>
</div>
-->

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

### Simplifying the build

We've established that we'll want to have inside our .app: a copy of every .dylib. And we want to rewrite the load commands in every dylib, plus our juicysfplugin binary.

Our libraries don't change between builds, so if we do the relinking dance just once, we can save those relinked libraries to `$(PROJECT_DIR)/lib`.  
This is a project-local copy of the dylib, which can be shared via version control.

Next, we change our environment-specific `-L/usr/local/lib` library search path to `-L$(PROJECT_DIR)/lib`.

We attempt a build of juicysfplugin with our new linker flags: `-lfluidsynth -L$(PROJECT_DIR)/lib`.

The linker correctly finds our project-local libfluidsynth, and links to it. But what's this?

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>
{:/}

Why does juicysfplugin _still_ load fluidsynth via the environment-specific `/usr/local`?

It's because of what fluidsynth's install_name was, at the time we linked to it.  
We can view a dylib's install name with `otool -D`:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -D $(PROJECT_DIR)/lib/libfluidsynth.dylib</span>
libfluidsynth.dylib:
  <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>
{:/}

The install_name recommends that consumers of libfluidsynth look for a dylib in `/usr/local`. We need to change that recommendation.

Let's edit our project-local copy of libfluidsynth.  
Give it a binary-relative install_name:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>install_name_tool <span class="nt">-id</span>                            <span class="sb">`</span><span class="c"># set install_name</span><span class="sb">` \</span>
<span class="nb">@loader_path/../lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span>    <span class="sb">`</span><span class="c"># to this</span><span class="sb">` \</span>
$(PROJECT_DIR)/lib/libfluidsynth.dylib           <span class="sb">`</span><span class="c"># in this obj file</span><span class="sb">`</span>
</code></pre>
  </div>
</div>
{:/}

Next time we build juicysfplugin, we see that the linker now writes the correct load command into our binary:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -L ~/juicysfplugin.app/Contents/MacOS/juicysfplugin</span>
juicysfplugin.app/Contents/MacOS/juicysfplugin:
  <span class="nb">@loader_path/../lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …
</code></pre>
  </div>
</div>
{:/}

We no longer need to do any post-build relinking of juicysfplugin or its libraries.  
juicysfplugin links to a project-local libfluidsynth, which has been configured to tell consumers to use a binary-relative link.

### More project-agnostic convention

Our binary-relative link, `@loader_path`, is successful in making our binaries portable. We could even stop here.  
But there's an itch remaining.

It's bad that our libraries are responsible for declaring "where can I be found at runtime". This forced us to make a project-specific copy of each library, with baked-in assumptions about juicysfplugin.app's directory layout.

It's preferable to invert the control.  
The binary, juicysfplugin, should be in charge of "where will libraries be found at runtime".

Thankfully, there's a mechanism to accomplish this: @rpath expansion.

Libraries may set an @rpath-relative install_name.  
Binaries decide at runtime how to expand @rpath, and may even specify fallbacks.

Let's make fluidsynth's install_name @rpath-relative:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code>install_name_tool <span class="nt">-id</span>                            <span class="sb">`</span><span class="c"># set install_name</span><span class="sb">` \</span>
<span class="nb">@rpath/</span><span class="k">libfluidsynth.1.7.2.dylib</span>                 <span class="sb">`</span><span class="c"># to this</span><span class="sb">` \</span>
$(PROJECT_DIR)/lib/libfluidsynth.dylib           <span class="sb">`</span><span class="c"># in this obj file</span><span class="sb">`</span>
</code></pre>
  </div>
</div>
{:/}

Then we configure the juicysfplugin binary to use a "runtime search path" of `@loader_path/../lib`. This is an XCode build setting, equivalent to gcc's `-rpath` option.

Now the libfluidsynth that we saved under `$(PROJECT_DIR)/lib` is environment-independent and project-independent. Other open-source developers may like to grab this portable library and use it in their own project.

To finish the job: replace all the `@loader_path` links we made earlier (i.e. fluidsynth to its brew dependencies) with @rpath.  
And (optionally) declare @rpath install_names upon each dylib, to help anybody who links directly to the libraries you ship.

## Generalizing the process

There's some relatable use-cases here:

- You link to some brew-installed library (e.g. libfluidsynth), and want to make a relinked project-local copy of that library
- You produce some binary (e.g. `juicysfplugin.app/Contents/MacOS/juicysfplugin`), and want to bundle+link libraries into the app, for portable distribution

I've automated both of these use-cases with [this bash script](https://gist.github.com/Birch-san/e84cfa3b93ffa104af2bd9a047d14109).  
Run `./make_portable.sh mycoolbinary` or `./make_portable.sh libcool.dylib` to make any mach-o object file portable.  
It follows the dependencies, copies them into a nearby `lib` folder, and relinks everything to use those local libraries.

I am [not the only one](https://github.com/essandess/matryoshka-name-tool) to automate this.

## Further hints

### Why not use @executable_path?

We output a variety of build targets. In the standalone juicysfplugin.app, @loader_path and @executable_path are the same thing.

The plugin targets (VST, VST3, AU), however, are designed to be hosted inside a different executable (e.g. Garageband, FL Studio).  
Here @executable_path points to the plugin host (Garageband.app/Contents/MacOS), which is not what we want.

We want to load libraries relative to the binary which contains the load command. Hence @loader_path is necessary.

### install_name_tool gotchas

When relinking a library with `install_name_tool [-change old new] file`, beware: you must match **exactly**.

To find the link matching `/usr/local/Cellar/glib/2.56.1/lib/libglib-2.0.0.dylib` and rewrite it…

- You cannot match on leaf name `libglib-2.0.0.dylib` or library name, `glib`.
- You cannot match on an equivalent symlink path `/usr/local/opt/glib/lib/libglib-2.0.0.dylib`

If your command matches nothing: there is no error message, and the exit code says success as usual.

If you are automating this in a parameterised way, don't be tempted to re-use absolute paths; fluidsynth and gthread disagree on whether glib lives in `/usr/local/opt` or `/usr/local/Cellar`.

#### There's no debugger

There used to be a [helpful environment variable](https://nickdesaulniers.github.io/blog/2016/11/20/static-and-dynamic-libraries/), `LD_DEBUG`, which let you watch runtime link resolution.  
Unfortunately, [Apple removed it](https://www.reddit.com/r/C_Programming/comments/5kypa9/ld_preload_support_removed_from_osx_10122s/). Probably [removed a build option](https://stackoverflow.com/questions/17106383/ld-debug-on-freebsd).

There is _some_ tracing you can enable in the runtime linker. You can see how it expands the variable @rpath, and whether that succeeded.

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="k">DYLD_PRINT_RPATHS=1</span> …/juicysfplugin.app/Contents/MacOS/juicysfplugin
<span class="nb">RPATH successful expansion of @rpath/lib/libfluidsynth.dylib</span>
…
<span class="k">DYLD_PRINT_LIBRARIES=1</span> …/juicysfplugin.app/Contents/MacOS/juicysfplugin
dyld: loaded: …/juicysfplugin.app/Contents/MacOS/juicysfplugin
<span class="nb">dyld: loaded: …/juicysfplugin.app/Contents/MacOS/../lib/libfluidsynth.dylib</span>
…
</code></pre>
  </div>
</div>
{:/}

It will tell you which expansions of @rpath fail (here I deliberately wrote in a link to a non-existent file):

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
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
{:/}

You can get _some_ feedback regarding how it searches _fallback locations_.  
I copied `notlibfluidsynth.dylib` into `~/tmp` (a directory I specify as a fallback location), and it succeeds, and tells you which location it used:

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
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
{:/}

The linker provides other `DYLD_PRINT_*` variables, like `DYLD_PRINT_STATISTICS_DETAILS`, `DYLD_PRINT_ENV`, `DYLD_PRINT_OPTS`. I recommend you check them out in `man dyld`. You can see the environment and options with which your process is launched, or read statistics of how it spent its time before calling `main()`.

<!--
##### DTrace won't help here

I wanted to trace the dylib lookups using [DTrace](http://dtrace.org/blogs/brendan/2011/10/10/top-10-dtrace-scripts-for-mac-os-x/).:

{::nomarkdown}
<label for="diagramoverflow"></label>
{:/}
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

But sadly, dtrace doesn't seem to start tracing until after the process launches. Moreover, we cannot attach to dyld. Not just because of [System Integrity Protection](https://stackoverflow.com/questions/33476432/is-there-a-workaround-for-dtrace-cannot-control-executables-signed-with-restri), but also because dyld is not a user-land process. We do not see it in pgrep or execsnoop.

And all of this is modulated with the fact that dyld has a cache, so it may not hit the filesystem. We can turn this off with `DYLD_SHARED_REGION=avoid`, but passing that environment to the dtrace cmd is difficult; `dtrace -c` is [very broken on macOS](https://8thlight.com/blog/colin-jones/2017/02/02/dtrace-gotchas-on-osx.html).
-->

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

Mercifully, the user is guaranteed to have system libraries, so we can link to those dynamically. But for anything else: we would have to change the way we build objects in libfluidsynth.a (i.e. omit unused dependencies, use alternative libraries which can be statically linked, or use a mixture of static/dynamic linking).

Supposing you succeed, you still have a new problem: licensing. By statically linking, you've created a derivative work in your name, instead of distributing the original artefact.  
If you statically link to a GPL library, you must release under GPL license: the source for both your work and the library. Statically linking to LGPL: you may instead release just the compiled object code for your work.  
Note: I am not a lawyer, and I inferred the above from [this discussion](https://stackoverflow.com/questions/10130143/gpl-lgpl-and-static-linking).

### Reconfigure the runtime linker

Don't actually do this, but you can abuse the dynamic linker, [dyld](https://www.unix.com/man-page/osx/1/dyld/).

> The dynamic linker uses the following environment variables. They affect any program that uses the dynamic linker.  
> 
> **DYLD_FALLBACK_LIBRARY_PATH**  
> &nbsp;&nbsp;It is used as the default location for libraries not found in their install path. By default, it is set to `$(HOME)/lib:/usr/local/lib:/lib:/usr/lib.`

When resolution fails for `/usr/local/Cellar/glib/2.56.1/lib/libglib-2.0.0.dylib`, dyld will search for the leaf name `libglib-2.0.0.dylib` under each of those fallback library paths.

So, you could provide a folder of libs and instruct the user to add that folder to their DYLD_FALLBACK_LIBRARY_PATH.

{::nomarkdown}
<label for="diagramoverflow"></label>
{:/}
```bash
# add to your .profile or similar
export DYLD_FALLBACK_LIBRARY_PATH="$HOME/Downloads/juicysfplugin/lib:$DYLD_FALLBACK_LIBRARY_PATH"
```

This isn't very deterministic though. Our bundled libraries would only be used as a last resort.

More prescriptive is to use `DYLD_INSERT_LIBRARIES`. This has higher precedence; the bundled libraries are checked as a _first_ resort.



<!--
### Fix the install name of the dependency before you link to it

When we link against a brew library (`-lfluidsynth -L/usr/local/lib`), why is it that our link is an _absolute path_?

It's because of the install_name of the .dylib.

#### Find install_name

We can see this with `otool -L`. It shows load commands in an object file's private headers.  
Earlier we used it to see LC_LOAD_DYLIB ("what libraries does our binary link to"), but it also shows us LC_ID_DYLIB ("what does this library call itself"):

{::nomarkdown}
<label for="diagramoverflow"></label>
<div class="wrap-me language-bash highlighter-rouge">
  <div class="highlight">
    <pre class="highlight">
<code><span class="gu">otool -L /usr/local/lib/libfluidsynth.dylib</span>
/usr/local/lib/libfluidsynth.dylib:
  <span class="err">/usr/local/lib/</span><span class="k">libfluidsynth.1.7.2.dylib</span> (compatibility version 1.0.0, current version 1.7.2)
  …

<span class="c"># use lower-case otool -l for more detail</span>
</code></pre>
  </div>
</div>
{:/}

What does this install_name tell us? It means that any object file linking to this dylib, will refer to it as `/usr/local/lib/libfluidsynth.1.7.2.dylib`.

But that's just the suggested initial value. As demonstrated earlier, we can use install_name_tool to change the load commands in our juicysfplugin executable.

We can fix the problem even earlier: **change the install_name.**

#### Set install_name relative to juicysfplugin

By setting libfluidsynth's install_name to `@loader_path/../lib/libfluidsynth.1.7.2.dylib`, the juicysfplugin binary we build will have a relative link from the very start. No post-build fiddling is necessary.

Moreover, now that the library has a relative install_name, it's not environment-specific. It can be copied into our project folder and shared alongside our source code. We can add that project-local folder to our library search path.

#### Multiple consumers of library

We can clean this up even further. `@loader_path/../lib/` is too project-specific. It's best if we can support a variety of project structures.

The install_name `@rpath/libfluidsynth.1.7.2.dylib` lets us invert control. Each project that consumes this library can specify a list of rpaths to search. juicysfplugin specifies a runtime search path of `../lib`., so @rpath expands to: `…juicysfplugin.app/Contents/MacOS/../lib/libfluidsynth.1.7.2.dylib`.

-->
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

It was fun to deep-dive into dynamic linking. The non-intuitive bits were:

- install_name_tool has a bad API for rewriting links
  - To rewrite a link: you must state the current link's fully-qualified path
  - I would rather specify the library's leaf name
- The linker writes load commands based on a library's install_name
  - My intuition was that it'd use the current filesystem path of the library
- `otool -L` has a weird output format
  - various load commands are displayed, but their 'type' is hidden
  - `otool -l` is more specific, but hard to parse
- @rpath expansion seems far more sane than distributing project-specific libraries, but it is underused

I'm surprised by how fiddly this was. I'd thought software bundling would be a really solved problem on macOS. The .app format is a nice attempt at making applications portable, but the dream falls flat if dynamic linking is difficult.

The Windows version of juicysfplugin was far easier to link. If the library is not found in the primary location, the runtime linker will search for it in a few fallback directories. These are pretty convenient; you can place the .dll alongside your application, or into the system folder (an installer can help with this).

It would be nice if Brew libraries were built with @rpath-relative install_names. For my application, this would've removed any need for relinking. But redistributability of libraries requires [solving more problems than just linking](https://github.com/Homebrew/brew/issues/4371). And if you distribute your own software via the brew ecosystem, then library paths are well-known anyway.

Still, the journey was educational. The concepts are transferable (it's helped me resolve linking problems on Linux), but I can see that there are ecosystems (JVM, NodeJS) that have a totally different approach to libraries. A developer could build a career on JVM/JS and never have to battle with native code linking. Docker is another way to solve the portability problem for native code, since it gives you a reproducible environment.

I feel like native code linking is in danger of becoming a lost art, but at the same time I have confidence that WebAssembly (which enables native code to target the browser) and GraalVM (which enables LLVM-compatible source code to target the JVM) will generate new interest.