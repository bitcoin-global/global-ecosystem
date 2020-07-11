#!/bin/bash

tmppipeline=$(mktemp /tmp/pipeline.XXXXXX)
tmpfile=$(mktemp /tmp/spruce.XXXXXX)

cat <<EOF > $tmpfile
spruce:
# Build pipeline file
- base: base.yml
  merge:
  - with_all_in: consts/
    regexp: ".*.(yml)"
  - with_all_in: jobs/shared/
    regexp: ".*.(yml)"
  - with_all_in: resources/shared/
    regexp: ".*.(yml)"
  - with:
      files:
      - resources/docker.builder.yml
      - resources/git.builder-ecosystem.yml
      - resources/git.pipeline-ecosystem.yml
  - with_all_in: jobs/builder/
    regexp: ".*.(yml)"
  - with_all_in: jobs/pipes/
    regexp: ".*.(yml)"
  to: $tmppipeline

# Clean pipeline file
- base:  $tmppipeline
  prune:
  - meta
  - meta_plan
  to: $tmppipeline

# Deploy pipeline file
fly:
  target: bitglob
  name: shared-infra
  config: $tmppipeline
  non_interactive: true
EOF

# Apply file
aviator -f $tmpfile

# Cleanup
rm -rf $tmppipeline
