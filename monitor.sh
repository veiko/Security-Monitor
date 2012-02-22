#!/bin/bash

#Global variables
BAK="/usr/srv"
INPT=""

function vk_init {
	# Check for pv, this is used to view a graphical representation of a processes progress
	hash pv 2>&- || { vk_install "pv"; }
	vk_menu
}

function vk_menu {
	vk_title "M A I N - M E N U"
	vk_choose 'Backups' 'Networking' 'Services' 'Users' 'Watch'
	SEL=$INPT
	vk_load
}

function vk_choose {
	local OPT=''
	echo -e "[m] Main Menu\n"
	for ITM in "$@"
	do
		local LTTR=${ITM:0:1}
		OPT=$OPT','${LTTR,,}
		echo "["${LTTR,,}"] ${ITM}"
	done
	echo -e "\n[q] Quit\n"
	vk_prompt "Enter your choice [m$OPT,q]"
	case $INPT in
		'm') vk_menu ;;
		'q') vk_exit ;;
	esac
}

function vk_prompt {
	vk_rev "$1"
	read -n1 INPT
}

function vk_load {
	case $INPT in
		'b') vk_backups ;;
		'n') vk_network ;;
		's') vk_services ;;
		'u') vk_users ;;
		'w') vk_watch ;;
		*) vk_menu ;;
	esac
}

#########################
### MAIN MENU OPTIONS ###
#########################

### Backup a folder or directory
function vk_backups {
	vk_title "B A C K U P S"
	if [ ! -e $BAK ]
	then
		mkdir $BAK
	fi
	vk_choose 'Backup a file' 'View stored backups'
	case $INPT in
		'b') vk_backup ;;
		'v')
			vk_title "View stored backups"
			ls -lh $BAK | grep ".tgz" | awk '{printf("%s %s\n",$8,$5)}' | column -t
			vk_footer ;;
		*) vk_backups ;;
	esac
}

# Check networking status
function vk_network {
	vk_title 'N E T W O R K I N G'
	vk_choose 'Summary' 'Listening ports' 'Hosts connected'
	case $INPT in
		's')
			vk_title 'Summary'
			netstat -ant | awk '{print $NF}' | grep -v '[a-z]' | sort | uniq -c ;;
		'l')
			vk_title 'Listening ports'
			vk_bold 'netstat'
			netstat -tlnp | grep LISTEN | awk 'BEGIN{print "LOCAL PID/COMMAND\n"}{printf("%s %s\n",$4,$7)}' | column -t
			vk_bold 'lsof'
			lsof -Pan -i tcp -i udp | grep LISTEN | awk 'BEGIN{print "COMMAND PID USER LOCAL"}{printf("%s %s %s %s\n",$1,$2,$3,$9)}' | column -t
			vk_bold 'ss'
			ss -alnp | awk '{printf("%s %s\n",$3,$5)}' | column -t ;;
		'h')
			vk_title 'Hosts connected'
			netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }' ;;
		*) vk_network ;;
	esac
	vk_footer
}

function vk_services {
	vk_title "S E R V I C E S"
	vk_choose 'Find port number or service name'
	case $INPT in
		'f')
			vk_title "Find port number or service name"
			vk_prompt "Please enter the port number or name of service"
			cat /etc/services | grep $INPT
			vk_footer ;;
		*) vk_services ;;
	esac
}

function vk_users {
	vk_title "U S E R S"
	vk_choose 'Check for irregularities' 'Groups' 'Sudoers' 'Users' 'Processes'
	case $INPT in
		'g')
			vk_title "Groups"
			awk -F: '{printf("%s %s -> x%s\n",$3,$1,$4)}' /etc/group | column
			vk_footer ;;
		'p')
			vk_title 'Processes'
			ps hax -o user | sort | uniq -c | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }' | column -t
			vk_footer ;;
		*) vk_users ;;
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
	echo -e "\n\nExiting...\n"
	exit
}

function vk_backup {
	vk_title "B A C K U P S - Performing Backup"
	vk_bold "Path to the file or directory to be backed up: "
	read -e path
	### Check that path is valid
	while [[ -z $path || ! -e $path ]]; do
		echo "Invalid path: Empty or file does not exist. Please try again."
		read -e path
	done
	echo
	vk_bold "List of files already present in $BAK"
	ls $BAK
	vk_bold "Name of the file to be created: "
	read output_file
	vk_underline "tar -cf - $path | pv -s $(du -sb . | awk '{print $1}') | gzip > $BAK/$output_file.tgz"
	tar -cf - $path | pv -s $(du -sb . | awk '{print $1}') | gzip > $BAK/$output_file.tgz
	vk_footer
}

function vk_bold {
	tput bold
	echo -e "$1"
	tput sgr0
}

function vk_rev {
	tput rev
	echo -e "$1"
	tput sgr0
}

function vk_underline {
	tput smul
	echo -e "$1"
	tput rmul
}

function vk_err {
	tput setaf 1
	vk_rev "$1\n"
}

function vk_install {
	echo -e "Command $1 not found\nInstalling $1"
	apt-get install $1 2>&- || echo "Installation could not be completed."; return
	tput bold
	read -n 1 -p "Installation of $1 complete. Hit <Enter> to continue." test
	tput sgr0
}

function vk_footer {
	vk_prompt "\n[b] Back [m] Main Menu [q] Quit"
	case $INPT in
		'b')
			INPT=$SEL
			vk_load ;;
		'm') vk_menu ;;
		'q') vk_exit ;;
		*)
			vk_err "\nUnknown command. Please try again."
			vk_footer ;;
	esac
}

function vk_title {
	tput clear
	tput setaf 5
	vk_bold "GTFO Security\n"
	if [ "${#1}" -gt 0 ]
	then
		vk_rev " $1 \n"
	fi
}

trap 'vk_err "\n\nAAAARRRRRGGGGGGGHHHHHHH....\n"; exit;' INT
vk_init
