#!/bin/bash
# author: Piotr Karwowski
# website: www.piotrkarwowski.com
# restore_subfolders.sh
#
# Description:
#   1. Scans a backup directory for subfolders containing .sql files.
#   2. Prompts user to pick which subfolder to restore from.
#   3. Creates a new MySQL database (with current date/time in its name).
#   4. Restores "structure" files first, then all other data files.
#
# Usage:
#   ./restore_subfolders.sh
#
#   (No arguments needed; everything is configured in the script.)
#
# Notes:
#   - Adjust DB_USER, DB_PASS, DB_HOST, BACKUP_DIR, DB_NAME_PREFIX as needed.
#   - Filenames containing 'structure' are treated as schema (tables) only.
#   - Everything else is assumed to be data.

# ------------------ Configuration ------------------
DB_USER="admin"
DB_PASS="password"
DB_HOST="localhost"

# The top-level directory that contains subfolders of .sql files
BACKUP_DIR="/home/backup/"

# Prefix for the restored DB name
DB_NAME_PREFIX="restored"

# ------------------ Script Logic -------------------

# 1. Gather subfolders that contain at least one .sql file
subfolders=()

# Make sure BACKUP_DIR exists
if [ ! -d "${BACKUP_DIR}" ]; then
  echo "Error: BACKUP_DIR does not exist: ${BACKUP_DIR}"
  exit 1
fi

# Loop through all items in BACKUP_DIR; pick only directories with *.sql
for folder in "${BACKUP_DIR}"/*; do
  # skip if not a directory
  [ -d "${folder}" ] || continue

  # Check if folder has at least one .sql file
  sql_count=$(find "${folder}" -maxdepth 1 -type f -name '*.sql' | wc -l)
  if [ "${sql_count}" -gt 0 ]; then
    subfolders+=("${folder}")
  fi
done

# If no subfolders have .sql files, exit
if [ ${#subfolders[@]} -eq 0 ]; then
  echo "No subfolders in '${BACKUP_DIR}' contain .sql files. Nothing to restore."
  exit 0
fi

# 2. Prompt user to pick which subfolder to restore from
echo "Found the following backup folders containing .sql files:"
for i in "${!subfolders[@]}"; do
  echo "  $((i+1)). ${subfolders[$i]}"
done

read -rp "Enter the number of the folder you want to restore from: " choice

# Validate the choice
if ! [[ "${choice}" =~ ^[0-9]+$ ]] || [ "${choice}" -lt 1 ] || [ "${choice}" -gt "${#subfolders[@]}" ]; then
  echo "Invalid choice. Exiting."
  exit 1
fi

RESTORE_FOLDER="${subfolders[$((choice-1))]}"

echo "-----------------------------------------------------"
echo "You chose: ${RESTORE_FOLDER}"
echo "-----------------------------------------------------"

# 3. Create a new database name
TIMESTAMP=$(date +'%Y%m%d_%H%M')
NEW_DB_NAME="${DB_NAME_PREFIX}_${TIMESTAMP}"
#NEW_DB_NAME="${DB_NAME_PREFIX}"
echo "Creating new database: ${NEW_DB_NAME}"
mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" -e "CREATE DATABASE \`${NEW_DB_NAME}\`;"
if [ $? -ne 0 ]; then
  echo "Error: Failed to create database ${NEW_DB_NAME}."
  exit 1
fi

# 4. Separate 'structure' vs. 'data' .sql files in the chosen folder
structure_files=()
data_files=()

# Gather all .sql files in that folder
sql_files=( "${RESTORE_FOLDER}"/*.sql )

for f in "${sql_files[@]}"; do
  # skip if for some reason there's no .sql files (edge case with *.sql expansion)
  [ -f "$f" ] || continue

  if [[ "$f" == *structure* ]]; then
    structure_files+=("$f")
  else
    data_files+=("$f")
  fi
done

# If no .sql files were found (edge case), exit
if [ ${#structure_files[@]} -eq 0 ] && [ ${#data_files[@]} -eq 0 ]; then
  echo "No .sql files found in ${RESTORE_FOLDER} after all. Exiting."
  exit 0
fi

# 4a. Restore structure files first
if [ ${#structure_files[@]} -gt 0 ]; then
  echo "-----------------------------------------------------"
  echo "Restoring STRUCTURE files first..."
  echo "-----------------------------------------------------"
  for structure_file in "${structure_files[@]}"; do
    echo "Restoring $structure_file ..."
    mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" "${NEW_DB_NAME}" < "${structure_file}"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to restore structure from $structure_file"
      exit 1
    fi
  done
else
  echo "No structure files found (filenames containing 'structure')."
fi

# 4b. Restore data files second
if [ ${#data_files[@]} -gt 0 ]; then
  echo "-----------------------------------------------------"
  echo "Restoring DATA files..."
  echo "-----------------------------------------------------"
  for data_file in "${data_files[@]}"; do
    echo "Restoring $data_file ..."
    mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" "${NEW_DB_NAME}" < "${data_file}"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to restore data from $data_file"
      exit 1
    fi
  done
else
  echo "No data files found."
fi

# Done!
echo "-----------------------------------------------------"
echo "Restore completed successfully!"
echo "New database name: ${NEW_DB_NAME}"
echo "-----------------------------------------------------"
