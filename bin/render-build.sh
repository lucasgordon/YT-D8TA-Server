#!/usr/bin/env bash

# Exit on error
set -o errexit

# Install Chrome for web scraping
STORAGE_DIR=/opt/render/project/.render

if [[ ! -d $STORAGE_DIR/chrome ]]; then
  echo "...Downloading Chrome"
  mkdir -p $STORAGE_DIR/chrome
  cd $STORAGE_DIR/chrome
  wget -P ./ https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  ar x google-chrome-stable_current_amd64.deb
  tar -xf data.tar.xz -C $STORAGE_DIR/chrome
  rm ./google-chrome-stable_current_amd64.deb
  cd $HOME/project/src # Make sure we return to where we were
else
  echo "...Using Chrome from cache"
fi

# Add Chrome to PATH
export PATH="${PATH}:/opt/render/project/.render/chrome/opt/google/chrome"

python3 -m venv venv
source venv/bin/activate

pip install -r requirements.txt

bundle install
rm -rf node_modules package-lock.json
npm install
bin/rails assets:precompile
bin/rails assets:clean