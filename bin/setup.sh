#!/bin/bash
set -e
# Cleanup incase script failed before.
rm libs -rf
git clone https://github.com/ChrisKader/libs/ libs
