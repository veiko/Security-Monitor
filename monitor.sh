#!/bin/bash

#Global variables
backup_path="/usr/srv"
current_submenu=""
last_input=""

function vk_init {
	# Check for pv, this is used to view a graphical representation of a processes progress
	hash pv 2>&- || { vk_install "pv"; }
	vk_menu
}

function vk_menu {
	vk_title "M A I N - M E N U"
	vk_choose 'Backups' 'Networking' 'Services' 'Users' 'Watch'
	current_submenu=$last_input
	vk_load
}

function vk_choose {
	local options=''
	echo "[m] Main Menu"
	echo
	for menu_item in "$@"
	do
		local shortcut=${menu_item:0:1}
		options=$options','${shortcut,,}
		echo "["${shortcut,,}"] ${menu_item}"
	done
	echo
	echo "[q] Quit"
	echo
	tput bold
	tput rev
	echo -n "Enter your choice [m$options,q]"
	tput sgr0
	read -n1 last_input
	case $last_input in
		'm') vk_menu ;;
		'q') vk_exit ;;
	esac
}

#########################
### MAIN MENU OPTIONS ###
#########################

### Backup a folder or directory
function vk_backups {
	vk_title "B A C K U P S"
	vk_choose 'Backup a file' 'View stored backups' 'Change backup location'
	case $last_input in
		'b')
			vk_backup ;;
		'v')
			vk_title "Viewing stored backups"
			ls -lh $backup_path | grep ".tgz" | awk '{printf("%s %s\n",$8,$5)}' | column -t
			vk_menu2 ;;
		*)
			vk_backups ;;
	esac
}

# Check networking status
function vk_network {
	vk_title "N E T W O R K I N G"
	tput bold
	echo "All connections"
	tput sgr0
	netstat -ant | awk '{print $NF}' | grep -v '[a-z]' | sort | uniq -c
	tput bold
	echo "Listening on ports"
	tput sgr0
	netstat -tlnp | grep LISTEN | awk 'BEGIN{print "LOCAL PID/ProgramName"}{printf("%s %s\n",$4,$7)}' | column -t
	tput bold
	echo "Established connections per host"
	tput sgr0
	netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }'
#			ssFile="/tmp/ss"
#		if [ -e "$ssFile" ]
#		then
#			diff /tmp/ss <(ss)
#		fi
#		ss > /tmp/ss
	vk_menu2
}

function vk_services {
	vk_title "S E R V I C E S"
	vk_choose 'Find port number or service name'
	case $last_input in
		'f')
			vk_title "Find port number or service name"
			read -p "Please enter the port number or name of service: " last_input
			cat /etc/services | grep $last_input
			vk_menu2 ;;
		'm')
			vk_menu ;;
		'q')
			vk_exit ;;
		*)
			vk_services ;;
	esac
}

function vk_users {
	vk_title "U S E R S"
	vk_choose 'Check for irregularities' 'Groups' 'Sudoers' 'Users'
	case $last_input in
		'q')
			vk_exit ;;
		'm')
			vk_menu ;;
		'g')
			vk_title "Display Groups"
			awk -F: '{printf("%s %s -> x%s\n",$3,$1,$4)}' /etc/group | column
			vk_menu2 ;;
		*)
			vk_users ;;
	esac
}

function vk_watch {
	vk_title "W A T C H"
	echo "watch -n 1 mysqladmin --user=<user> --password=<password> processlist"
	vk_choose 'Database commands'
}

########################
### COMMON FUNCTIONS ###
########################

function vk_exit {
	echo ""
	echo "Exiting..."
	echo ""
	exit
}

function vk_backup {
	vk_title "B A C K U P S - Performing Backup"
	tput bold
	echo "Path to the file or directory to be backed up: "
	tput sgr0
	read -e path
	### Check that path is valid
	while [[ -z $path || ! -e $path ]]; do
		echo "Invalid path: Empty or file does not exist. Please try again."
		read -e path
	done
	echo
	tput bold
	echo "List of files already present in $backup_path"
	tput sgr0
	ls $backup_path
	tput bold
	echo -n "Name of the file to be created: "
	tput sgr0
	read output_file
	while [[ -z $path || ! -e $path ]]; do
		echo "Invalid path: Empty or file does not exist. Please try again."
		read -e path
	done
	### Check that directory exists
	if [ ! -e /usr/srv ]
	then
		mkdir /usr/srv
	fi
	tput smul
	echo "tar -cf - $path | pv -s $(du -sb . | awk '{print $1}') | gzip > $backup_path/$output_file.tgz"
	tput rmul
	tar -cf - $path | pv -s $(du -sb . | awk '{print $1}') | gzip > $backup_path/$output_file.tgz
	vk_menu2
}

function vk_install {
	echo "Command $1 not found"
	echo "Installing $1"
	apt-get install $1 2>&- || echo "Installation could not be completed."; return
	tput bold
	read -n 1 -p "Installation of $1 complete. Hit <Enter> to continue." test
	tput sgr0
}

function vk_load {
	case $last_input in
		'q')
			vk_exit ;;
		'b')
			vk_backups ;;
		'n')
			vk_network ;;
		's')
			vk_services ;;
		'u')
			vk_users ;;
		'w')
			vk_watch ;;
		*)
			vk_menu ;;
	esac
}

function vk_load_test {
	case $last_input in
		'Quit')
			vk_exit ;;
		'Backups')
			vk_backups ;;
		'Networking')
			vk_network ;;
		'Services')
			vk_services ;;
		'Users')
			vk_users ;;
		*)
			vk_menu ;;
	esac
}

function vk_menu2 {
	echo
	echo
	tput rev
	read -n 1 -p "[r] return [m] return to main menu [q] quit " choice
	tput sgr0
	case $choice in
		'm') vk_menu ;;
		'r')
			last_input=$current_submenu
			vk_load ;;
		*)
			echo ""
			echo "Unknown command. Please try again."
			vk_menu2 ;;
	esac
}

function vk_title {
	tput clear
	tput bold
	tput setaf 5
	echo "GTFO Security Tutorial"
	tput sgr0
	echo
	if [ "${#1}" -gt 0 ]
	then
		tput rev
		echo " $1 "
		echo
		tput sgr0
	fi
}

trap 'echo "AAAARRRRRGGGGGGGHHHHHHH...."; exit;' INT
vk_init
