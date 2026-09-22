#!/usr/bin/env bash
pkill -u "$UID" -x hyprsunset || { hyprsunset -t 4500 & }
