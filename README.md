# zfs-snapshot
zfs-snapshot

This script replicates the functionality of Apple Time Machine backups in zfs. It is designed to be run hourly using crontab or any of it's comparable suites.



It will do the following:

	- Take an hourly snapshot.

	- Keep hourly snapshots for 24 hours.

	- Keep daily snapshots for a week.

	- Keep monthly snapshots indefinitely.

