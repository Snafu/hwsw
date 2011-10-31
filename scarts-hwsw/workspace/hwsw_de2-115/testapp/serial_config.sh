#!/bin/sh

COM=/dev/ttyS0

SERIALCONFIG="115200 parenb -parodd cs8 -hupcl -cstopb cread clocal -crtscts ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel -iutf8 -opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0 -isig -icanon -iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop -echoprt -echoctl -echoke"

case $1 in
        "init")
                echo "initializing Com1 ..."
                echo "stty -F $COM $SERIALCONFIG"
                stty -F $COM $SERIALCONFIG
        ;;
        "listen")
                echo "waiting for replay ..."
                echo "cat $COM"
                cat $COM
        ;;
        "write")
                if test -z $2
                then
                        echo "********************************************"
                        echo "Usage: $0 write <filename>"
                        echo "********************************************"
                else
                        echo "cat $2 > $COM"
                        cat $2 > $COM
                fi
        ;;
        "status")
                echo "status of $COM ..."
                echo "stty -F $COM --all"
                stty -F $COM --all
        ;;
        *)
                echo "Usage: $0 (init|listen|write|status) [filename]"
        ;;
esac


