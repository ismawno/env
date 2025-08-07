#!/bin/bash

dirs="../toolkit ../vulkit ../onyx ../drizzle"

python src/for_each.py --ignore-cmd-errors -v -y -n -d $dirs -c "cp ../convoy/src/convoy.py ." "cp ../convoy/src/setup/build.py ../convoy/src/setup/cmake_scanner.py setup/"
python src/for_each.py --ignore-cmd-errors -v -y -d $dirs -c "python setup/cmake_scanner.py -p . -v"
python src/for_each.py --ignore-cmd-errors -v -y -d ../drizzle ../onyx -c "cp ../convoy/src/setup/setup.py ../convoy/src/setup/*install* setup/"
python src/for_each.py --ignore-cmd-errors -v -y -d ../toolkit -c "cp ../convoy/src/codegen/cpp/parser.py ../convoy/src/codegen/cpp/orchestrator.py ../convoy/src/codegen/cpp/generator.py ../convoy/src/codegen/cpp/reflect.py ../convoy/src/codegen/cpp/serialize.py codegen/cpp/"
python src/for_each.py --ignore-cmd-errors -v -y -d ../vulkit -c "cp ../convoy/src/codegen/cpp/generator.py ../convoy/src/codegen/cpp/vkloader.py codegen/cpp/"
if [ ! -z "$1" ]; then
    git add .
    git commit -m "$1"
    python src/for_each.py --ignore-cmd-errors -v -y -n -d $dirs -c "git add convoy.py setup/" "git commit -m \"$1\"" "git push"
    python src/for_each.py --ignore-cmd-errors -v -y -n -d ../toolkit -c "git add codegen/" "git commit -m \"$1\"" "git push"
fi
