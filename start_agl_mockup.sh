#!/bin/bash

REPO_DIR=$(cd $(dirname $0) && pwd)

if [ "$1" = "-d" ] || [ "$1" = "--dry" ]; then
    DRY="echo "
    shift
fi

function daemon() {
    name=$1
    port=$2
    logfile=$3
    shift; shift; shift
    opts=$*

    CMD="afb-daemon --port=${port} --name=${name} \
        --workdir=${REPO_DIR}/build/package --ldpaths=lib --roothttp=htdocs \
        --token= ${opts}"

    echo -n "Start ${name}... "
    if [ "$DRY" != "" ] || [ "$logfile" = " " ]; then
        ${DRY} ${CMD}
        logfile="null"
    elif [ "$logfile" = "bg" ]; then
        ${DRY} ${CMD} &
        logfile="null"
    else
        ${CMD} > ${logfile} 2>&1 &
        pid=$!
    fi
    echo "(pid $pid, logfile $logfile )"
    ${DRY} sleep 0.5
}

trap "cleanExit" 0 1 2 15
cleanExit ()
{
    ${DRY} pkill -9 afb-can_emulat
    ${DRY} pkill -9 afb-can_app
}

# Check Supervisor
if [ "$(ps -ef |grep afs-supervisor |wc -l)" != "2" ]; then
    echo "Please start supervisor in another shell: "
    echo " afs-supervisor --port 1712 --token HELLO --ws-server=unix:/tmp/supervisor -vv"
    exit 1
fi

# can emulator
daemon afb-can_emulator 1111 /tmp/can_emulator.log -vvv --ws-server unix:/tmp/can_emul

# can app
daemon afb-can_app 2222 bg -vv --ws-client unix:/tmp/can_emul

scenario=$1
[ "$scenario" = "" ] && scenario=1
${DRY} afb-client-demo 'localhost:2222/api?token=XXX&uuid=magic' can_app start '{"scenario": '${scenario}'}'

key=
while [ "$key" != "q" ]; do
    echo "Press 'q' to quit"
    read key
done
