#!/bin/sh
set -e

mkdir -p tmp/pids

bundle exec rails db:migrate

exec bundle exec puma -C config/puma.rb
