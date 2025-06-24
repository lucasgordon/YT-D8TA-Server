#!/usr/bin/env bash

# Exit on error
set -o errexit

python3 -m venv venv
source venv/bin/activate

pip install -r requirements.txt

bundle install
rm -rf node_modules package-lock.json
npm install
bin/rails assets:precompile
bin/rails assets:clean