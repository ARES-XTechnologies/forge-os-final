# FORGE OS live USB: run the installer automatically on the first screen.
[ -x ~/.automated_script.sh ] && ~/.automated_script.sh
if [[ "$(tty)" == "/dev/tty1" ]]; then
	/usr/local/bin/forge-install
fi
