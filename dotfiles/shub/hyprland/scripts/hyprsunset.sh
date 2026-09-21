#!/usr/bin/env bash
pkill -x hyprsunset || { hyprsunset -t 4500 & }
