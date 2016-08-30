function ver_cmp() {
    local ver1="$1"
    local ver2="$2"
    declare -i fields="$3"

    if [[ "${fields}" -eq 0 ]] ; then
        [[ "${ver1%%.*}" -le "${ver2%%.*}" ]]
        return $?
    fi

    [[ "${ver1%%.*}" -lt "${ver2%%.*}" ]] && return $? || \
        ver_cmp "${ver1#*.}" "${ver2#*.}" "$((--fields))"
}

function main() {
    declare -a fields
    local ver1="${1:-1.4.500}"
    local ver2="${2:-1.4.55}"
    declare -i rc=0

    if [[ "${#ver1}" -ne "${#ver2}" ]] ; then
        return 3
    fi

    grep -Eq '[0-9]+\.[0-9]+\.[0-9]+' <<<"${ver1}"
    rc=$((rc+$?))
    grep -Eq '[0-9]+\.[0-9]+\.[0-9]+' <<<"${ver2}"
    rc=$((rc+$?))

    if (($rc)) ; then
        return ${rc}
    fi

    IFS='.' read -r -a fields <<<"${ver1}"
    ver_cmp "${ver1}" "${ver2}" "${#fields[@]}"
}

main "$@"
