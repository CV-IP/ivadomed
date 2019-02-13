#!/bin/bash
#
# Wrapper to use with generate_ground_truth.sh, the script outputs BIDS
# data and takes bids data as input. It will loop across all centers and all
# subjects within each center
#
# Usage:
#   ./run_process.sh <script>
#
# Example:
#   ./run_process.sh generate_ground_truth.sh
#
# Note:
#   Make sure to copy the file parameters_template.sh into parameters.sh and 
#   edit it with the proper list of subjects and variable.

# Authors: Nicolas Pinon, Julien Cohen-Adad

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# Build color coding (cosmetic stuff)
Color_Off='\033[0m'  # Text Reset
Green='\033[0;92m'  # Yellow
Red='\033[0;91m'  # Red
On_Black='\033[40m'  # Black

# Initialization
unset SITES
# unset SUBJECTS
time_start=$(date +%x_%r)

# Load config file
if [ -e "parameters.sh" ]; then
  source parameters.sh
else
  printf "\n${Red}${On_Black}ERROR: The file parameters.sh was not found. You need to create one for this pipeline to work.${Color_Off}\n\n"
  exit 1
fi

# build syntax for process execution
task=`pwd`/$1

# If the variable SITES does not exist (commented), get list of all sites
if [ -z ${SITES} ]; then
  echo "Processing all sites located in: $PATH_DATA"
  # Get list of folders (remove full path, only keep last element)
  SITES=`ls -d ${PATH_DATA}/*/ | xargs -n 1 basename`
else
  echo "Processing sites specified in parameters.sh"
fi
echo "--> " ${SITES[@]}

# Create output folder folder ("-p" creates parent folders if needed)
mkdir -p ${PATH_OUTPUT}

if [ ! -d "$PATH_OUTPUT" ]; then
  printf "\n${Red}${On_Black}ERROR: Cannot create folder: $PATH_OUTPUT. Exit.${Color_Off}\n\n"
  exit 1
fi

# Processing of one subject
do_one_subject_parallel() {
  local subject="$1"
  echo "cd ${PATH_DATA}/${site}; ${task} $(basename $subject) ${PATH_OUTPUT}/$site ${PATH_QC}"
}
do_one_subject() {
  local subject="$1"
  cd ${PATH_DATA}/${site}
  ${task} $(basename $subject) ${PATH_OUTPUT}/$site ${PATH_QC}
}

# Run processing with or without "GNU parallel", depending if it is installed or not
if [ -x "$(command -v parallel)" ]; then
  echo 'GNU parallel is installed! Processing subjects in parallel using multiple cores.' >&2
  for site in ${SITES[@]}; do
    mkdir -p ${PATH_OUTPUT}/${site}
    find ${PATH_DATA}/${site} -mindepth 1 -maxdepth 1 -type d | while read subject; do
      do_one_subject_parallel $subject
    done
  done \
  | parallel --halt-on-error soon,fail=1 sh -c "{}"
else
  echo 'GNU parallel is not installed. Processing subjects sequentially.' >&2
  for site in ${SITES[@]}; do
    mkdir -p ${PATH_OUTPUT}/${site}
    find ${PATH_DATA}/${site} -mindepth 1 -maxdepth 1 -type d | while read subject; do
      do_one_subject $subject
    done
  done
fi

# Display stuff
echo "FINISHED :-)"
echo "Started: $time_start"
echo "Ended  : $(date +%x_%r)"