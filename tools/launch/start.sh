#!/bin/sh
# Starts the local server for the sprite tools page on macOS or Linux:
# Python 3 if it's usable, else Perl. Used by the Mac and Linux launchers. -Elvie
here=$(cd "$(dirname "$0")" && pwd)

py=""
for c in python3 python; do
  p=$(command -v "$c" 2>/dev/null) || continue
  # On a Mac without the developer tools, /usr/bin/python3 is only a stub that
  # asks to install them; skip it and use Perl instead. -Elvie
  if [ "$(uname)" = "Darwin" ] && [ "$p" = "/usr/bin/python3" ] && ! xcode-select -p >/dev/null 2>&1; then
    continue
  fi
  if "$p" -c 'import sys; sys.exit(sys.version_info < (3, 7))' >/dev/null 2>&1; then
    py=$p
    break
  fi
done

if [ -n "$py" ]; then
  exec "$py" "$here/serve.py"
elif command -v perl >/dev/null 2>&1; then
  exec perl "$here/serve.pl"
fi

echo
echo "  The sprite tools need Python 3 or Perl to run a small local server,"
echo "  and neither was found. Install Python 3 from https://www.python.org"
echo "  (or your system's package manager) and try again."
echo
exit 1
