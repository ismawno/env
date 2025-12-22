#!/bin/sh

toolkit="$HOME/toolkit"
vulkit="$HOME/vulkit"
vulkit="$HOME/onyx"

convoy="$HOME/convoy/src"
feach="$convoy/for_each.py"
args="--ignore-cmd-errors -v -y -d"

python "$feach" $args "$toolkit" "$vulkit" -n -c "cp $convoy/convoy.py ."
python "$feach" $args "$toolkit" "$vulkit" -n -c "cp $convoy/codegen/cpp/generator.py codegen/cpp/"
python "$feach" $args "$toolkit" -c "cp $convoy/codegen/cpp/parser.py $convoy/codegen/cpp/orchestrator.py codegen/cpp/"
