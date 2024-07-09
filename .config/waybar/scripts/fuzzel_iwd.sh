#!/usr/bin/env zsh

set -ex

script=`basename "$0"`
pathname=`dirname "$0"`

help="$script [-h/--help] -- script to connect to wlan with iwd
  Usage:
    depending on how the script is named,
    it will be executed either with dmenu, with rofi
    or fuzzel.
  Examples:
    dmenu_iwd.sh
    rofi_iwd.sh
    fuzzel_iwd.sh
    wofi_iwd.sh"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    printf "%s\n" "$help"
    exit 0
fi

function fuzzel() {
    command fuzzel -d -w 75 "$@"
}

function ssid-scan(){
    eval "$pathname/iwd-scan.py $@"
}

function percentage() {
  if [[ -z "$strength" ]]
  then
      return
  fi

  offset=$(( $strength + 110 ))
  progress=$(( $offset * 100 / 180 ))

  progress=""
  k=$(( $offset / 10))
  echo $offset $k
  progress="["
  for ((ii = 0 ; ii <= k; ii++)); do progress="$progress█"; done
  for ((j = ii ; j <= 10 ; j++)); do progress="$progress "; done
  progress="$progress] "
}

label_interface=""
menu_interface="fuzzel -p '$label_interface'"
label_ssid=""
menu_ssid="fuzzel -p '$label_ssid'"
label_psk="🔒"
menu_psk="fuzzel -p '$label_psk'"

remove_escape_sequences() {
    tail -n +5 \
        | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g;/^\s*$/d"
}

get_interface() {
    interface=$(iwctl device list \
        | remove_escape_sequences \
        | awk '{printf("%-12s %-9s %s\n", $1, $2, $3)}' \
        | eval $menu_interface \
        | awk '{print $1}'
    )
    [ -n "$interface" ] \
        || exit 1
}

scan_ssid() {
    scan_result=("${(@f)$(ssid-scan)}")
    scan_result_formatted=""
    for (( i=1; i<$#scan_result; i+=4 ))
    do
        ssid=${scan_result[$i]}
        strength=${scan_result[$i+1]}
        security=${scan_result[$i+2]}
        connected=${scan_result[$i+3]}

        if [[ $connected = "1" ]]
        then
            connected="✅"
        else
            connected="  "
        fi

        percentage
        echo $progress
        printf -v scan_result_formatted "$scan_result_formatted%s%-42ls %s dBm   %-6s   %s\n" $connected $ssid $strength $security $progress
    done
}

get_ssid() {
    select=`echo "🔄[RESCAN]\n"$scan_result_formatted | eval $menu_ssid`
    if [[ -z "$select" ]]
    then
        exit
    elif [[ "$select" = "🔄[RESCAN]" ]]
    then
        scan_ssid
        get_ssid
        return
    fi

    to_array=(${(f)scan_result_formatted})
    selectedIndex=${to_array[(Ie)$select]}
    print $selectedIndex
    selectedIndex=$(( $(( $selectedIndex - 1 )) * 4 ))
    selectedIndex=$(( $selectedIndex + 1 ))

    i_ssid=${scan_result[$selectedIndex]}
    i_strength=${scan_result[$selectedIndex +1]}
    i_security=${scan_result[$selectedIndex+2]}
    i_connected=${scan_result[$selectedIndex+3]}

    if [[ $i_connected = "1" ]]
    then
        i_connected="✅"
    else
        i_connected="  "
    fi

    print "found a match $i_ssid"
    ssid=$i_ssid
}

get_psk() {
    psk=$(printf 'press esc or enter if you had already insert a passphrase before!\n' \
        | eval $menu_psk \
    )
}

connect_iwd() {
    if [[ "$open" = 1 ]]
    then
        iwctl station "$interface" connect ''$ssid''
    else
        get_psk
        iwctl station "$interface" connect "$ssid" -P "$psk"
    fi
    notify-send "iNet wireless daemon" "connected to \"$ssid\""
}

get_interface \
    && scan_ssid \
    && get_ssid \
    && connect_iwd
