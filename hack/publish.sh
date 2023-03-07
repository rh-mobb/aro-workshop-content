#!/bin/bash

set -eox

TEMP=$(mktemp -d)
BRANCH=$(git branch --show-current)

cd "${TEMP}"
git clone git@github.com:rh-mobb/workshop.git --branch main --single-branch workshop
cd workshop



#./virtualenv/bin/mkdocs gh-deploy -m "Manual update of gh-pages" -b gh-pages --force -v
