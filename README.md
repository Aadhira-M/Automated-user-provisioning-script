
# Linux User Provisioning Script

A Bash script that automates bulk Linux user creation from a CSV file.
Built as a simulation of an enterprise onboarding pipeline.

## What it does
- Reads user details from a CSV (username, group, shell, SSH key)
- Validates each row before processing
- Creates Linux groups if they don't exist
- Creates users with home directories and specified shell
- Injects SSH public keys into `authorized_keys`
- Falls back to a default shell if the specified one isn't installed
- Skips already-existing users safely (idempotent)
- Logs every action with timestamps to `/var/log/user_provisioning.log`

## Usage
```bash
sudo ./provision_users.sh users.csv
```

## CSV format
