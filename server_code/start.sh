#!/bin/bash

if [ ! -e "Gemfile.lock" ]; then
  bundle install
fi

bundle exec puma -b 'ssl://127.0.0.1:9292?key=server.key&cert=server.crt'
