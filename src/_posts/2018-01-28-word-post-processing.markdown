---
layout: post
title:  "Word post-processing"
date:   2018-01-28 14:16:43 -0000
categories: blog Jamie LinguaBrowse
syntax_highlight: true
author: Jamie Birch
---


**LinguaBrowse** v1.3.1 saw the release of the word post-processing feature. This enables two things:

* Splitting a word into its constituent grammatical parts.

* Reducing a conjugated word back to its dictionary form.

This new addition is a big milestone and will significantly aid the study of pretty much every language supported except Chinese languages (eg. Mandarin and Cantonese – a fact I shall [touch on briefly](#the-special-case-of-chinese-based-languages) at the end!). I'd like to highlight a few of the troublesome grammatical features across different languages that it will improve dictionary lookup support for, picking a few languages for context:

* [unspaced compound nouns](#unspaced-compound-nouns) (*w.r.t.* German and Japanese)

* [inflected words](#inflected-words) (*w.r.t.* French and English)

* [contractions](#contractions) (*w.r.t.* French, English, and Italian)

## Unspaced compound nouns

Compound nouns – or more particularly, 'unspaced' compound nouns, where each noun in the compound is not separated by spaces – are a really menacing language feature for learners of any level to have to deal with when trying to define them in a dictionary:

1. Long words are a pain to input into a dictionary.

2. Identifying the word boundaries within the whole compound can be hard.

3. Even knowing the word boundaries, the words within the compound may not be in a form suitable for dictionary input ('dictionary form').

German infamously features unspaced **compound nouns**. Purportedly, its longest *authentic* word is apparently 'Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz', which means the "law for the delegation of monitoring beef labelling".

In earlier versions of **LinguaBrowse**, tapping a German word would simply perform dictionary lookup upon the whole word. This is because – except for Japanese and Korean – I'd always used only Apple's [CFStringTokenizer](https://developer.apple.com/documentation/corefoundation/cfstringtokenizer-rf8) to initially process the text on a page, and they view German compound words as atomic. If you'd happened to have installed the system Oxford German ↔ English dictionary, you'd be okay, as it has a built-in lemmatiser (they call it the [Lemmatron](https://developer.oxforddictionaries.com/documentation?__prclt=OId2cMb0)) to handle non-dictionary form words (such as compound words), but its usefulness to students is neutered on iOS: the user gets no ability to browse based on the sub-part of each word (they're simply given a definition for the whole compound), so they have to guess how to join each English word in the definition back to its German counterpart in the dictionary entry.

*Now* I post-process words upon user tap using Apple's [`NSLinguisticTagger`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSLinguisticTagger_Class/), which is more aggressive at tokenising and can thus break up words into further sub-parts. The results are very satisfying:

{% include blog-image.html url="2018-01-28-word-post-processing/german1.png" description="Compound noun handling (German)" %}

The menu gives you the option of looking up, firstly, the full word, then each sub-part. All sub-parts are provided in dictionary form where possible (`NSLinguisticTagger` is rather hit-or-miss in practice), or at least provided as-is.

German is not the only language featuring unspaced compound nouns. Agglutinative languages, such as Japanese, Chinese, and Thai, lack spaces altogether, so their compound nouns are implicitly unspaced , and determining where to split them up is a real challenge. I can't comment on Thai (I don't speak a word of it!), but **LinguaBrowse** did actually process the word boundaries in Japanese and Chinese very competently to begin with. However, post-processing still serves a purpose in Japanese, as I found that any words written in *katakana* (a script principly used in loan words) had, upon tap, been being looked up as a single term up until this update. Now, words like メディアセンター (メディア + センター; 'media' + 'centre') can be looked up as a whole, or piece-by-piece:

{% include blog-image.html url="2018-01-28-word-post-processing/katakana.png" description="Compound noun handling (Japanese)" %}

## Inflected words

An inflected word is one that may change its form to express a grammatical function/attribute such as tense, subject, mood, person, number, case, or gender.

Inflected words pose a problem to language-learners because dictionaries don't provide a lookup key for every possible inflection of a word – readers have to first normalise the inflected words back to dictionary form before they can look them up. This can prove difficult, as:

* irregular words may inflect in unpredictable ways – in the French phrase "je suis" ("I am"), 'suis' is unrecognisably different from its dictionary form, 'être' ("to be");

* the particular grammar used may be beyond the student's level of knowledge – again, in French, although the verb 'soit' looks like it might be the third-person form of a (fictional) verb 'soir', it is instead the subjunctive form of the aforementioned 'être';

* knowing how to normalise a certain word may require knowledge of that word's etymology – English is composed of words from a great variety of languages (principally French, Latin, and Ancient Greek) with different conventions for inflecting, and thus case-by-case knowledge may be needed to handle each word (if encountering the word 'octopodes' in English for the first time, it may require intuitive familiarity with conjugation patterns of Greek-derived words to recognise that it is the plural of 'octopus' rather than, say, 'octopode').

In the initial versions of **LinguaBrowse**, no direct handling of inflected forms was performed whatsoever; it was entirely down to the dictionary to figure it out. However, this wasn't too disastrous, as some of the system dictionaries (certainly the Oxford ones) had built-in lemmatisation capability. Notably though, the Japanese one did not, so I did specially bundle a tokeniser for Japanese early on.

Things changed with iOS 11 (which was released about 3 months after **LinguaBrowse** first hit the App Store), as lemmatisation capabilities for `NSLinguisticTagger` were announced (affecting English, French, Italian, German, Spanish, Portuguese, Russian, and Turkish). In this update, I finally got around to implementing those.

So now, when tapping on an inflected word, users will be given the opportunity to look it up either as-is, or by its lemma (whenever `NSLinguisticTagger` can determine it):


{% include blog-image.html url="2018-01-28-word-post-processing/plural.png" description="Plurals handling" %}

{% include blog-image.html url="2018-01-28-word-post-processing/pp.png" description="Conjugation handling (past participle)" %}

{% include blog-image.html url="2018-01-28-word-post-processing/pt.png" description="Conjugation handling (past tense)" %}

{% include blog-image.html url="2018-01-28-word-post-processing/gerund.png" description="Conjugation handling (gerunds)" %}

{% include blog-image.html url="2018-01-28-word-post-processing/conjugation.png" description="Conjugation handling (present tense)" %}

## Contractions

A contraction is when a word is shortened from its original form, usually mirroring how the word is spoken in practice. English is chock-full of these: "it's" ("it is"), "let's" ("let us"), "they're" ("they are"), "y'all" ("you all"), "fish 'n' chips" ("fish and chips"), and so on. The first-person pronoun of French also induces a lot of this ("l'occasion" – "la occasion", and "l'aspect" – "le aspect"), as does that of Italian ("l'occasione" – "la occasione"; "l'aspetto" – "lo aspetto"), both obscuring the gender of the noun.

While before, tapping on a contracted word would input all of it into the dictionary, now one can choose to input just the noun, removing the contraction. Regrettably, `NSLinguisticTagger` does not lemmatise "l'" back to its full form "le" or "la", however, but *it sure would be nice to add by some other means in future*.

{% include blog-image.html url="2018-01-28-word-post-processing/contraction.png" description="Contractions handling" %}

## The special case of Chinese-based languages

I mentioned before that this post-processing helps for most languages, with the key exception of the Chinese language family (I'm familiar with only Mandarin, so hopefully what I say hereon in applies generally to other major members of the family such as Cantonese). Astonishingly, Chinese words do not inflect whatsoever, surprisingly making Chinese text the easiest to facilitate word lookup for. In fact, **LinguaBrowse** originally started with the name Pinyinjector, and was designed purely to help me read Mandarin (before the scope spiralled out of control to facilitate all pairs of major languages). I could certainly expend a lot of space here extolling the virtues of its ultra-lean grammar, but that's perhaps a story for a separate post!