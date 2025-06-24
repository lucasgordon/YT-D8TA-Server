#!/usr/bin/env bash

# Exit on error
set -o errexit

bundle install
rm -rf node_modules package-lock.json
npm install
pip install -r requirements.txt
bin/rails assets:precompile
bin/rails assets:clean