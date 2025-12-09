# Dedup Service

System service for file deduplication using hard links.

## Features

- Scans specified directories for duplicate files
- Uses XXHash for fast hash calculation
- Replaces duplicates with hard links
- Configurable scan intervals and minimum file size
- Dry-run mode for testing
- Systemd integration with proper logging

## Installation

### From RPM repository:

```bash
sudo dnf install dedup-service
