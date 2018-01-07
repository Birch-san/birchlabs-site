#!/usr/bin/env sh
# container_gem_cache ensures that the container need not run bundle install on every startup
exec docker run -it --rm --init \
-v "$PWD/src":/srv/jekyll:delegated \
-v "$PWD/container_gem_cache":/usr/local/bundle:delegated \
-v "$PWD/dist":/dist \
my/jekyll:3.7.0 jekyll build \
-d /dist