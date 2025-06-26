#!/usr/bin/env bash

# Exit on error
set -o errexit

bundle install
rm -rf node_modules package-lock.json
npm install

# Backup thumbnails directory before cleaning assets
if [ -d "public/thumbnails" ]; then
  echo "Backing up thumbnails directory..."
  cp -r public/thumbnails /tmp/thumbnails_backup
fi

bin/rails assets:precompile
bin/rails assets:clean

# Restore thumbnails directory after cleaning assets
if [ -d "/tmp/thumbnails_backup" ]; then
  echo "Restoring thumbnails directory..."
  rm -rf public/thumbnails
  mv /tmp/thumbnails_backup public/thumbnails
fi