# reconstruct_collection.sh

Reconstructs an Ansible `galaxy.yml` file from an existing `MANIFEST.json` found in an unpacked collection tarball. This script essentially performs the reverse operation of `ansible-galaxy collection build`.

## Overview

When you have a built Ansible collection (either as a `.tar.gz` file or an unpacked directory), this script will:
1. Extract the collection (if provided as a tar.gz file)
2. Read the `MANIFEST.json` file
3. Reconstruct the `galaxy.yml` file from the manifest data
4. Remove build artifacts (`MANIFEST.json` and `FILES.json`) to prepare for a clean rebuild

## Requirements

- `jq` - JSON processor
- `tar` - Archive extraction tool

### Installing Dependencies

**On Debian/Ubuntu:**
```bash
sudo apt install jq tar
```

**On macOS:**
```bash
brew install jq
# tar is pre-installed on macOS
```

**On RHEL/CentOS/Fedora:**
```bash
sudo dnf install jq tar
# or
sudo yum install jq tar
```

## Usage

```bash
./reconstruct_collection.sh <target_folder_or_tar.gz>
```

### Parameters

- `<target_folder_or_tar.gz>` - Either:
  - A path to an Ansible collection `.tar.gz` file, or
  - A path to an unpacked collection directory containing `MANIFEST.json`

### Examples

**Working with a tar.gz file:**
```bash
./reconstruct_collection.sh my-collection-1.0.0.tar.gz
```

The script will:
- Extract the tar.gz file to a directory next to the archive
- Find the extracted collection directory
- Reconstruct `galaxy.yml` from `MANIFEST.json`
- Remove build artifacts

**Working with an unpacked directory:**
```bash
./reconstruct_collection.sh /path/to/unpacked/collection
```

The script will:
- Validate that the directory contains `MANIFEST.json`
- Reconstruct `galaxy.yml` from `MANIFEST.json`
- Remove build artifacts

## Safety Features

- **Directory Protection**: The script cannot target its own directory (prevents accidental self-modification)
- **Validation**: Ensures `MANIFEST.json` exists before processing
- **Overwrite Protection**: Prompts before overwriting existing `galaxy.yml` files
- **Extraction Safety**: Prompts before overwriting existing extraction directories

## What Gets Reconstructed

The script reconstructs the following fields in `galaxy.yml` from `MANIFEST.json`:

- `namespace`
- `name`
- `version`
- `readme`
- `description`
- `authors` (array)
- `tags` (array)
- `license` (array)
- `repository`
- `documentation`
- `homepage`
- `issues`
- `build_ignore` (array)
- `dependencies` (JSON format)

## Output

After successful execution, the script will:
1. Create/overwrite `galaxy.yml` in the target directory
2. Remove `MANIFEST.json` (if present)
3. Remove `FILES.json` (if present)
4. Display the target directory path for next steps

## Next Steps

After running the script:

1. Switch to the target directory:
   ```bash
   cd <target_directory>
   ```

2. Edit `galaxy.yml` to make any needed changes (update version, metadata, etc.)

3. Rebuild the collection:
   ```bash
   ansible-galaxy collection build
   ```

## Error Handling

The script will exit with an error if:
- Required dependencies (`jq` or `tar`) are not installed
- The input parameter is not a valid directory or tar.gz file
- The target directory is the script's own directory
- `MANIFEST.json` is not found in the target location
- The tar.gz file cannot be extracted or contains no directories

## Notes

- The script uses `set -e` to exit immediately on any error
- All file operations are performed in the target directory
- When extracting tar.gz files, the extraction directory is created next to the archive file
- The script preserves the original tar.gz file (does not delete it)

