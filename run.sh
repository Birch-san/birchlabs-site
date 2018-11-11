#!/usr/bin/env sh
# container_gem_cache ensures that the container need not run bundle install on every startup
exec docker run -it --rm --init \
--name jekyll_run \
-v "$PWD/src":/srv/jekyll:delegated \
-v "$PWD/container_gem_cache":/usr/local/bundle:delegated \
`#-v "$HOME/git/jekyll-postfiles":/jekyll-postfiles:delegated` \
-v "$PWD/dist":/dist:delegated \
-p 8087:4000 \
-p 35729:35729 \
-p 3000:3000 \
jekyll/jekyll:3.8.4 jekyll serve --livereload -d /dist