#!/bin/bash

# Die letzten K_HOURS Stunden ein Backup behalten
K_HOURS=24

# Die letzten K_DAYS Tage das 0 Uhr Backup behalten 
K_DAYS=7

# Die letzten K_WEEKS Wochen das Backup vom 1. Tag der Woche um 0 Uhr behalten
K_WEEKS=4

# Die letzten K_MONTHS Monate das Backup vom 1. um 0 Uhr behalten
K_MONTHS=12

# Die letzten K_YEARS Jahre das Backup vom 1.1. um 0 Uhr behalten
K_YEARS=5

DATE_PREFIX="backup-"
DATE_FRMT="%Y-%m-%d-%H"

KEEPS=()

for (( c=0; c<${K_HOURS}; c++)); do
  KEEPS+=("$(date +"%Y-%m-%d-%H" --date="${c} hours ago")")
done

for (( c=0; c<${K_DAYS}; c++))
do
  KEEPS+=("$(date +"%Y-%m-%d-00" --date="${c} days ago")")
done

for (( c=0; c<${K_WEEKS}; c++))
do
  KEEPS+=("$(date +"%Y-%m-%d-00" --date="${c} weeks ago")")
done

for (( c=0; c<${K_MONTHS}; c++))
do
  KEEPS+=("$(date +"%Y-%m-01-00" --date="${c} months ago")")
done

for (( c=0; c<${K_YEARS}; c++))
do
  KEEPS+=("$(date +"%Y-01-01-00" --date="${c} years ago")")
done

#echo ${KEEPS[@]}

REMOVES=()
FILES=/backup/backups/backup-*
for FILE in $FILES
do
  if [ -d "${FILE}" ]; then
    RFILE=$(echo ${FILE} | sed "s/\/backup\/backups\/${DATE_PREFIX}//g")
#	If FILE NOT in KEEPS-array
    if [[ !("${KEEPS[*]}" =~ (^|[^[:alpha:]])${RFILE}([^[:alpha:]]|$)) ]]; then
      REMOVES+=(${FILE})
    fi
  fi
done

for REMOVE in ${REMOVES[@]}
do
#  echo "REMOVE: ${REMOVE}"
  rm -R "${REMOVE}"
  rm "${REMOVE}.log"
done
