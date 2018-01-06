#!/usr/bin/env sh
# container_gem_cache ensures that the container need not run bundle install on every startup
exec docker run -it --rm --init \
-v "$PWD/src":/srv/jekyll:delegated \
-v "$PWD/container_gem_cache":/usr/local/bundle:delegated \
-v "$PWD/dist":/dist \
-p 8087:4000 \
-p 35729:35729 \
-p 3000:3000 \
my/jekyll:3.7.0 jekyll serve --livereload --incremental \
-d /dist