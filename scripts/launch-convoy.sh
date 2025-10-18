#!/bin/sh

toolkit="$HOME/toolkit"
vulkit="$HOME/vulkit"

convoy="$HOME/convoy/src"
feach="$convoy/for_each.py"
args="--ignore-cmd-errors -v -y -d"

python $feach $args $toolkit $vulkit -n -c "cp $convoy/convoy.py ."
python $feach $args $toolkit -c "cp $convoy/codegen/cpp/parser.py $convoy/codegen/cpp/orchestrator.py $convoy/codegen/cpp/generator.py $convoy/codegen/cpp/reflect.py $convoy/codegen/cpp/serialize.py codegen/cpp/"
python $feach $args $vulkit -c "cp $convoy/codegen/cpp/generator.py $convoy/codegen/cpp/vkloader.py codegen/cpp/"

