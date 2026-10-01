#!/bin/sh
# Stage only the public site. README and DEPLOY.md stay out of Pages.
set -e
cd "$(dirname "$0")"
rm -rf dist
mkdir -p dist/legal
cp index.html legal.html thanks.html robots.txt _redirects _headers dist/
cp legal/index.html dist/legal/index.html
