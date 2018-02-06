---
layout: post
title:  "Looking up non-dictionary form words in thirty languages"
date:   2018-01-28 14:16:43 -0000
categories: blog Jamie LinguaBrowse
syntax_highlight: true
author: Jamie Birch
---

## Introduction

### The web browser for foreign languages: LinguaBrowse

**LinguaBrowse** is a free iOS app for reading native-level foreign-language texts (in any of around 30 languages) on the internet. It allows users to look up any unknown word on a web-page simply by tapping on it – no more wrestling with selection boxes and switching to external dictionary apps. It works by processing the text of a page into tokens using Apple's [CFStringTokenizer](https://developer.apple.com/documentation/corefoundation/cfstringtokenizer-rf8) (except for Japanese and Korean, for which I use [mecab](https://github.com/shirakaba/iPhone-libmecab/tree/korean) – but that's a whole other story), then effectively making each token into a tappable button.

In previous versions, word lookup might fail due to the looked-up token not being in dictionary form. This issue was partially hidden because some of the iOS system dictionaries can handle non-dictionary form words by virtue of having a built-in lemmatiser (Oxford dictionaries use what they call their [Lemmatron](https://developer.oxforddictionaries.com/documentation?__prclt=OId2cMb0)). However, as a developer, I cannot depend upon this:

* most language pairs don't have system dictionaries – all bilingual system dictionaries are based on English, so, for example, there is no French ↔ Spanish dictionary for French speakers learning Spanish;

* even if a system dictionary is available, there is no guarantee that the user has installed one for their system.

From **LinguaBrowse** v1.3.1, users can now tap non-dictionary form words without the lookup failing, as post-processing is performed on the word by Apple's [NSLinguisticTagger](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSLinguisticTagger_Class/), which is more aggressive at tokenising and can thus break up words into further sub-parts. Whenever an inflected word or compound noun is tapped, a tooltip will appear to allow users to look up the word as-is, or by its dictionary form (where available – this is an [iOS 11 addition](https://developer.apple.com/videos/play/wwdc2017/208/) to its capabilities, affecting English, French, Italian, German, Spanish, Portuguese, Russian, and Turkish), or sub-part (where appropriate).

### Looking up non-dictionary form words

Non-dictionary form words are everywhere, as I demonstrate by showing all the tooltips that **LinguaBrowse** would present for eight separate instances of non-dictionary form words in a single page of an arbitrary Wikipedia article:

{% include blog-height-limited-image.html url="2018-01-28-word-post-processing/superimposition.png" width="640" height="1136" max-height="600" description="(Superimposed image of eight separate use cases; in real usage, only one tooltip would be shown at a time) LinguaBrowse can now handle all manner of conjugations, contractions, and other grammatical features that would otherwise impede dictionary lookup of a word." %}

By selecting the dictionary form that appears in the tooltip after tapping a word, we can choose to look up that form instead. Thus, we get a far more informative dictionary definition than had we been forced to look it up by its inflected form:

{% include blog-image.html url="2018-01-28-word-post-processing/lookup_50.png" width="1125" height="665" description="Comparison between dictionary definitions on Glosbe (https://glosbe.com) given for the inflected form of a word (left), which at best is able to provide a Google translation, and the dictionary form (right), which is able to directly provide high-quality definitions and other useful information." %}

This new addition is a big milestone and will significantly enhance support for pretty much every language in **LinguaBrowse**'s catalogue except for the Chinese languages (Mandarin and Cantonese compound nouns are handled sufficiently well by the initial tokenising pass, and their verbs and adjectives simply don't inflect!).


## Processing of non-dictionary form words, in detail

### Introduction

I'd like to highlight a few of the troublesome grammatical features across different languages that it will improve dictionary lookup support for, picking a few languages for context:

1. [compound nouns](#compound-nouns) (*w.r.t.* German and Japanese)

2. [inflected words](#inflected-words) (*w.r.t.* French and English)

3. [contractions](#contractions) (*w.r.t.* French, English, Italian, Japanese, and Chinese)

### 1. Compound nouns

#### What are compound nouns?

Compound nouns are nouns made by combining together multiple words. In English, there are many ways to create them, and they needn't even contain any nouns. For example:

* 'bath' + 'room' = 'bathroom' (noun + noun)

* 'small' + 'talk' = 'small talk' (adjective + noun)

* 'hair' + 'cut' = 'haircut' (noun + verb)

* 'dry' + 'cleaning' = 'dry cleaning' (adjective + verb)

* 'draw' + 'back' = 'drawback' (verb + preposition)

#### How were they handled by the initial pass with CFStringTokenizer?

For space-delimited compound nouns (e.g. 'deputy head'), CFStringTokenizer doesn't resolve the compound as a single token. This is not ideal for dictionary lookup: although in many cases, one can infer the meaning of the compound by combining the constituent meanings of each word  (e.g. 'deputy head' is easily understood by its parts 'deputy' and 'head'), one cannot do so for all words (e.g. for words like 'vice principal'). This is of some concern to me, but given that there aren't any trivial options to surmount this – the easiest one involving connecting to an online dictionary API in each language to check whether any words following the selected one could form a compound – I think that users can live with this occasional inconvenience.

For undelimited compound nouns (ones without spaces between words, e.g. 'greenhouse'), CFStringTokenizer treats the whole word as a single token, and this is generally desirable; searching 'greenhouse' in a dictionary as-is will return a useful result, and in fact, searching by its constituent parts – whilst etymologically interesting – would actually give a misleading meaning.

In English, undelimited compound nouns are mainly formed over time due to the ubiquity of a space-delimited equivalent (e.g. 'web site' becoming 'website' by nature of the pair of words being so common together) and this birth from ubiquity prevents the chains of undelimited words becoming too long. Thus, one can reasonably expect dictionaries to cover the vast majority of them. In German, however, undelimited compound nouns can be constructed without any such precedent, with even more grammatical flexibility, and without any hard limit on the number of constituent words; so much so that no dictionary could practically cover all their possible combinations. As an example, the longest authentic word in German is purportedly 'Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz', which means the "law for the delegation of monitoring beef labelling"! With CFStringTokenizer alone, we can't break up this compound into its sub-words, so we're at the mercy of our dictionary (which will need to lemmatise the word itself).

#### How are they now handled by NSLinguisticTagger's second pass?

While NSLinguisticTagger doesn't break up undelimited compound nouns in English (as stated before, this would only be of etymological interest, rather than being of practical use in looking up the definition), it *does* do so for German, which aids word lookup immensely:

<!-- {% include blog-image.html url="2018-01-28-word-post-processing/german1.png" description="Compound noun handling (German). To my best understanding, this is the correct way to split up the word 'Straßenbahnkrawalle' into its constituent dictionary forms. Keen-eyed readers may notice that these options are presented all in lower case despite capital letters conveying meaning in German. This behaviour is down to a possible Cocoa frameworks bug that I never got to the bottom of, wherein NSMutableOrderedSet seems to ignore custom 'Hashable' and 'Equatable' methods – it's a long story – that's the correct data structure for the job, so for now, I regrettably won't be improving upon the situation. Although it may confuse users a little bit, it has no impact on dictionary lookup, as all LinguaBrowse dictionaries are case-insensitive." %} -->

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/german1.png" width="771" height="225" max-width="480" description="Compound noun handling (German)." %}

The menu presented gives the user the option of looking up: firstly, the full word (in case they really do want to try looking up the holistic definition); then, each subsequent distinct sub-part. All sub-parts are provided in dictionary form wherever possible (NSLinguisticTagger only supports lemmatisation from iOS 11, and even then, it's rather hit-or-miss in practice), or at least provided as-is (i.e. the 'stem', which is extracted much more reliably and is available to older versions of iOS).

#### So does this only help for German?

German is not the only language featuring unspaced compound nouns. Agglutinative languages, such as Japanese, Chinese, and Thai, lack spaces altogether, so their compound nouns are implicitly unspaced, and determining where to split them up is a real challenge. I can't comment on Thai (I don't speak a word of it!), but my first-pass processing with CFStringTokenizer (for Chinese) and [mecab](https://github.com/shirakaba/iPhone-libmecab/tree/korean) (for Japanese) did actually identify the word boundaries in Japanese and Chinese very competently to begin with. However, post-processing still serves a purpose in Japanese, as I found that any words written in *katakana* (a script principly used for transcribing loan words) were mistakenly being interpreted by mecab as single, continuous words (interestingly, CFStringTokenizer – which I had thought was simply a more locked-down implementation of mecab, because Apple has indeed been using mecab under the hood since at least Mac OS 10.5 <sup>[[1]](https://web.archive.org/web/20160305113404/http://chasen.org/~taku/blog/archives/2008/07/mac_os_x_leropa.html)[[2]](https://web.archive.org/web/20170708060425/http://d.hatena.ne.jp:80/kazama/20080115/p1)</sup> – *does* break them up correctly). Now, words like メディアセンター (メディア + センター; 'media' + 'centre') can be looked up piece-by-piece:

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/katakana.png" width="575" height="185" max-width="480" description="Compound noun handling (Japanese)" %}

### 2. Inflected words

#### What are inflected words?

An inflected word is one that may change its form to express a grammatical function/attribute such as tense, subject, mood, person, number, case, or gender. Inflected words are troublesome to look up as-is because dictionaries don't provide a lookup key for every possible inflection of a word. Users may even lack the knowledge to convert an inflected word to dictionary form manually. A couple of examples from French:

* the phrase "je suis" ("I am") is sufficiently irregular that it is unrecognisably different from its dictionary form 'être' ("to be");

* the verb 'soit' looks like it might be the third-person form of a (fictional) verb 'soir', yet it is instead the subjunctive form of the aforementioned 'être';

<!-- * In Japanese, verbs are sometimes written phonetically, without inclusion of a Chinese character to indicate which lemma they belong to, and therefore have to guess which the word might be out of many homophones. This is commonly so for the verb 'かかる' which, without context, could mean any out of 罹る, 掛かる, 懸かる, 斯かる, 架かる, 係る, 掛る, or 懸る (it's normally 掛かる, by the way!).

Actually, this last example can't be handled via NSLinguisticTagger (which so far doesn't support lemmatisation for Japanese, and in any case would require the whole sentence as context), but I've surmounted this problem in another way already, which I'll detail in a separate dev note regarding why I bundle the mecab tokeniser rather than using CFStringTokenizer for Japanese. -->

<!-- * knowing how to normalise a certain word may require knowledge of that word's etymology – English is composed of words from a great variety of languages (principally French, Latin, and Ancient Greek) with different conventions for inflecting, and thus case-by-case knowledge may be needed to handle each word (if encountering the word 'octopodes' in English for the first time, it may require intuitive familiarity with conjugation patterns of Greek-derived words to recognise that it is the plural of 'octopus' rather than, say, 'octopode'). -->

#### How were they handled by the initial pass with CFStringTokenizer?

In non-agglutinative languages (i.e. languages with spaces delimiting all non-compound words), the handling is intuitive: each inflected word simply maps to a token.

In agglutinative languages (i.e. languages without any delimiting punctuation between words, like Thai, Chinese, and Japanese), the handling is the same, but we need a better definition of what a 'word' means. I can't comment on Thai, and Chinese doesn't have inflected words, but for Japanese, each Short Unit Word, as defined in [Maekawa et al., 2014 – Balanced corpus of contemporary written Japanese](https://link.springer.com/article/10.1007/s10579-013-9261-0), is mapped to a token. A very nice visual introduction to the topic of Short Unit Words vs. Long Unit Words is given in [Tanaka et al., 2016 – Universal Dependencies for Japanese](http://www.lrec-conf.org/proceedings/lrec2016/pdf/122_Paper.pdf).

In both cases, while the token contains a logical word, it would not be in dictionary form and thus would risk failing lookup.

#### How are they now handled by NSLinguisticTagger's second pass?

From iOS 11, NSLinguisticTagger purports to supports lemmatisation (provision of dictionary forms for inflected words) for English, French, Italian, German, Spanish, Portuguese, Russian, and Turkish. LinguaBrowse also bundles a tokeniser, mecab, to extend such support to Korean and Japanese – although in the latter case, I introduced it long before this update and hard-coded it to just search the dictionary form pre-emptively (historically because no iOS system dictionary for Japanese provides lemmatisation, so there's never any use in searching the inflected form).

So now, when tapping on an inflected word, users are given the opportunity to look it up either as-is, or by its lemma (whenever NSLinguisticTagger can determine it). A plethora of examples from English:

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/plural.png" width="1095" max-width="480" height="236" description="Plurals handling" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/pp.png" width="1088" height="190" max-width="480" description="Conjugation handling (past participle)" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/pt.png" width="1083" height="222" max-width="480" description="Conjugation handling (past tense)" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/gerund.png" width="1063" max-width="480" height="254" description="Conjugation handling (gerunds)" %}

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/conjugation.png" width="1101" max-width="480" height="247" description="Conjugation handling (present tense)" %}

### 3. Contractions

#### What is a contraction?

A contraction is when a word is shortened from its original form, usually mirroring how the word is spoken in practice. English is chock-full of these: "it's" ("it is"), "let's" ("let us"), "they're" ("they are"), "y'all" ("you all"), "fish 'n' chips" ("fish and chips"), and so on. The first-person pronoun of French also induces a lot of this ("l'occasion" – "la occasion", and "l'aspect" – "le aspect"), as does that of Italian ("l'occasione" – "la occasione"; "l'aspetto" – "lo aspetto"), both obscuring the gender of the noun. I'm focusing just on contractions in languages with Latin scripts here, but I'll touch upon those of non-Latin script languages at the end.

#### How were they handled by the initial pass with CFStringTokenizer?

The whole contraction, e.g. "it's", would be regarded as a single token. While most English contractions would be listed in a dictionary, Italian and French dictionaries will typically omit the "l'" from the lookup key in favour of categorising it as 'masculine' or 'feminine'. So only a forgiving dictionary (like Glosbe) would facilitate lookup of such words.

#### How are they now handled by NSLinguisticTagger's second pass?

Now, one can choose to input just the noun, removing the contraction. Regrettably, NSLinguisticTagger does not lemmatise "l'" back to its full form 'le' or 'la' to show gender, but *it sure would be nice to add by some other means in future*.

{% include blog-width-limited-image.html url="2018-01-28-word-post-processing/contraction.png" width="611" height="175" max-width="480" description="Contractions handling" %}

#### What about languages with non-Latin scripts?

Contractions look rather different in languages with non-Latin scripts. In my examples from Japanese and Chinese, they don't exhibit any of the same regularity and ubiquity (making them less of a common problem to surmount), and don't necessarily pose a great problem to tokenisation, nor interfere with word lookup.

##### Japanese 

Japanese has quite a few contractions:

* やっぱ (from やっぱり, or more strictly 矢っ張り)

* 何だって (from 何だと言って or 何で有っても)

* あざす (from ありがとうございます)

* I suspect 'こんな' comes from 'このような'!

These are tokenised differently on a case-by-case basis, whether by CFStringTokenizer or by mecab: sometimes they'll break up the word into sub-parts ('何だって' breaks into '何' and 'だって'), and other times they'll recognise the full word (as with 'やっぱ') – it fully depends on how the word was handled in the tokeniser's training set (if indeed at all, given how colloquial some of them are). But whether the tokenisation leaves you with sub-parts or the full word, it's usually enough to get a decent term for a dictionary search.

 The only improvement I could make upon this would be to upgrade mecab from using Naist's JDic dictionary to the superior Unidic (which has first-class lemmatisation support and uses a monstrously larger corpus). However, I'd need a spare month (and ideally a Japanese-speaking C++ programmer to consult) to even attempt this upgrade, and I don't even know what Unidic's licensing is.

##### Chinese

Fascinatingly, I found that Chinese [has contractions](http://web.archive.org/web/20170708194353/http://chinesehacks.com/vocabulary/syllable-contractions/) too! Here are some examples from the linked article, which I must note focuses on Taiwan Mandarin and references webspeak, but nonetheless:

* 知道 (zhīdào) -> 造 (zào)

* 时候 (shíhòu) -> 兽 (shòu)

* 我一直 (wǒ yīzhí) -> 伟直 (wěi zhí)

* 什么时候 (Shénme shíhòu) -> 神兽 (shénshòu)

* 我会 (Wǒ huì) -> 伟 (wěi)

* 今天 (jīntiān) -> 间 (jiān)

I don't know to what degree each of these examples are colloquial/slang or are limited to Taiwan Mandarin (although I do believe that at least 圕, a three-syllable contraction of 图书馆, is acceptable in 'standard', i.e. Beijing, Mandarin), and so the question of whether they are handled well falls down to:

* how well CFStringTokenizer can discern where to place its word boundaries (which depends upon the training set that it was originally trained upon – most likely not a 'net speak' corpus – and the other words that happen to be found amongst it in the target sentence, making this a difficult question to answer definitively);

* the quality of the dictionary used, to explain that the word may have an alternative meaning to its canonical ones if being employed as a contraction.

In any case, I suspect that this case would be too niche to need handling in practice.

### Wrap-up

Hopefully this real-world application has given some clarity about the overlapping use cases of CFStringTokenizer and NSLinguisticTagger, and exposed a few intriguing aspects of different languages.

If you liked this dev note, you can get notified of future ones (and progress updates on LinguaBrowse) at:

* [Reddit](http://www.reddit.com/r/LinguaBrowse)

* [Twitter](https://twitter.com/LinguaBrowse?lang=en)

* [Facebook](https://www.facebook.com/LinguaBrowse)

