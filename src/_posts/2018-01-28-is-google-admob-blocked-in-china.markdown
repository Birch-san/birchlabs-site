---
layout: post
title:  "Is Google AdMob blocked in China?"
date:   2018-01-28 14:16:44 -0000
categories: blog Jamie LinguaBrowse
syntax_highlight: true
author: Jamie Birch
---

# Background

There's a bit of mystery surrounding whether Google Ads are blocked in China or not (as the search engine itself and many of the other main services [certainly are](https://en.wikipedia.org/wiki/Websites_blocked_in_mainland_China)).

You can confirm for yourself by checking the up-to-date Greatfire.org results for the following URLs:

* [https://www.google.com](https://en.greatfire.org/https/www.google.com)

* [https://www.google.com/admob](https://en.greatfire.org/https/www.google.com/admob) (however, as this is the 'dashboard' URL, it may not actually be the same endpoint used by Admob ad services themselves).

## How about Chinese iOS ad networks?

I went to great efforts to research iOS ad providers operating in China, as they'd be guaranteed to work. I ideally wanted to find one that allowed me to reuse the current Google Admob framework that I'd gone to the effort of setting up already: [Reddit thread](https://www.reddit.com/r/iOSProgramming/comments/79apg5/update_what_should_i_do_about_providing_inapp_ads/?ref=share&ref_source=link). However, as I report in the thread, all services seem to require a Chinese ID, and most involve getting into direct contact with the advertising agency (rather unsettling for me).

# Investigation

As nobody was giving any satisfactory information on the subject, I decided take it into my own hands and make a TestFlight build of my app, [**LinguaBrowse**](https://itunes.apple.com/us/app/linguabrowse/id1281350165?mt=8), to have people test it in China. I got the help of three testers. Following the great results of the first test session, I released the app on the China App Store rather than just using TestFlight.

Evidence is documented in full in this [imgur album](https://imgur.com/a/MOUk1) (testers 1 & 2)
... and [this one](https://imgur.com/a/G7JCG) (tester 3), though I'll show some key images for flavour here anyway:

## Tester 1: using an iPhone with China Telecom on my TestFlight build

*Note: although this tester's carrier says 中国移动 (China Mobile), the tester believes that the WiFi in use is actually provided by China Telecom.*

* My banner ad appeared in portrait mode, and was able to automatically refresh with a new ad every two minutes (although I only got a screenshot of the first one, sorry). We did not test landscape mode.

* Ads appeared and refreshed regardless of whether VPN was off or on, so it gets past the Great Firewall without any ads being blocked.

* Of note, we were also able to view Google AdMob ads placed by other parties on websites that we visited, so it's not just in-app AdMob services that work, either.

{% include blog-height-limited-image.html width="640" height="1136" max-height="600" url="2018-01-28-is-google-admob-blocked-in-china/ct_iphone_portrait_without_vpn_success.jpg" description="China Telecom permitting a portrait-mode banner ad on iPhone." %}

## Tester 2: using an iPad with China Mobile on my App Store app

* As before, my banner ad appeared in portrait mode, and was able to automatically refresh with a new ad every two minutes (this time, I do have two separate photos as proof).

* I noticed later that my banner ad failed to receive ads in landscape mode (I set up my app to change the banner area's colour to red if `adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError)` is called). Since I only noticed this after concluding the test, I don't have any insight into why this happened. It may be just that the available advertisers weren't able to provide the right format of ad in time; not sure. I should note that landscape ads work just fine on an iPhone situated outside of China.

* We didn't test with VPNs.

{% include blog-height-limited-image.html width="1078" height="1596" max-height="600" url="2018-01-28-is-google-admob-blocked-in-china/cm_ipad_portrait_success.jpg" description="China Mobile permitting a portrait-mode banner ad on iPad." %}

## Tester 3: using an iPhone with China Unicom on my App Store app

* Portrait and landscape iPhone banner ads were blocked on China Unicom, yet worked over VPN.

{% include blog-height-limited-image.html width="728" height="1295" max-height="600" url="2018-01-28-is-google-admob-blocked-in-china/cu_iphone_portrait_error_without_vpn.jpg" description="China Unicom blocking a portrait-mode banner ad on iPhone (landscape was also blocked). Blockade was lifted immediately upon connecting to a VPN." %}

## Does the Google AdMob pane register any clicks?

I couldn't test this directly, as it's against the terms and conditions of Google AdMob to deliberately click on ads, so I had to wait a while for some data to come in. Coincident with a small number of downloads from the China App Store, Google AdMob pane does presently report (a small number of) click-throughs in China. Whether the clickers were using national Chinese internet providers (rather than VPNs), however, I don't know; and I also don't know whether they got their apps from the China App Store or any other nation's App Store (not that it makes any difference, though, I expect). However, I can say that the revenue is non-zero.

# Conclusion

Google AdMob works perfectly well in China for **two of the three** biggest ISPs (China Mobile and China Telecom), except *maybe* for landscape ads on iPad (requires further investigation to figure out exactly what was happening). However, it's completely blocked on the **third biggest provider**, China Unicom. For the former two ISPs, I have evidence now that ads display, refresh, and that click-throughs are registered in the Google AdMob pane. Whether the eCPM is decent is a whole different question, but I'll be watching my numbers. Hope this helps conclude a question that has been bouncing around unanswered, and with an awful lot of misinformation, since at least 2014.