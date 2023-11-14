#!/bin/bash

# Alberta Provincial DEM converter.
# (c)2023 Andy Smith <andy@nsnw.ca>.
# This script is made available under the MIT License -
# please refer to LICENSE for more details.
#
# Usage:-
# ./convert.sh <ORDER_ZIP_FILE>
#
# A directory named 'output' will be created, containing 3 files:-
# * masspoint.csv, containing the converted masspoint (*.gnp) files
#   merged together
# * soft_breakline.csv, containing the converted soft breakline (*.gsl)
#   files merged together
# * hard_breakline.csv, containing the converted hard breakline (*.ghl)
#   files merged together
#
# For more information, refer to the '20K Digital Elevation Model' guide
# on the Altalis site at
# https://www.altalis.com/altalis/files/download?fileUUID=f36d8ca5-5f89-4e73-84d8-053b16c7510c

# Set directory paths.
BASE_DIR="$(dirname $0)"
TMP_DIR="${BASE_DIR}/tmp"
ORDER_DIR="${TMP_DIR}/order"
DEFAULT_OUTPUT_DIR="${BASE_DIR}/output"
INPUT_DIR="${TMP_DIR}/input"
MERGE_DIR="${TMP_DIR}/merge"

# Set colours.
F_CYAN="\033[38;5;038m"
F_RED="\033[38;5;160m"
F_GREEN="\033[38;5;028m"
F_YELLOW="\033[38;5;178m"
F_PURPLE="\033[38;5;062m"
CLR="\033[0m"

log() {
  # Print a log message with a timestamp.
  local MSG="$1"

  echo -e "${F_CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${CLR} ${MSG}"
}

error() {
  # Print an error message.
  local MSG="$1"

  log "${F_RED}[ERROR]${CLR} ${MSG}"
}

hi() {
  # Highlight a string.
  local TEXT="$*"

  echo -en "${F_YELLOW}${TEXT}${CLR}"
}

count() {
  # Highlight a number.
  local NUM="$1"

  echo -en "${F_PURPLE}${NUM}${CLR}"
}

clean_tmp_dir() {
  if [[ -d ${TMP_DIR} ]]; then
    log "Cleaning up temporary directory..."
    rm -rf ${TMP_DIR}
  fi
}

clean_output_dir() {
  if [[ -d "${OUTPUT_DIR}" ]]; then
    log "Cleaning up output directory..."
    rm -rf "${OUTPUT_DIR}"
  fi
}

clean_input_dir() {
  if [[ -d ${INPUT_DIR} ]]; then
    log "Cleaning up input directory..."
    rm -rf ${INPUT_DIR}
  fi
}

clean_merge_dir() {
  if [[ -d ${MERGE_DIR} ]]; then
    log "Cleaning up merge directory..."
    rm -rf ${MERGE_DIR}
  fi
}

make_tmp_dir() {
  clean_tmp_dir
  log "Creating temporary directory..."
  mkdir ${TMP_DIR}
}

make_output_dir() {
  log "Creating output directory..."
  mkdir "${OUTPUT_DIR}"
}

make_input_dir() {
  clean_input_dir
  log "Creating input directory..."
  mkdir -p ${INPUT_DIR}/{masspoint,soft_breakline,hard_breakline}
}

make_merge_dir() {
  clean_merge_dir
  log "Creating merge directory..."
  mkdir -p ${MERGE_DIR}/{masspoint,soft_breakline,hard_breakline}
}

