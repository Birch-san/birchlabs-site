#!/usr/bin/env sh
# container_gem_cache ensures that the container need not run bundle install on every startup
exec docker run -it --rm --init \
-v "$PWD/src":/srv/jekyll \
-v "$PWD/container_gem_cache":/usr/local/bundle \
-p 8087:4000 \
my/jekyll:3.7.0