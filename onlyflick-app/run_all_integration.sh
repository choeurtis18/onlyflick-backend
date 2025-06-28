#!/bin/bash

echo "Running all integration tests..."

for file in integration_test/*.dart; do
  echo "Running $file"
  flutter drive --driver=integration_test/driver.dart --target="$file" -d chrome || exit 1
done

echo "All integration tests passed."
