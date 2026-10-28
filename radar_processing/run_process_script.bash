#!/bin/bash

source /home/jduda/miniforge_source
conda activate astropy

set -x
python -u ${SCRIPT_DIR}/process_refl_workflow.py ${TIME}

set -
