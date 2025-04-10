#!/bin/bash
# author: Piotr Karwowski
# website: www.piotrkarwowski.com
# per_table_backup_with_structure_chunked.sh
#
# Description:
#   1. Dumps the entire database schema (no data) into one file.
#   2. Dumps each table’s data in multiple chunks based on numeric ID ranges.
#
# Usage:
#   ./per_table_backup_with_structure_chunked.sh
#
# Notes:
#   - "CHUNK_SIZE_IN_ROWS" below sets how many rows per chunk (approximately).
#   - Adjust DB_USER, DB_PASS, DB_NAME, OUTPUT_DIR, etc. to your environment.
#   - Test thoroughly to ensure it works for your schema and data.

# -------------------------------------------------------------------
# 1. CONFIGURATION
# -------------------------------------------------------------------
DB_USER="admin"
DB_PASS="password"
DB_NAME="database_name"
TIMESTAMP=$(date +'%Y%m%d_%H%M')
OUTPUT_DIR="/home/backup/$TIMESTAMP"

CHUNK_SIZE=500000

# Ensure the backup directory exists
mkdir -p "${OUTPUT_DIR}"

# 1. Dump the entire database structure (no data) into a single file
STRUCTURE_FILE="${OUTPUT_DIR}/${DB_NAME}_structure_${TIMESTAMP}.sql"

echo "Dumping the entire database structure to: ${STRUCTURE_FILE}"
mysqldump \
    -u"${DB_USER}" -p"${DB_PASS}" \
    --no-data \
    --add-drop-table \
    "${DB_NAME}" > "${STRUCTURE_FILE}" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Failed to dump the database structure."
  exit 1
fi
echo "Successfully dumped the database structure."

# 2. Dump each table's data separately
echo "Retrieving table list from database: ${DB_NAME}"
TABLES=$(mysql -u"${DB_USER}" -p"${DB_PASS}" -N -B -e "SHOW TABLES IN ${DB_NAME};" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "${TABLES}" ]; then
  echo "Error: Could not retrieve tables from ${DB_NAME} or no tables found."
  exit 1
fi

for TABLE in ${TABLES}; do
  echo
  echo "------------------------------------"
  echo "Processing table: ${TABLE}"

  # Get row count for this table
  ROW_COUNT=$(mysql -u"${DB_USER}" -p"${DB_PASS}" -N -B -e "SELECT COUNT(*) FROM \`${DB_NAME}\`.\`${TABLE}\`;" 2>/dev/null)

  if [ $? -ne 0 ]; then
    echo "Error: Could not retrieve row count for table ${TABLE}."
    continue
  fi

  echo "Number of rows: ${ROW_COUNT}"

  # If the table has <= CHUNK_SIZE rows, do a single dump
  if [ "${ROW_COUNT}" -le "${CHUNK_SIZE}" ]; then
    OUTPUT_FILE="${OUTPUT_DIR}/${DB_NAME}_${TABLE}_${TIMESTAMP}.sql"
    echo "Row to begin at: 1 (single dump because <= ${CHUNK_SIZE} rows)."
    echo "Dumping table ${TABLE} -> ${OUTPUT_FILE}"

    mysqldump \
      -u"${DB_USER}" -p"${DB_PASS}" \
      --single-transaction --quick \
      "${DB_NAME}" "${TABLE}" > "${OUTPUT_FILE}" 2>/dev/null

    if [ $? -ne 0 ]; then
      echo "Error: Failed to dump table ${TABLE}."
    else
      echo "Success: ${OUTPUT_FILE} created."
    fi

  else
    # More than CHUNK_SIZE rows; dump in chunks
    echo "Table ${TABLE} has more than ${CHUNK_SIZE} rows; dumping in chunks..."

    # We assume there is a numeric primary key named 'id'.
    # First, retrieve the minimum and maximum 'id' values.
    MIN_ID=1
    MAX_ID=$ROW_COUNT

    if [ -z "${MIN_ID}" ] || [ -z "${MAX_ID}" ]; then
      echo "Error: Could not retrieve min/max id for table ${TABLE}. Skipping."
      continue
    fi

    CURRENT_START=${MIN_ID}
    # Dump each chunk until we've covered all rows
    while [ "${CURRENT_START}" -le "${MAX_ID}" ]; do
      CURRENT_END=$((CURRENT_START + CHUNK_SIZE - 1))
      if [ "${CURRENT_END}" -gt "${MAX_ID}" ]; then
        CURRENT_END=${MAX_ID}
      fi

      echo "Row to begin at: ${CURRENT_START}"
      OUTPUT_FILE="${OUTPUT_DIR}/${DB_NAME}_${TABLE}_${TIMESTAMP}_${CURRENT_START}-${CURRENT_END}.sql"
      echo "Dumping rows with id BETWEEN ${CURRENT_START} AND ${CURRENT_END} -> ${OUTPUT_FILE}"

      mysqldump \
        -u"${DB_USER}" -p"${DB_PASS}" \
        --single-transaction --quick \
        "${DB_NAME}" "${TABLE}" \
        --where="1 LIMIT ${CURRENT_END} OFFSET $((CURRENT_START-1))" \
        > "${OUTPUT_FILE}" 2>/dev/null

      if [ $? -ne 0 ]; then
        echo "Error: Failed to dump table ${TABLE}, chunk ${CURRENT_START}-${CURRENT_END}."
      else
        echo "Success: ${OUTPUT_FILE} created."
      fi

      # Next chunk starts at CURRENT_END+1
      CURRENT_START=$((CURRENT_END + 1))
    done
  fi
done

echo
echo "All table dumps and the structure file are located in: ${OUTPUT_DIR}"
echo

# Find subfolders that start with PREFIX* and are older than 90 days, then remove them
find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -name "*" -mtime +90 -exec rm -rf {} \;
