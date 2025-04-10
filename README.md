Overview
This repository contains two Bash scripts that facilitate per-table MySQL backups (in chunks, if needed) and restoring backups from a chosen directory.

Backup Script: per_table_backup_with_structure_chunked.sh

Dumps database schema in one file.

Dumps each table’s data in individual files, optionally split into multiple chunks (based on numeric ID ranges).

Restore Script: restore_subfolders.sh

Scans a backup directory for subfolders of .sql files.

Prompts user to pick which subfolder to restore from.

Creates a new MySQL database and restores structure files first, then data files.

Prerequisites
MySQL or MariaDB command-line tools:

mysqldump

mysql

Bash shell environment (Linux/Unix).

Proper file permissions so that the scripts can be executed:

bash
Copy
Edit
chmod +x per_table_backup_with_structure_chunked.sh
chmod +x restore_subfolders.sh
Make sure the MySQL user you specify has the necessary privileges to:

Read from the database (for backup).

Create new databases and tables (for restore).

Insert data (for restore).

Script 1: Backup (per_table_backup_with_structure_chunked.sh)
Features
Schema-only dump is saved in a single .sql file.

Table data is dumped in separate .sql files, one file per table.

Tables with rows greater than CHUNK_SIZE will be split into multiple files based on id ranges.

Requires each table to have a numeric primary key named id.

Configuration
Edit the variables at the top of the script:

bash
Copy
Edit
DB_USER="admin"
DB_PASS="password"
DB_NAME="database_name"
CHUNK_SIZE=500000
OUTPUT_DIR="/home/backup/$(date +'%Y%m%d_%H%M')"
DB_USER, DB_PASS: MySQL username and password.

DB_NAME: The name of the database you want to back up.

CHUNK_SIZE: Approximate number of rows per chunk.

OUTPUT_DIR: Directory where the backup files will be stored (includes a timestamp).

Usage
Make the script executable:

bash
Copy
Edit
chmod +x per_table_backup_with_structure_chunked.sh
Run the script:

bash
Copy
Edit
./per_table_backup_with_structure_chunked.sh
Upon completion, you will see a backup folder (named with the current timestamp) containing:

One file for the entire database structure (e.g. database_name_structure_20230407_1030.sql)

One or more .sql files for each table’s data, chunked if necessary (e.g. database_name_tableName_20230407_1030_1-500000.sql).

Script 2: Restore (restore_subfolders.sh)
Features
Allows you to pick a subfolder of .sql files to restore.

Automatically creates a new MySQL database with a timestamp in the name (e.g. restored_20230407_1030).

Restores all files containing the word structure first (schema), then restores all other files (data).

Configuration
Edit the variables at the top of the script:

bash
Copy
Edit
DB_USER="admin"
DB_PASS="password"
DB_HOST="localhost"
BACKUP_DIR="/home/backup/"
DB_NAME_PREFIX="restored"
DB_USER, DB_PASS, DB_HOST: Credentials and host for connecting to MySQL.

BACKUP_DIR: The top-level directory containing subfolders of .sql files (the same or similar to where your backup script saved them).

DB_NAME_PREFIX: Prefix for the newly created database.

Usage
Make the script executable:

bash
Copy
Edit
chmod +x restore_subfolders.sh
Run the script:

bash
Copy
Edit
./restore_subfolders.sh
The script will:

List subfolders in BACKUP_DIR containing at least one .sql file.

Prompt you to pick which folder to restore from (by number).

Create a new MySQL database named restored_YYYYMMDD_HHMM.

Restore structure files first, then all other .sql files.

When the restore is complete, you’ll see a success message with the name of the newly created database.

Important Notes & Limitations
Chunked Backups:

The chunking logic assumes there is a numeric primary key called id on every table.

If your tables are missing such a key, the chunked part won’t work properly.

Manual Verification:

Always verify the backups and restores, especially for large databases.

You may want to perform a mysqldump (without chunking) from time to time to compare or double-check.

User Privileges:

Make sure your DB_USER has the CREATE, SELECT, INSERT (and possibly DROP) privileges, or else the scripts may fail.

No Warranty:

These scripts are provided as-is. Always test them on non-production systems before using them in production.

Example Workflow
Backup a production database:

bash
Copy
Edit
./per_table_backup_with_structure_chunked.sh
A new timestamped folder (e.g. /home/backup/20230407_1030/) will be created with your .sql files.

Restore to a test environment:

Copy the backup folder to your restore server if needed.

Update BACKUP_DIR to point to where the folder is located on the restore server.

Run:

bash
Copy
Edit
./restore_subfolders.sh
Pick the folder you want to restore from.

The script creates a new database (e.g. restored_20230407_1030) and loads the schema + data into it.
