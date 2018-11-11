#!/usr/bin/env sh
# container_gem_cache ensures that the container need not run bundle install on every startup
exec docker run -it --rm --init \
--name jekyll_gem \
-v "$PWD/src":/srv/jekyll:delegated \
-v "$PWD/container_gem_cache":/usr/local/bundle:delegated \
`#-v "$HOME/git/jekyll-postfiles":/jekyll-postfiles:delegated` \
jekyll/jekyll:3.8.4 bundle