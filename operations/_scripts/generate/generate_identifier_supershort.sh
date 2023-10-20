#!/bin/bash

set -e
echo "-----------------------------supershort----------========================================="
if [ -z "$AWS_RESOURCE_IDENTIFIER" ]; then
  GITHUB_IDENTIFIER="$($GITHUB_ACTION_PATH/operations/_scripts/generate/generate_identifier.sh)"
  GITHUB_IDENTIFIER="$($GITHUB_ACTION_PATH/operations/_scripts/generate/shorten_identifier.sh ${GITHUB_IDENTIFIER} 30)"
else
  GITHUB_IDENTIFIER="$AWS_RESOURCE_IDENTIFIER"
fi
echo "$GITHUB_IDENTIFIER" | xargs