convert_breakline_file() {
  # Convert a breakline file.
  #
  # The format of the file is:-
  #         <ORIGINAL_LINE_ID>
  # <START_X>    <START_Y>    <START_Z>
  # <END_X>      <END_Y>      <END_Z>
  # END
  #
  # We convert it to two CSV-style lines:-
  # <POINT_ID>,<AREA_NAME>,<LINE_ID>,<ORIGINAL_LINE_ID>,<hard|soft>,start,<START_X>,<START_Y>,<START_Z>
  # <POINT_ID>,<AREA_NAME>,<LINE_ID>.<ORIGINAL_LINE_ID>,<hard|soft>,end,<END_X>,<END_Y>,<END_Z>
  # where:-
  # * <POINT_ID> is <AREA_NAME>_<hard|soft>_<ORIGINAL_LINE_ID>_<start|end>
  # * <LINE_ID> is <AREA_NAME>_<hard|soft>_<ORIGINAL_LINE_ID>
  # * <AREA_NAME> is the name of the section (e.g. '72e01ne')

  local BREAKLINE_FILE="$1"
  local BREAKLINE_FILE_NAME=$(basename ${BREAKLINE_FILE%.*})
  local BREAKLINE_FILE_TYPE=$(basename ${BREAKLINE_FILE##*.})

  if [[ ${BREAKLINE_FILE_TYPE} = "ghl" ]]; then
    local BREAKLINE_TYPE="hard"
  else
    local BREAKLINE_TYPE="soft"
  fi

  local BREAKLINE_CONVERTED_FILE=${MERGE_DIR}/${BREAKLINE_TYPE}_breakline/${BREAKLINE_FILE_NAME}.csv

  log "> Converting ${BREAKLINE_TYPE} breakline file $(hi ${BREAKLINE_FILE})..."

  local POINT_ID_PREFIX="${BREAKLINE_FILE_NAME}_${BREAKLINE_TYPE}"

  cat ${BREAKLINE_FILE} \
    | perl -0777 -pe "s/\s+(\d+)\r\n([0-9.]+)\s+([0-9.]+)\s+(\-?[0-9.]+)\r\n([0-9.]+)\s+([0-9.]+)\s+(\-?[0-9.]+)\r\nEND\r\n/${POINT_ID_PREFIX}_\1_start,${BREAKLINE_FILE_NAME},${POINT_ID_PREFIX}_\1,\1,${BREAKLINE_TYPE},start,\2,\3,\4\n${POINT_ID_PREFIX}_\1_end,${BREAKLINE_FILE_NAME},${POINT_ID_PREFIX}_\1,\1,${BREAKLINE_TYPE},end,\5,\6,\7\n/igs" \
    | grep -v "^END" >${BREAKLINE_CONVERTED_FILE}

  rm ${BREAKLINE_FILE}

  local BREAKLINE_COUNT=$(cat ${BREAKLINE_CONVERTED_FILE} | cut -f2-3 -d"," | sort -n | uniq | wc -l)

  log "  Found $(count ${BREAKLINE_COUNT}) ${BREAKLINE_TYPE} breaklines."
}

convert_breakline_files() {
  # Iterate over all the breakline files of a given type and convert them.

  local BREAKLINE_TYPE=$1
  local BREAKLINE_FILE_DIR="${INPUT_DIR}/${BREAKLINE_TYPE}_breakline"

  if [[ ${BREAKLINE_TYPE} = "hard" ]]; then
    local BREAKLINE_SUFFIX="ghl"
  else
    local BREAKLINE_SUFFIX="gsl"
  fi

  local BREAKLINE_FILES="$(find ${BREAKLINE_FILE_DIR} -name "*.${BREAKLINE_SUFFIX}")"

  log "Converting ${BREAKLINE_TYPE} breakline files..."

  for BREAKLINE_FILE in ${BREAKLINE_FILES}; do
    convert_breakline_file "${BREAKLINE_FILE}"
  done
}

convert_masspoint_file() {
  # Convert a masspoint file.
  #
  # The format of the file is:-
  # <ORIGINAL_POINT_ID>,<X>,<Y>,<Z>
  #
  # Since this is already a CSV, we only need to add a unique ID and the area:-
  # <POINT_ID>,<AREA_NAME>,<ORIGINAL_POINT_ID>,<X>,<Y>,<Z>
  # where:-
  # * <POINT_ID> is <AREA_NAME>_<ORIGINAL_POINT_ID>
  # * <AREA_NAME> is the same as for the breakline files

  local MASSPOINT_FILE=$1

  local MASSPOINT_FILE_NAME=$(basename ${MASSPOINT_FILE%.*})
  local MASSPOINT_FILE_TYPE=$(basename ${MASSPOINT_FILE##*.})

  local MASSPOINT_CONVERTED_FILE=${MERGE_DIR}/masspoint/${MASSPOINT_FILE_NAME}.csv

  log "> Converting masspoint file $(hi ${MASSPOINT_FILE})..."

  local POINT_ID_PREFIX="${MASSPOINT_FILE_NAME}"

  cat ${MASSPOINT_FILE} \
    | perl -0777 -pe "s/(\d+),([0-9.]+),([0-9.]+),(\-?[0-9.]+)/${POINT_ID_PREFIX}_\1,${MASSPOINT_FILE_NAME},\1,\2,\3,\4/g" \
    | grep -v "^ENV" >${MASSPOINT_CONVERTED_FILE}

  local MASSPOINT_COUNT=$(cat ${MASSPOINT_CONVERTED_FILE} | cut -f2-3 -d"," | sort -n | uniq | wc -l)

  log "  Found $(count ${MASSPOINT_COUNT}) masspoints."
}

convert_masspoint_files() {
  # Iterate over all the masspoint files and convert them.

  local MASSPOINT_FILE_DIR="${INPUT_DIR}/masspoint"

  local MASSPOINT_FILES="$(find ${MASSPOINT_FILE_DIR} -name "*.gnp")"

  log "Converting masspoint files..."

  for MASSPOINT_FILE in ${MASSPOINT_FILES}; do
    convert_masspoint_file "${MASSPOINT_FILE}"
  done
}

merge_masspoint_files() {
  # Merge all the converted masspoint files, and add a CSV header.

  local MASSPOINT_DIR="${MERGE_DIR}/masspoint"
  local MASSPOINT_CSV="${OUTPUT_DIR}/masspoint.csv"

  log "Creating masspoint CSV..."

  # Add the CSV header.
  echo "point_id,area_id,original_point_id,x,y,z" >"${MASSPOINT_CSV}"

  # Loop through all the files and add them.
  for MASSPOINT_FILE in ${MASSPOINT_DIR}/*; do
    log "> Merging masspoint file $(hi ${MASSPOINT_FILE})..."
    cat ${MASSPOINT_FILE} >>"${MASSPOINT_CSV}"
  done

  local MASSPOINT_COUNT=$(($(cat "${MASSPOINT_CSV}" | cut -f2-3 -d"," | sort -n | uniq | wc -l)-1))

  log "Created masspoint CSV $(hi ${MASSPOINT_CSV}) with $(count ${MASSPOINT_COUNT}) points."
}

merge_breakline_files() {
  # Merge all the converted breakline files, add add a CSV header.

  local BREAKLINE_TYPE=$1
  local BREAKLINE_DIR="${MERGE_DIR}/${BREAKLINE_TYPE}_breakline"
  local BREAKLINE_CSV="${OUTPUT_DIR}/${BREAKLINE_TYPE}_breakline.csv"

  log "Creating ${BREAKLINE_TYPE} breakline CSV..."

  # Add the CSV header.
  echo "point_id,area_id,line_id,original_line_id,line_type,point_type,x,y,z" >"${BREAKLINE_CSV}"

  # Loop through all the files and add them.
  for BREAKLINE_FILE in ${BREAKLINE_DIR}/*; do
    log "> Merging ${BREAKLINE_TYPE} breakline file $(hi ${BREAKLINE_FILE})..."
    cat ${BREAKLINE_FILE} >>"${BREAKLINE_CSV}"
  done

  local BREAKLINE_COUNT=$(($(cat "${BREAKLINE_CSV}" | cut -f2-3 -d"," | sort -n | uniq | wc -l)-1))

  log "Created ${BREAKLINE_TYPE} breakline CSV $(hi ${BREAKLINE_CSV}) with $(count ${BREAKLINE_COUNT}) breaklines."
}

gather_masspoint_files() {
  # Find all the masspoint files (with a '.gnp' extension) and gather them in one place.

  log "Gathering DEM masspoint files..."

  local DEM_MASSPOINT_FILES="$(find ${ORDER_DIR}/dem -name '*.gnp')"

  for DEM_MASSPOINT_FILE in ${DEM_MASSPOINT_FILES}; do
    mv ${DEM_MASSPOINT_FILE} ${INPUT_DIR}/masspoint/
  done

  local DEM_MASSPOINT_INPUT_FILES="$(find ${INPUT_DIR}/masspoint -name '*.gnp')"
  local DEM_MASSPOINT_INPUT_FILES_COUNT="$(echo ${DEM_MASSPOINT_INPUT_FILES} | wc -w)"

  log "Found $(count ${DEM_MASSPOINT_INPUT_FILES_COUNT}) masspoint files."
}

gather_breakline_files() {
  # Find all the breakline files (with a '.gsl' or '.ghl' extension depending on the type)
  # and gather them in one place.

  local BREAKLINE_TYPE=$1

  if [[ ${BREAKLINE_TYPE} = "hard" ]]; then
    local BREAKLINE_SUFFIX="ghl"
  else
    local BREAKLINE_SUFFIX="gsl"
  fi

  local BREAKLINE_FILE_DIR="${INPUT_DIR}/${BREAKLINE_TYPE}_breakline"

  log "Gathering DEM ${BREAKLINE_TYPE} breakline files..."

  local DEM_BREAKLINE_FILES="$(find ${ORDER_DIR}/dem -name "*.${BREAKLINE_SUFFIX}")"

  for DEM_BREAKLINE_FILE in ${DEM_BREAKLINE_FILES}; do
    mv ${DEM_BREAKLINE_FILE} ${BREAKLINE_FILE_DIR}
  done

  local DEM_BREAKLINE_INPUT_FILES="$(find ${BREAKLINE_FILE_DIR} -name "*.${BREAKLINE_SUFFIX}")"
  local DEM_BREAKLINE_INPUT_FILES_COUNT="$(echo ${DEM_BREAKLINE_INPUT_FILES} | wc -w)"

  log "Found $(count ${DEM_BREAKLINE_INPUT_FILES_COUNT}) ${BREAKLINE_TYPE} breakline files."
}

unpack_order() {
  # Unpack the order zip file, and then unzip the zip files contained within.

  local ORDER_FILE="$1"

  log "Unpacking order file $(hi ${ORDER_FILE})..."

  unzip -q ${ORDER_FILE} -d ${ORDER_DIR}

  local DEM_ZIPS="$(find ${ORDER_DIR} -name '*.zip')"
  local DEM_ZIPS_COUNT="$(echo ${DEM_ZIPS} | wc -w)"

  log "Order file $(hi ${ORDER_FILE}) unpacked, $(count ${DEM_ZIPS_COUNT}) zips found."

  log "Unpacking DEM zips..."

  for DEM_ZIP in ${DEM_ZIPS}; do
    log "> Unpacking $(hi ${DEM_ZIP})..."
    unzip -q ${DEM_ZIP} -d ${ORDER_DIR}/dem
    log "  Removing $(hi ${DEM_ZIP})..."
    rm ${DEM_ZIP}
  done
}

if [[ -z ${1+x} ]]; then
  error "No order zip file given."
  exit 1
fi

ORDER_ZIP_FILE="$1"

if [[ ! -z ${2+x} ]]; then
  OUTPUT_DIR="$2"
else
  OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"
fi

# Unpack the order file.
make_tmp_dir
unpack_order "${ORDER_ZIP_FILE}"

# ...gather all the files...
make_input_dir
gather_masspoint_files
gather_breakline_files hard
gather_breakline_files soft

# ...convert them...
make_merge_dir
convert_masspoint_files
convert_breakline_files hard
convert_breakline_files soft

# ...and then merge the files by type.
make_output_dir
merge_masspoint_files
merge_breakline_files hard
merge_breakline_files soft

clean_tmp_dir

log "Files output to $(hi ${OUTPUT_DIR})."
