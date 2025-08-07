#!/bin/bash

toolkit="$HOME/toolkit"
vulkit="$HOME/vulkit"
onyx="$HOME/onyx"
drizzle="$HOME/drizzle"
env="$HOME/env"
projects="$toolkit $vulkit $onyx $drizzle"

convoy="$HOME/convoy/src"
feach="$convoy/for_each.py"
args="--ignore-cmd-errors -v -y -d"

python $feach $args $projects -n -c "cp $convoy/convoy.py ." "cp $convoy/setup/build.py $convoy/setup/cmake_scanner.py setup/"
python $feach $args $drizzle $onyx -c "cp $convoy/setup/setup.py $convoy/setup/*install* setup/"
python $feach $args $toolkit -c "cp $convoy/codegen/cpp/parser.py $convoy/codegen/cpp/orchestrator.py $convoy/codegen/cpp/generator.py $convoy/codegen/cpp/reflect.py $convoy/codegen/cpp/serialize.py codegen/cpp/"
python $feach $args $vulkit -c "cp $convoy/codegen/cpp/generator.py $convoy/codegen/cpp/vkloader.py codegen/cpp/"
python $feach $args $projects -c "python setup/cmake_scanner.py -p . -v"
# python $feach $args $env -c "cp $convoy/convoy.py scripts/"
if [ ! -z "$1" ]; then
    git add .
    git commit -m "$1"
    python $feach $args $projects -n -c "git add convoy.py setup/" "git commit -m \"$1\"" "git push"
    python $feach $args $toolkit -n -c "git add codegen/" "git commit -m \"$1\"" "git push"
fi
