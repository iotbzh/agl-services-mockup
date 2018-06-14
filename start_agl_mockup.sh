#!/bin/bash

AGL_MOCKDIR="/tmp/agl_mockup"
REPO_DIR=$(cd $(dirname $0) && pwd)

if [ "$1" = "-d" ] || [ "$1" = "--dry" ]; then
    DRY="echo "
    shift
fi

pids=""

function daemon() {
    name=$1
    port=$2
    logmode=$3
    shift; shift; shift
    opts=$*

    CMD="afb-daemon --port=${port} --name=${name} \
        --workdir=${REPO_DIR}/build/package --ldpaths=lib --roothttp=htdocs \
        --token= ${opts}"

    echo -n "Start ${name}... "
    pid=""
    logfile=${AGL_MOCKDIR}/${name}.log
    if [ "$DRY" != "" ] || [ "$logmode" = "none" ]; then
        ${DRY} ${CMD}
        pid=$!
        logfile="null"
    elif [ "$logfile" = "bg" ]; then
        ${DRY} ${CMD} &
        logfile="null"
    else
        ${CMD} > ${logfile} 2>&1 &
        pid=$!
    fi
    echo "(pid $pid, logfile $logfile )"

    [ "$pid" != "" ] && pids="${pids} ${pid}"

    ${DRY} sleep 0.5
}

trap "cleanExit" 0 1 2 15
cleanExit ()
{
    for pp in ${pids}; do
        ${DRY} kill -9 ${pp}
    done
 #   ${DRY} pkill -9 afb-can_emulat
 #   ${DRY} pkill -9 afb-can_app
}

# Check Supervisor
if [ "$(ps -ef |grep afs-supervisor |wc -l)" != "2" ]; then
    echo "Please start supervisor in another shell: "
    echo " afs-supervisor --port 1712 --token HELLO --ws-server=unix:${AGL_MOCKDIR}/supervisor -vv"
    exit 1
fi

[ ! -d "$AGL_MOCKDIR" ] && mkdir -p "$AGL_MOCKDIR"

# GPS emulator & app
daemon afb-gps_emulator 1101 log -vvv --ws-server unix:${AGL_MOCKDIR}/gps_emul
daemon afb-gps_app 1102 log -vv --ws-client unix:${AGL_MOCKDIR}/gps_emul

# CAN emulator & app
daemon afb-can_emulator 2201 log -vvv --ws-server unix:${AGL_MOCKDIR}/can_emul
daemon afb-can_app 2202 log -vv --ws-client unix:${AGL_MOCKDIR}/can_emul
#daemon afb-can_app 2202 bg -vv --ws-client unix:${AGL_MOCKDIR}/can_emul --monitoring

#echo "Wait 5 seconds..."
#${DRY} sleep 5
echo "Press any key to send 'can_app start' command..."
${DRY} read

echo "Send GPS start..."
rate=1000
${DRY} afb-client-demo 'localhost:1102/api?token=XXX&uuid=magic' gps_app start '{"sample_rate": '$rate'}'

echo "Send CAN start..."
scenario=$1
[ "$scenario" = "" ] && scenario=1
${DRY} afb-client-demo 'localhost:2202/api?token=XXX&uuid=magic' can_app start '{"scenario": '${scenario}'}'

if [ "${DRY}" != "echo" ]; then
    key=
    while [ "$key" != "q" ]; do
        echo "Press 'q' to quit"
        read key
    done
fi

echo "Exiting start_agl_mockup script..."
