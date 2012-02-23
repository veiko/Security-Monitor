#!/bin/bash
#
# A script to monitor various security items
#
# GTFO Security System


#Global variables
BAK="/usr/srv"
INPT=""

# Initialize program
vk_init() {
	# Check whether pv is installed
	hash pv 2>&- || { vk_install "pv"; }
	vk_menu
}

# Main menu
vk_menu() {
	vk_title "M A I N - M E N U"
	vk_choose 'Backups' 'Iptables' 'Networking' 'Services' 'Users' 'Watch'
	SEL=$INPT # Set the selected submenu
	vk_load
}

vk_choose() {
	local OPT=''
	echo -e "[m] Main Menu\n"
	# Iterate through passed parameters
	for ITM in "$@"
	do
		local LTTR=''
		local COUNT=0
		while [[ "$OPT" == *"$LTTR"* ]]; do		# Check whether this letter has already been used
			LTTR=${ITM:COUNT:1}									# Get the next letter of the string
			LTTR=${LTTR,,}
			((COUNT++))
		done
		OPT=$OPT','$LTTR											# Add the letter to the list of options
		echo "["${LTTR,,}"] "${ITM}						# Add item to the menu
	done
	echo -e "\n[q] Quit\n"
	vk_prompt "Enter your choice [m$OPT,q]"
	case $INPT in														# The two options m & q are always available
		'm') vk_menu ;;												# [m] Main Menu
		'q') vk_exit ;;												# [q] Quit
	esac
}

vk_prompt() {
	vk_rev "$1"
	read -n1 INPT
}

vk_load() {
	case $INPT in
		'b') vk_backups ;;
		'i') vk_iptables ;;
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

# Backup a folder or directory
vk_backups() {
	vk_title "B A C K U P S"
	if [ ! -e $BAK ]
	then
		mkdir $BAK
	fi
	vk_choose 'Backup a file' 'Restore backup' 'View stored backups'
	case $INPT in
		'b') vk_backup ;;
		'r') vk_restore ;;
		'v')
			vk_title "View stored backups"
			ls -lh $BAK | grep ".tgz" | awk '{printf("%s %s\n",$8,$5)}' | column -t
			vk_footer ;;
		*) vk_backups ;;
	esac
}

# Iptables
vk_iptables() {
	vk_title 'I P T A B L E S'
	vk_choose 'View firewall' 'Clear all rules' 'Save rules' 'Restore rules' 'Default firewall'
	case $INPT in
		'c')
			vk_title "Clear all rules"
			iptables -F
			vk_iptables_list
			vk_footer ;;
		'd')
			vk_iptables_defaults ;;
		'r') vk_iptables_restore ;;
		's') vk_iptables_save ;;
		'v')
			vk_title "View firewall"
			vk_iptables_list
			vk_footer ;;
		*) vk_iptables ;;
	esac
}

# Networking
function vk_network {
	vk_title 'N E T W O R K I N G'
	vk_choose 'Summary' 'Listening ports' 'Hosts connected'
	case $INPT in
		's')
			vk_title 'Summary'
			netstat -ant | awk '{print $NF}' | grep -v '[a-z]' | sort | uniq -c | awk '{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }' | column -t ;;
		'l')
			vk_title 'Listening ports'
			vk_bold 'netstat -tlnp'
			netstat -tlnp | grep LISTEN | awk 'BEGIN{print "LOCAL PID/COMMAND\n"}{printf("%s %s\n",$4,$7)}' | column -t
			vk_bold 'lsof -Pan -itcp -iudp'
			lsof -Pan -itcp -iudp | grep LISTEN | awk 'BEGIN{print "COMMAND PID USER LOCAL"}{printf("%s %s %s %s\n",$1,$2,$3,$9)}' | column -t
			vk_bold 'ss -alnp'
			ss -alnp | awk '{printf("%s %s\n",$3,$5)}' | column -t ;;
		'h')
			vk_title 'Hosts connected'
			netstat -an | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq -c | awk 'BEGIN{print "HOST CONNECTIONS"}{ printf("%s\t%s\t",$2,$1) ; for (i = 0; i < $1; i++) {printf("*")}; print "" }' | column -t;;
		*) vk_network ;;
	esac
	vk_footer
}

# Services
function vk_services {
	vk_title "S E R V I C E S"
	vk_choose 'Find port number or service name'
	case $INPT in
		'f')
			vk_title "Find port number or service name"
			read -p "Please enter the port number or name of service" INPT
			cat /etc/services | grep $INPT
			vk_footer ;;
		*) vk_services ;;
	esac
}

# Users
function vk_users {
	vk_title "U S E R S"
	vk_choose 'All Users' 'Check for irregularities' 'Groups' 'Processes run by users' 'Sudoers' 'User Details' 
	case $INPT in
		'a')
			vk_title 'All Users'
			cat /etc/passwd
			vk_footer ;;
		'c') echo "Nothing Yet" ;;
		'g')
			vk_title "Groups"
			awk -F: '{printf("%s %s > %s\n",$3,$1,$4)}' /etc/group | column
			vk_footer ;;
		'p')
			vk_title 'Processes'
			ps hax -o user | sort | uniq -c | awk '{printf("%s\t%s\t",$2,$1);for(i=0;i<$1;i++){printf("*")};print("")}' | column -t
			vk_footer ;;
		's')
			vk_title 'Sudoers'
			cat /etc/sudoers
			vk_footer ;;
		'u')
			vk_title 'User Details'
			awk -F: 'BEGIN{print("USER:GROUP:DETAILS:HOME DIR:SHELL")}{printf("%s %s:%s:%s:%s:%s\n",$3,$1,$4,$5,$6,$7)}' /etc/passwd | column -ts:
			read -p "Enter a users ID to view further details" INPT
			local USER=`getent passwd $INPT`
			USER=${USER%%:*}
			vk_title 'User Information: '$USER
			id $USER
			echo
			ps af -u $USER
			echo
			chage -l $USER
			vk_footer ;;
		*) vk_users ;;
	esac
}

