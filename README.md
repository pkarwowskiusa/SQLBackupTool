MySQL Per-Table Backup and Restore Scripts

## Overview
This repository contains two Bash scripts that facilitate **per-table MySQL backups** (in chunks, if needed) and **restoring** backups from a chosen directory.

- **Backup Script**: `per_table_backup_with_structure_chunked.sh`
  - Dumps database schema in one file.
  - Dumps each table’s data in individual files, optionally split into multiple chunks (based on numeric ID ranges).
- **Restore Script**: `restore_subfolders.sh`
  - Scans a backup directory for subfolders of `.sql` files.
  - Prompts user to pick which subfolder to restore from.
  - Creates a new MySQL database and restores structure files first, then data files.

## Prerequisites
1. **MySQL** or **MariaDB** command-line tools:
   - `mysqldump`
   - `mysql`
2. **Bash** shell environment (Linux/Unix).
3. Proper **file permissions** so that the scripts can be executed:
   ```bash
   chmod +x per_table_backup_with_structure_chunked.sh
   chmod +x restore_subfolders.sh
