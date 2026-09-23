#!/bin/bash
# Prints: <state>\t<operator>\t<signal-percent>\t<own-number>\t<access-tech>\t<nm-uuid>
# state is one of: none (no modem present), registered, connected, ...
# nm-uuid is the NetworkManager gsm connection profile to act on for
# connect/disconnect, empty if no gsm profile exists yet.

nm_uuid=$(nmcli -t -f TYPE,UUID connection show 2>/dev/null | awk -F: '$1 == "gsm" {print $2; exit}')

command -v mmcli >/dev/null 2>&1 || { printf 'none\t\t\t\t\t%s\n' "$nm_uuid"; exit 0; }

modem=$(mmcli -L 2>/dev/null | grep -oE '/org/freedesktop/ModemManager1/Modem/[0-9]+' | head -n1)
if [[ -z $modem ]]; then
  printf 'none\t\t\t\t\t%s\n' "$nm_uuid"
  exit 0
fi

kv=$(mmcli -m "$modem" --output-keyvalue 2>/dev/null)
state=$(awk -F': ' '/modem\.generic\.state /{print $2; exit}' <<<"$kv")
signal=$(awk -F': ' '/modem\.generic\.signal-quality\.value/{print $2; exit}' <<<"$kv")
operator=$(awk -F': ' '/modem\.3gpp\.operator-name/{print $2; exit}' <<<"$kv")
number=$(awk -F': ' '/modem\.generic\.own-numbers\.value\[1\]/{print $2; exit}' <<<"$kv")
tech=$(awk -F': ' '/modem\.generic\.access-technologies\.value\[1\]/{print $2; exit}' <<<"$kv")

printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${state:-unknown}" "${operator:-Mobile}" "${signal:--1}" "$number" "$tech" "$nm_uuid"
