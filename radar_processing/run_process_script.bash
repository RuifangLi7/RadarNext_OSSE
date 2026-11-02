#!/bin/bash

source /home/jduda/miniforge_source
conda activate astropy

# No need for command line arguments, as all necessary arguments will be read in from environmental vars in the Python script
python -u ${SCRIPT_DIR}/process_refl_workflow.py
