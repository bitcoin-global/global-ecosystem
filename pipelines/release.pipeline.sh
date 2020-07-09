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
      - resources/git.bitcoin-global.yml
      - resources/git.global-ecosystem.yml
      - resources/docker.builder.yml
  - with_all_in: jobs/release/
    regexp: ".*.(yml)"
  to: ignore.release.pipeline.yml

# Clean pipeline file
- base:  ignore.release.pipeline.yml
  prune:
  - meta
  - meta_plan
  to: ignore.release.pipeline.yml

# Deploy pipeline file
fly:
  target: bitglob
  name: release-procedures
  config: ignore.release.pipeline.yml
EOF

# Apply file
aviator -f $tmpfile

# Cleanup
rm -rf $tmppipeline
