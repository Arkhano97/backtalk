#!/bin/bash
# backtalk: talk to your Claude Code agent out loud.
# backtalk entrypoint — start a spoken conversation with your agent.
# Terminal-invoked (inherits the terminal's mic permission). Ctrl-C hangs up.
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# WSL2 self-heal. PortAudio's ALSA pulse plugin looks for the socket at
# the standard runtime path whatever $PULSE_SERVER says, and WSLg only
# creates it at /mnt/wslg/PulseServer. Without this link, playback does
# not fail cleanly: it CRASHES the process with a core dump, which reads
# as the voice line being broken rather than the audio path being
# unwired. That runtime folder is wiped on every reboot, so the link is
# remade on every launch rather than once at install.
# Guarded on the socket existing, so this is a no-op on every platform
# that is not WSL2.
if [ -S /mnt/wslg/PulseServer ] && [ ! -S "/run/user/$(id -u)/pulse/native" ]; then
  mkdir -p "/run/user/$(id -u)/pulse"
  ln -sf /mnt/wslg/PulseServer "/run/user/$(id -u)/pulse/native"
fi
# Single-instance guard: a stale voice session left in a background
# terminal answers the same mic alongside a fresh launch = two voices at
# once, and it sounds haunted. One body, one mouth.
if pkill -f "backtalk[.]main" 2>/dev/null; then
  echo "[backtalk] replaced a previous voice session"
  sleep 1   # let the old process release mic/speaker devices
fi
# Self-repair: reconcile the environment with the shipped package list
# before launching (sub-second when already current). --inexact keeps
# anything the person's agent added on purpose; a missing package
# (a half-finished install, a drifted env) heals here instead of
# crashing on import. If it fails (offline), launch anyway.
uv sync -q --inexact 2>/dev/null || true
exec uv run python -m backtalk.main "$@" 2> >(grep -vi "pkg_resources\|VIRTUAL_ENV" >&2)
