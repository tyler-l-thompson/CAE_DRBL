#!/bin/bash
RUNAS=root
bond0.142:1(){
        case "$1" in
		on)
			su "$RUNAS" -c "ifconfig bond0.142:1 up -broadcast 192.168.100.254"
                        sleep 3
                        su "$RUNAS" -c "ifconfig"
                        echo "Port bond0.142:1 has been ENABLED"
			;;
        	off)
                        su "$RUNAS" -c "ifconfig bond0.142:1 down"
                        sleep 3
                        su "$RUNAS" -c "ifconfig"
                        echo "Port bond0.142:1 has been DISABLED"
			;;
		*)
                        echo $"Bad syntax recived for bond0.142:1(x)"
       			;;
	esac
}
bond0.142:2(){
        case "$1" in
                 on)
                        su "$RUNAS" -c "ifconfig bond0.142:2 up -broadcast 192.168.101.254"
                        sleep 3
                        su "$RUNAS" -c "ifconfig"
                        echo "Port bond0.142:2 has been ENABLED"
                        ;;
                off)
                        su "$RUNAS" -c "ifconfig bond0.142:2 down"
                        sleep 3
                        su "$RUNAS" -c "ifconfig"
                        echo "Port bond0.142:2 has been DISABLED"
                        ;;
                *)
                        echo $"Bad syntax recived for bond0.142:2(x)"
                        ;;
        esac
}
case "$1" in
	bond0.142:1)
		case "$2" in
			on)
				bond0.142:1 "on"
				;;
			off)
				bond0.142:1 "off"
				;;
			*)
				echo $"Usage: $0 $1 [on|off]"
				;;
		esac
		;;
	bond0.142:2)
		case "$2" in
			on)
				bond0.142:2 "on" 
				;;
			off)
				bond0.142:2 "off" 
				;;
			*)
				echo $"Usage: $0 $1 [on|off]"
				;;
		esac
		;;
	both)
		case "$2" in
			on)
				bond0.142:1 "on"
				bond0.142:2 "on"
				;;
			off)
				bond0.142:1 "off"
				bond0.142:2 "off"
				;;
			*)
				echo $"Usage: $0 $1 [on|off]"
				;;
		esac
		;;
	*)
		echo $"Usage: $0 [bond0.142:1|bond0.142:2|both] [on|off]"
		;;
esac
