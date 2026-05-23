#!/bin/sh

toolkit="$HOME/toolkit"
vulkit="$HOME/vulkit"
onyx="$HOME/onyx"

convoy="$HOME/convoy/src"
feach="$convoy/for_each.py"
args="--ignore-cmd-errors -v -y -d"

python "$feach" $args "$toolkit" "$vulkit" "$onyx" -n -c "cp $convoy/convoy.py ."
python "$feach" $args "$toolkit" -c "cp $convoy/codegen/parser.py $convoy/codegen/orchestrator.py $convoy/codegen/generator.py codegen/"
python "$feach" $args "$vulkit" -c "cp $convoy/codegen/generator.py codegen/"
python "$feach" $args "$onyx" -c "cp $convoy/codegen/generator.py codegen/"
