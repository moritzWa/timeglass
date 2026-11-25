# Testing

## Model checks

`sh scripts/test.sh` checks valid and malformed durations, bounds, countdown
formatting, wall-clock expiry, persistence, and removal of cancelled state.
The test store is a unique temporary directory, not the user's app data.

## Native checks (2026-11-25)

The development app ran in an isolated macOS 26.5.2 VM. Audio output was verified
muted before any timer was started. No sound was played on the host Mac.

- Enter on `10m` created one native pending notification with sound and a saved
  deadline. A second Enter removed both the pending notification and state file.
- A 20-second countdown finished and displayed the native “Time's up” banner.
- A 60-second timer restored after process termination and relaunch. Enter then
  cancelled the restored timer; native pending count returned to zero.
- A ten-second timer created one sound-enabled pending request. The app process
  was terminated. macOS then reported zero pending requests and one delivered
  notification whose sound was present.
- The initial notification permission banner was allowed inside the VM. Native
  diagnostics reported authorized notifications and enabled notification sound.
- The window's glass backing was clipped to its 26pt silhouette and checked from
  a fresh desktop capture. The README screenshot uses only a generated duration.

Sound attachment and delivery were checked through UserNotifications, not by
listening to the muted VM. Sleep/reboot delivery and physical audio output have
not been exercised. Those remain subject to macOS notification and Focus settings.