function vk_watch {
	vk_title "W A T C H"
	vk_choose 'Find files with setuid' 'Last commands performed in MySql'
	case $INPT in
		'f')
			find / -type f \( -perm -4000 -o -perm -2000 \) -print
			vk_footer ;;
		'l')
			echo 'watch -n 1 mysqladmin --user=<user> --password=<password> processlist'
			vk_footer ;;
		*) vk_watch ;;
	esac
}

########################
### COMMON FUNCTIONS ###
########################

function vk_exit {
	echo -e "\n\nExiting...\n"
	exit
}

function vk_backup {
	local PTH
	local OTPT
	vk_title "B A C K U P S - Performing Backup"
	vk_bold "Path to the file or directory to be backed up: "
	read -e PTH
	### Check that path is valid
	while [[ -z $PTH || ! -e $PTH ]]; do
		echo "Invalid path: Empty path or file does not exist. Please try again."
		read -e path
	done
	echo
	vk_underline "\nList of files present in $BAK"
	ls $BAK
	vk_bold "\nName of the file to be created: "
	read OTPT
	vk_underline "tar -cf - $PTH | pv -s $(du -sb . | awk '{print $1}') | gzip > $BAK/$OTPT.tgz"
	tar -cf - $PTH | pv -s $(du -sb . | awk '{print $1}') | gzip > $BAK/$OTPT.tgz
	vk_footer
}

function vk_restore {
	local FL
	local PTH
	vk_title "B A C K U P S - Performing Backup"
	vk_underline "List of files present in $BAK"
	ls $BAK
	vk_bold "Select the file you would like to restore: "
	read -e FL
	while [[ -z $FL || ! -e $BAK/$FL ]]; do
		vk_err "Invalid file. Please try again."
		read -e FL
	done
	vk_bold "Enter the parent directory to where the file will be restored: "
	read -e PTH
	while [[ -z $PTH || ! -e $PTH ]]; do
		vk_err "Invalid path. Please try again."
		read -e PTH
	done
	echo
	vk_underline "gzip -cd $BAK/$FL | tar -xC $PTH"
	# Actual backup is not performed yet
	# gzip -cd $BAK/$FL | tar -xC $PTH
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
		vk_rev " $* \n"
	fi
}

##########################
### IPTABLES FUNCTIONS ###
##########################

vk_iptables_list() {
	iptables -vL | grep -v "Chain" | grep -v 'target' | awk 'BEGIN{print("TARGET;PRT;INT;SOURCE IP;DEST IP")}{printf("%s;%s;%s;%s;%s",$3,$4,$6,$8,$9);$1=$2=$3=$4=$5=$6=$7=$8=$9="";print($0)}' | column -ts\;
}

vk_iptables_defaults() { 
	vk_title "Restore defaults"
	vk_prompt "Are you sure you want to restore defaults? [y,n]"
	if [ $INPT = 'y' ]
	then
		iptables -F
		echo "[1] Allow anything on loopback interface"
		iptables -A INPUT -i lo -j ACCEPT
		echo "[2] Allow previously established connections"
		iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
		echo "[3] Allow inbound SSH connection"
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
		echo "[4] Allow DNS"
		iptables -A OUTPUT -p udp --sport 1024:65535 --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
		iptables -A INPUT -p udp --sport 53 --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
		iptables -A OUTPUT -p tcp --sport 1024:65535 --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
		iptables -A INPUT -p tcp --sport 53 --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
		echo "[5] Allow connecting to the internet"
		iptables -A OUTPUT -p tcp --sport 1024:65535 --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
		echo "[6] Set default policy to drop for all other connections"
		iptables -A INPUT -j DROP
		iptables -A OUTPUT -j DROP
		vk_footer
	else
		vk_iptables
	fi
}

# Restore saved iptables
vk_iptables_restore() {
	vk_title "Restoring iptables"
	gpg -o $BAK/selbatpi $BAK/selbatpi.gtfo							# Unencrypt rules file
	`which iptables-restore` < $BAK/selbatpi						# Restore from encrypted file to avoid polluted rules
	rm $BAK/selbatpi																		# Remove unencrypted file
	vk_bold "Iptables restored succesfully"
	vk_footer
}

# Save iptables
vk_iptables_save() {
	vk_title "Saving iptables"
	`which iptables-save` > /etc/default/iptables				# Save iptables to default location
	`which iptables-save` > $BAK/selbatpi								# Save to file in backup folder as well
	gpg -c $BAK/selbatpi																# Encrypt saved rules
	rm $BAK/selbatpi																		# Remove unencrypted version
	mv $BAK/selbatpi.gpg $BAK/selbatpi.gtfo							# Rename gpg to something less obvious
	vk_bold "Iptables saved succesfully"
	vk_footer
}

trap 'vk_err "\n\nAAAARRRRRGGGGGGGHHHHHHH....\n"; exit;' INT
vk_init
