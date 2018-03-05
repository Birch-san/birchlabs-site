---
layout: post
title:  "Looking up non-dictionary form words in thirty languages"
date:   2018-01-28 14:16:43 -0000
categories: blog Jamie LinguaBrowse
syntax_highlight: true
author: Jamie Birch
---

## Introduction

### A web browser for foreign languages: LinguaBrowse

**[LinguaBrowse](https://itunes.apple.com/us/app/linguabrowse/id1281350165?ls=1&mt=8)** is an iOS app for reading native-level foreign-language texts on the internet. It allows users to look up any unknown word on a web-page simply by tapping on it, so users don't have to wrestle with any text selection boxes nor constantly switch out to a dictionary app.

In this post, I'll detail all the language processing that goes on under the hood to facilitate this multilingual tap-to-define functionality. 


<!-- {% include blog-height-limited-image.html url="2018-01-28-word-post-processing/ChineseLookup.png" width="621" height="1104" max-height="600" description="Tap-to-define for a Chinese word. Here using the iOS system dictionary for Chinese ↔ English (shown with permission from the Oxford Dictionaries API team)." %} -->

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/ChineseLookup2.png" width="688" height="1223" max-height="600" description="Tap-to-define for a Chinese word. Here using the iOS system dictionary for Chinese ↔ English (shown with permission from the Oxford Dictionaries API team)." %}

### NLP tools used by LinguaBrowse

The tap-to-define functionality employs two of Apple's Natural Language Processing tools:

* [CFStringTokenizer](https://developer.apple.com/documentation/corefoundation/1542136-cfstringtokenizercopybeststringl), which I use to initially process the text of a page into tokens (that the user can tap upon to prompt a dictionary lookup) and for adding transcriptions to non-Latin scripts (e.g. adding pīnyīn to Mandarin).

* [NSLinguisticTagger](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSLinguisticTagger_Class/), to subsequently convert any tapped token into dictionary form (if necessary) before lookup.

* [CFStringTransform](https://developer.apple.com/documentation/corefoundation/1542411-cfstringtransform), to convert traditional Chinese characters into Simplified form (because the iOS Chinese ↔ English system dictionary expects Simplified Chinese). In an old part of my codebase, I'm also using it to transliterate Thai for some reason.

I substitute CFStringTokenizer and NSLinguisticTagger with [MeCab](https://github.com/shirakaba/iPhone-libmecab/tree/korean) to provide lemmatisation support for Japanese and Korean. This is the tool that Apple have used since at least Mac OS 10.5 for Japanese tokenising<sup>[[1]](https://web.archive.org/web/20160305113404/http://chasen.org/~taku/blog/archives/2008/07/mac_os_x_leropa.html)[[2]](https://web.archive.org/web/20170708060425/http://d.hatena.ne.jp:80/kazama/20080115/p1)</sup>, and I [have heard](https://stackoverflow.com/a/8285221/5951226) it's even the exact tokenizer used in CFStringTokenizer for Japanese. Whether the older NSLinguisticTagger ('NS' indicating NeXTSTEP, and 'CF' indicating Core Foundation) uses it too is another question altogether.

<!-- NSLinguisticTagger also helps in Japanese, if compound nouns fail to split; I experience this for some *katakana* loan words, possibly because my bundled MeCab may be using a different dictionary to that of CFStringTokenizer (which likely uses MeCab under the hood in any case, as Apple have been employing it since at least Mac OS 10.5<sup>[[1]](https://web.archive.org/web/20160305113404/http://chasen.org/~taku/blog/archives/2008/07/mac_os_x_leropa.html)[[2]](https://web.archive.org/web/20170708060425/http://d.hatena.ne.jp:80/kazama/20080115/p1)</sup>). -->

<!-- LinguaBrowse begins by processing the text of a page into (mostly) word-sized tokens using [CFStringTokenizer](https://developer.apple.com/documentation/corefoundation/cfstringtokenizer-rf8), then effectively making each token into a tappable button. Upon tap, the user may search that token as-is in a dictionary. -->

### What is CFStringTokenizer useful for?

CFStringTokenizer makes sense of texts: it can [figure out the predominant language](https://developer.apple.com/documentation/corefoundation/1542136-cfstringtokenizercopybeststringl), add [Latin transcriptions](https://developer.apple.com/documentation/corefoundation/kcfstringtokenizerattributelatintranscription) to words, and [split up texts up into smaller units](https://developer.apple.com/documentation/corefoundation/cfstringtokenizer/1588024-tokenization_modifiers), such as paragraphs, sentences, or words (this is a godsend for languages without spaces). In LinguaBrowse, I use it just for tokenising texts into arrays of words and adding transcriptions.

For Mandarin, which lacks any inflections, every token output by CFStringTokenizer will map to a dictionary-form word, and can thus be looked up in a dictionary as-is. However, most other languages have grammatical obstacles such as inflections that would cause lookup of the word as-is to fail (or return poor results). This is where NSLinguisticTagger comes in.

<!-- (with their [Lemmatron](https://developer.oxforddictionaries.com/documentation?__prclt=OId2cMb0)) -->

<!-- \* *Technically, some of the iOS system dictionaries, such as the Oxford ones, have built-in lemmatisers to handle non-dictionary form words, but most language pairs don't have a system dictionary, nor can we depend upon them having been installed.* -->

<!-- {% include blog-image.html url="2018-01-28-word-post-processing/lookup_50.png" width="1125" height="665" description="Comparison between dictionary definitions on Glosbe (https://glosbe.com) given for the inflected form of a word (left), which at best is able to provide a Google translation, and the dictionary form (right), which is able to directly provide high-quality definitions and other useful information." %} -->


### What is NSLinguisticTagger useful for?

NSLinguisticTagger has a lot of overlapping functionality with CFStringTokenizer: again, it can [tokenise texts into smaller units](https://developer.apple.com/documentation/foundation/nslinguistictaggerunit), [identify the dominant language](https://developer.apple.com/documentation/foundation/nslinguistictagger/2875117-dominantlanguage) for said units, but it can also do so much more. It can also [identify the dominant script](https://developer.apple.com/documentation/foundation/nsorthography) (such as Cyrillic or Simplified Chinese) of a unit, [identify part-of-speech](https://developer.apple.com/documentation/foundation/nslinguistictagscheme) of a word – including classifying by sub-types, as in [named entity recognition](https://developer.apple.com/documentation/foundation/nslinguistictagscheme/1415135-nametype) – and even [identify the lemma](https://developer.apple.com/documentation/foundation/nslinguistictagscheme/1416890-lemma) (dictionary form) of a word.

[As of iOS 11](https://developer.apple.com/videos/play/wwdc2017/208/), it's multi-threaded, it can tokenise all iOS/macOS system languages and identify 52 different languages – however, only eight languages are supported for lemmatisation, part-of-speech identification, and named entity recognition: English, French, Italian, German, Spanish, Portuguese, Russian, and Turkish.

So why not use NSLinguisticTagger for everything? Well, unless things have changed with the iOS 11 optimisations, CFStringTokenizer is historically [orders of magnitude faster](https://medium.com/@sorenlind/three-ways-to-enumerate-the-words-in-a-string-using-swift-7da5504f0062) at tokenising the same given length of string (although may perform comparably for small strings), and its tokenising time scales far better with input string length. So I decided to leave the tokenising to CFStringTokeniser, and the tagging to NSLinguisticTagger!

<!-- ### Looking up non-dictionary form words -->

With NSLinguisticTagger, we can support those eight extra languages by allowing users to look up words by their dictionary forms.

<!-- For other languages, non-dictionary form words are everywhere, and looking them up as-is is unlikely to return a result. Thus, I provide users a tooltip so that they can either look up the token returned by CFStringTokenizer as-is, or by a dictionary form elucidated by NSLinguisticTagger. Here's a few different examples, superimposed, of how often this can help even in just one paragraph:

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/superimposition.png" width="640" height="1136" max-height="600" description="LinguaBrowse can now handle all manner of conjugations, contractions, and other grammatical features that would otherwise impede dictionary lookup of a word (superimposed image of several use cases; in real usage, only one tooltip would be displayed at a time)." %} -->


## Aiding dictionary lookup with NLP

### Introduction

I'd like to highlight a few of the troublesome grammatical features posing problems to dictionary lookup that have required me to call upon a mixture of NLP tools to surmount:

1. [compound nouns](#1-compound-nouns) (examples from English, German, and Japanese)

2. [inflected words](#2-inflected-words) (examples from English)

3. [contractions](#3-contractions) (examples from French, English, Italian, and – as a bonus – Japanese and Chinese)

### 1. Compound nouns

#### What are compound nouns?

Compound nouns are nouns made by combining together multiple words. In English, there are many ways to create them, and they needn't even contain any nouns. For example:

* 'bath' + 'room' = 'bathroom' (noun + noun)

* 'small' + 'talk' = 'small talk' (adjective + noun)

* 'hair' + 'cut' = 'haircut' (noun + verb)

* 'dry' + 'cleaning' = 'dry cleaning' (adjective + verb)

* 'draw' + 'back' = 'drawback' (verb + preposition)

#### How should they be processed to aid dictionary lookup?

I'm going to classify compound nouns into two types: those delimited by spaces (e.g. 'dry cleaning'), and non-delimited ones (e.g. 'bathroom'). Space-delimited ones are resolved by CFStringTokenizer as multiple tokens, while non-delimited ones are resolved as a single token.

For space-delimited compound nouns, looking up each consituent part is often enough to deduce the meaning: For example, the meaning of 'deputy head' is easy to infer from its parts. However, just as often, the meanings of the constituent parts are unhelpful (e.g. for words like 'vice principal'). In these cases, LinguaBrowse's online dictionaries provide linkes to entries for any compound nouns deriving from a looked-up word.

For undelimited compound nouns, at least in English, it is best to look up the whole word as-is. For example, the word 'greenhouse' can only be understood as its whole. However, an ability to define the constituent parts will often be of help to learners. No clearer is this fact than in German, where compound nouns can grow as long as 'Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz' (meaning the "law for the delegation of monitoring beef labelling")! Thus, we can handle them as follows:

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/german1.png" width="771" height="225" max-height="225" description="Compound noun handling (German)." %}

In this example, the user has the option of looking up the whole word as-is, or by its sub parts, which are each in dictionary form where available.

I also use NSLinguisticTagger in Japanese for some *katakana* compound nouns that MeCab fails to split properly (perhaps it uses a different dictionary to NSLinguisticTagger/CFStringTokenizer):

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/katakana.png" width="575" height="185" max-height="185" description="Compound noun handling (Japanese)" %}


### 2. Inflected words

#### What are inflected words?

An inflected word is one that may change its form to express a grammatical function/attribute such as tense, subject, mood, person, number, case, or gender. Examples common to many languages are:

* conjugated verbs

* inflected adjectives

* plural forms of nouns


<!-- Inflected words are troublesome to look up as-is because dictionaries don't provide a lookup key for every possible inflection of a word. Users may even lack the knowledge to convert an inflected word to dictionary form manually. A couple of examples from French:

* the phrase "je suis" ("I am") is sufficiently irregular that it is unrecognisably different from its dictionary form 'être' ("to be");

* the verb 'soit' looks like it might be the third-person form of a (fictional) verb 'soir', yet it is instead the subjunctive form of the aforementioned 'être'; -->

<!-- * In Japanese, verbs are sometimes written phonetically, without inclusion of a Chinese character to indicate which lemma they belong to, and therefore have to guess which the word might be out of many homophones. This is commonly so for the verb 'かかる' which, without context, could mean any out of 罹る, 掛かる, 懸かる, 斯かる, 架かる, 係る, 掛る, or 懸る (it's normally 掛かる, by the way!).

Actually, this last example can't be handled via NSLinguisticTagger (which so far doesn't support lemmatisation for Japanese, and in any case would require the whole sentence as context), but I've surmounted this problem in another way already, which I'll detail in a separate dev note regarding why I bundle the mecab tokeniser rather than using CFStringTokenizer for Japanese. -->

<!-- * knowing how to normalise a certain word may require knowledge of that word's etymology – English is composed of words from a great variety of languages (principally French, Latin, and Ancient Greek) with different conventions for inflecting, and thus case-by-case knowledge may be needed to handle each word (if encountering the word 'octopodes' in English for the first time, it may require intuitive familiarity with conjugation patterns of Greek-derived words to recognise that it is the plural of 'octopus' rather than, say, 'octopode'). -->

#### How should they be processed to aid dictionary lookup?

For most cases, the simple answer is to just return the lemma given by NSLinguisticTagger. And if NSLinguisticTagger doesn't support lemmatisation for the given language, then we'll just have to look up the word as-is and hope the dictionary can give us a best-effort result.

However, a radical option does exist: Bundle your own extra lemmatisers into the app. I've done so for Japanese and Korean, with MeCab. While it was traditionally developed for Japanese tokenisation, I found a project to [adapt MeCab for Korean usage](https://bitbucket.org/eunjeon/mecab-ko), I incorporated the code into [my own fork](https://github.com/shirakaba/iPhone-libmecab/tree/korean) of an iOS wrapper for MeCab. I have lofty dreams of incorporating lemmatisers for every language under the sun, but for now, it's a stretch goal.

<!-- In non-agglutinative languages (i.e. languages with spaces delimiting all non-compound words), the handling is intuitive: each inflected word simply maps to a token.

In agglutinative languages (i.e. languages without any delimiting punctuation between words, like Thai, Chinese, and Japanese), the handling is the same, but we need a better definition of what a 'word' means. I can't comment on Thai, and Chinese doesn't have inflected words, but for Japanese, each Short Unit Word, as defined in [Maekawa et al., 2014 – Balanced corpus of contemporary written Japanese](https://link.springer.com/article/10.1007/s10579-013-9261-0), is mapped to a token. A very nice visual introduction to the topic of Short Unit Words vs. Long Unit Words is given in [Tanaka et al., 2016 – Universal Dependencies for Japanese](http://www.lrec-conf.org/proceedings/lrec2016/pdf/122_Paper.pdf).

In both cases, while the token contains a logical word, it would not be in dictionary form and thus would risk failing lookup. -->

<!-- #### How are they now handled by NSLinguisticTagger's second pass?

From iOS 11, NSLinguisticTagger purports to supports lemmatisation (provision of dictionary forms for inflected words) for English, French, Italian, German, Spanish, Portuguese, Russian, and Turkish. LinguaBrowse also bundles a tokeniser, mecab, to extend such support to Korean and Japanese – although in the latter case, I introduced it long before this update and hard-coded it to just search the dictionary form pre-emptively (historically because no iOS system dictionary for Japanese provides lemmatisation, so there's never any use in searching the inflected form). -->

So now, when tapping on an inflected word, users are given the opportunity to look it up either as-is, or by its lemma (whenever NSLinguisticTagger can determine it). A plethora of examples from English, all superimposed into one image:

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/superimposition.png" width="640" height="1136" max-height="600" description="Inflected word handling for several use cases (superimposed image; in real usage, only one tooltip would be displayed at a time)." %}

<!-- {% include blog-width-limited-image.html url="2018-01-28-word-post-processing/plural.png" width="1095" max-width="480" height="236" description="Plurals handling" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/pp.png" width="1088" height="190" max-width="480" description="Conjugation handling (past participle)" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/pt.png" width="1083" height="222" max-width="480" description="Conjugation handling (past tense)" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/gerund.png" width="1063" max-width="480" height="254" description="Conjugation handling (gerunds)" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/conjugation.png" width="1101" max-width="480" height="247" description="Conjugation handling (present tense)" %} -->

### 3. Contractions

#### What is a contraction?

A contraction is when a word is shortened from its original form, usually mirroring how the word is spoken in practice. English is chock-full of these:

* "shoulda" ➡ "should have"
* "gotta" ➡ "got to"
* "it's" ➡ "it is"
* "let's" ➡ "let us"
* "they're" ➡ "they are"
* "y'all" ➡ "you all"
* "fish 'n' chips" ➡ "fish and chips"

The definite articles of French and Italian also induce a lot of this:

* French: "l'occasion" ➡ "la occasion"
* French: "l'aspect" ➡ "le aspect"
* Italian: "l'occasione" ➡ "la occasione"
* Italian: "l'aspetto" ➡ "lo aspetto"


A significant problem to learners here is that this obscures the gender of the noun, preventing one from learning how to use the word in other contexts.

I'm focusing just on contractions in languages with Latin scripts here, but I'll touch upon those of non-Latin script languages at the end.

#### How should they be processed to aid dictionary lookup?

While most English contractions will be listed in a dictionary as-is (due to them being an accepted form of the word), contractions based on definite articles, such as those common in Italian and French, will often have the definite articles omitted. Instead, the dictionaries may just categorise the word as 'masculine' or 'feminine'. So only a forgiving dictionary would facilitate lookup of such words.

Thanks to NSLinguisticTagger, we can now separate definite-article contractions into their parts, allowing search by part of the word. Regrettably, NSLinguisticTagger does *not* lemmatise "l'" back to its full form 'le' or 'la' to show gender, but *it sure would be nice to add by some other means in future*.

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/contraction.png" width="611" height="175" max-height="175" description="Contractions handling" %}

#### What about languages with non-Latin scripts?

Contractions look rather different in languages with non-Latin scripts, and pose different problems to text processing. I'll introduce contractions in two different agglutinative languages, Japanese and Chinese, then comment on how they should be both handled.

##### Japanese

Japanese contractions are pretty commonplace due to Japanese having a phonetic alphabet.

* やっぱり ➡ やっぱ

* 何だと言って／何で有っても ➡ 何だって

* ありがとうございます ➡ あざす

* Many nouns, as listed in this [utterly uncited article](https://en.wikipedia.org/wiki/Japanese_abbreviated_and_contracted_words)

##### Chinese

Chinese contractions are harder to come by because, as far as I gather, they exist only within slang. Lacking a dedicated phonetic alphabet (apart from [Bopomofo](https://en.wikipedia.org/wiki/Bopomofo), which is not used stand-alone), Chinese does not lend itself well to phonetic contractions. Nonetheless, they do exist.

[These examples](http://web.archive.org/web/20170708194353/http://chinesehacks.com/vocabulary/syllable-contractions/) are predominantly from Taiwan Mandarin, and may be restricted to net-speak:

* 知道 (zhīdào) ➡ 造 (zào)

<!-- * 时候 (shíhòu) ➡ 兽 (shòu) -->

<!-- * 我一直 (wǒ yīzhí) ➡ 伟直 (wěi zhí) -->

* 什么时候 (shénme shíhòu) ➡ 神兽 (shénshòu)

* 我会 (wǒ huì) ➡ 伟 (wěi)

* 今天 (jīntiān) ➡ 间 (jiān)

[These ones](http://languagelog.ldc.upenn.edu/nll/?p=3330) are perhaps historical:

* [圕](https://en.wiktionary.org/wiki/圕) (tuān) ➡ 图书馆 (túshūguǎn)

* [千克](https://en.wiktionary.org/wiki/兛) (qiānkè) ➡ 兛 (qiānkè)

* [千瓦](https://en.wiktionary.org/wiki/瓩) (qiānwǎ) ➡ 瓩 (qiānwǎ)

In both these languages' cases, handling of the contractions requires both a well-trained tokeniser (to correctly identify the word boundary and ideally produce the dictionary form) and a good dictionary (to correctly interpret the word when looked up); there's not much more that can be done on the developer's end if relying upon just CFStringTokenizer and NSLinguisticTagger. At best, I could try to upgrade my MeCab's Japanese dictionary from NAIST's JDic to NINJAL's [UniDic](http://pj.ninjal.ac.jp/corpus_center/unidic/) (which is trained on a monstrously larger corpus<sup>[\[1\]](https://link.springer.com/article/10.1007/s10579-013-9261-0)[\[2\]](http://pj.ninjal.ac.jp/corpus_center/bccwj/en/)</sup>).

Realistically, though, I think we'll be able to live without special handling for such contractions! There will always be cases where the user will have to pick up slack for automatic study tools, and this is one of the less criminal ones.

### Wrap-up

Hopefully this real-world application has given some clarity about the overlapping use cases of CFStringTokenizer and NSLinguisticTagger, and exposed a few intriguing aspects of different languages.

If you liked this dev note, you can get notified of future ones (and progress updates on LinguaBrowse) at:

* [Reddit](http://www.reddit.com/r/LinguaBrowse)

* [Twitter](https://twitter.com/LinguaBrowse?lang=en)

* [Facebook](https://www.facebook.com/LinguaBrowse)

