# System Utils
Various utility scripts I use on my systems and when scripting in general

### syncup.sh
- Incrimental backup strategy using rsync (uncompressed).

### system-update.sh
- automated apt update script which also logs all updated packages.

### check-updates.sh
- simple apt-get update check and updates node_exporter monitored file.

### send-email.sh
- msmtp wrapper script for sending emails inside of other automation scripts (requires msmtp configured on system).

### screensaver.sh
- Randomly selects from one of my installed cli screensavers
  - [lavat](https://github.com/AngelJumbo/lavat)
  - [pipes.sh](https://github.com/pipeseroni/pipes.sh)
  - [terminal-rain](https://github.com/rmaake1/terminal-rain-lightning)

### backup.sh (depricated)
- Backup script using zstd compression and multiple redundant backups.
