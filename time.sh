# time.sh - simple flat/top-level timing measurement helper for shell scripts
# Copyright 2018 Avi Halachmi   @License MIT   https://github.com/avih/time.sh
#
# Example (see README.md for more info):
#   . /path/to/time.sh
#   time_switch_to foo
#   <do task foo>
#   time_switch_to "bar baz"
#   <do bar maybe with an argument baz>
#   time_finish


[ "${TIME_PRINT-}" ] || TIME_PRINT=3

# find a command to print a timestamp in ms, or fail to 'echo 0'.
# perl/python will have bigger overhead, but we auto-compensate reasonably-ish.
if [ -z "${TIME_CMD-}" ]; then
    for TIME_CMD in \
        'date +%s%3N' \
        'python -c "from time import time; print (int(time()*1000))"' \
        'perl -MPOSIX=strftime -MTime::HiRes=time -le "print int(time*1000)"' \
        'date +%s000' \
        'echo 0' ;
    do
        _tsh_tmp=$(eval "$TIME_CMD" 2>/dev/null) &&
            case $_tsh_tmp in *[!0-9]*|'') ;;  *) break; esac
    done
fi

_tsh_started=
_tsh_NL="
"

# stops the measurement if one was started, and start a new one named $1
# only one measurement at a time is supported, and one (automatic) overall.
time_switch_to() {
    _tsh_now=$(eval "$TIME_CMD")

    if [ "$_tsh_started" ]; then
        _tsh_dur=$(( _tsh_now - _tsh_t0 - TIME_COMP ))
        [ $_tsh_dur -ge 0 ] || _tsh_dur=0
        time_total=$(( time_total + _tsh_dur ))
        time_details="${time_details}${_tsh_dur} $_tsh_name${_tsh_NL}"
        case $TIME_PRINT in 2|3) >&2 echo "[ $_tsh_name: $_tsh_dur ms ]"; esac
    else
        _tsh_started=yes; time_total=0; time_details=
    fi

    case ${1-} in
        --|'') _tsh_started= ;;  # "finish". caller can use total and details
            *) _tsh_name=$1
               _tsh_t0=$_tsh_now
               case $TIME_PRINT in 1|3) >&2 echo "[ $1  ... ]"; esac
    esac
}

# assess compensation in ms/measure, floored to err on the side of caution.
# not perfect since cpu frequency scaling can change etc, but reasonable.
_tsh_assess_overhead() {
    TIME_PRINT=0; TIME_COMP=0
    time_switch_to x; time_switch_to --  # warmup and reset
    for x in 1 2 3 4; do time_switch_to $x; done; time_switch_to --
    echo $(( time_total / 4 ))  # 5 calls = 4 deltas, floored average
}

case ${TIME_COMP-} in *[!0-9]*|'') TIME_COMP=$(_tsh_assess_overhead); esac

# $1: number, $2: number to be printed as rounded percentage (number) of $1
_tsh_percent() {
    [ "$1" -gt 0 ] || set -- 1 0
    [ "$2" -ge 0 ] || set -- $1 0
    echo $(( (200 * $2 / $1 + 1 ) / 2 ))
}

# print a summary and reset the measurements. slow-ish but outside the measure.
# percentage values are rounded and might not add up to 100.
time_finish() {
    time_switch_to --
    _tsh_shell="$(basename "$( (readlink /proc/$$/exe || ps -o comm= -p $$) 2>/dev/null)")"

    >&2 printf "\n%s\n%s ms%s, %s ms/measure, %s\n%s\n" \
        ----- \
        $time_total "${TIME_TITLE:+ - $TIME_TITLE}" \
        $TIME_COMP "$(uname)${_tsh_shell:+/$_tsh_shell}" \
        -----

    printf %s "$time_details" | sort -rn | \
        (while read line; do
            >&2 printf "%${#time_total}s ms %3s %%  %s\n" \
                "${line%% *}" "$(_tsh_percent $time_total $line)" "${line#* }"
        done)

    >&2 printf "%s\n" -----
}
