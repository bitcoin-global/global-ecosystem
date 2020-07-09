#!/bin/bash

SCRIPT_ROOT=$(dirname $(readlink -f "$0"))
ruby ${SCRIPT_ROOT}/jobs/nodes/runner.rb
