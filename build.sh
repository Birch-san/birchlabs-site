#!/usr/bin/env sh
# container_gem_cache ensures that the container need not run bundle install on every startup
exec docker run -it --rm --init \
--name jekyll_build \
-v "$PWD/src":/srv/jekyll:delegated \
-v "$PWD/container_gem_cache":/usr/local/bundle:delegated \
`#-v "$HOME/git/jekyll-postfiles":/jekyll-postfiles:delegated` \
-v "$PWD/dist":/dist:delegated \
jekyll/jekyll:3.8.5 jekyll build -d /dist