#!/bin/bash
#Easy script to join an Ubuntu Desktop to an Active Directory domain
#Script para unir fácilmente un cliente Ubuntu/Fedora/Elementary a Dominio de Active Directory
#Tested on Ubuntu 16.04 LTS (Xenial) and Ubuntu 14.04 (Trusty) LTS
#Tested on Fedora 25 BETA and Fedora 24
#Tested on Elementary OS 4
#Visit beclimyfriend.blogspot.com for more!!
#Visita beclimyfriend.blogspot.com para más!! 
#Created by Joan Chacón

#Function that contains all the process for joining a fedora client
fedora_join () {

	echo "Would you like to install the required packages?(Y/N)"
	read ans

		if [ "$ans" == "y" ] || [ "$ans" == "Y" ]
		then
			dnf -y install realmd sssd oddjob oddjob-mkhomedir adcli samba-common-tools
		fi

	clear

	echo "Introduce your primary network interface (ex; enp0s3):"
	read iface

	echo "Introduce the IP adress from your domain DNS server:"
	read dns

	nmcli c modify $iface ipv4.dns $dns
	nmcli c down $iface
	nmcli c up $iface

	echo "Introduce your domain name (ex; mydomain.local):"
	read dom

	echo "Showing info from $dom:"
	realm discover $dom
	echo "Press any key to continue..."
	read cont
	ok=0

		while [ $ok -eq 0 ]
		do

			echo "Introduce your hostname (ex; fedoradesk)"
			read hname
			echo "Your workstation will be named as $hname.$dom ¿Continue(Y/N)?"
			read ans

			if [ "$ans" == "y" ] || [ "$ans" == "Y" ]
			then
				hostnamectl set-hostname --static "$hname.$dom"
				ok=1
			fi
		done

	upper=${dom^^}

	realm join $upper

	yum install -y authconfig-gtk

	system-config-authentication

	systemctl enable sssd.service

	systemctl restart sssd.service

}

#Function that generates /etc/realmd.conf config file
write_realmd () {

	echo "[users]" >> /etc/realmd.conf
	echo "default-home = /home/%D/%U" >> /etc/realmd.conf
	echo "default-shell = /bin/bash" >> /etc/realmd.conf
	echo "[active-directory]" >> /etc/realmd.conf
	echo "default-client = sssd" >> /etc/realmd.conf
	echo "os-name = Ubuntu Desktop Linux" >> /etc/realmd.conf
	echo "os-version = 16.04" >> /etc/realmd.conf
	echo "[service]" >> /etc/realmd.conf
	echo "automatic-install = no" >> /etc/realmd.conf
	echo "[$1]" >> /etc/realmd.conf
	echo "fully-qualified-names = no" >> /etc/realmd.conf
	echo "automatic-id-mapping = yes" >> /etc/realmd.conf
	echo "user-principal = yes" >> /etc/realmd.conf
	echo "manage-system = no" >> /etc/realmd.conf

}
#Function that generates /etc/lightdm/lightdm.conf.d/lightdm.conf config file
write_lightdm () {

	echo "[SeatDefaults]" >> /etc/lightdm/lightdm.conf.d/lightdm.conf
	echo "allow-guest=false" >> /etc/lightdm/lightdm.conf.d/lightdm.conf
	echo "greeter-show-manual-login=true" >> /etc/lightdm/lightdm.conf.d/lightdm.conf

}

echo "Linuxdomjoin script, tested on Ubuntu 16/14.04 / Elementary OS 4 / Fedora 25/24"
echo "Visit beclimyfriend.blogspot.com for more, hope it helps you!!"
echo "Joan Chacón"

#Asks for the distro
echo "Select your Linux distro Ubuntu(U)/Fedora(F)/ElementaryOS(E)"
read distro

if [ "$distro" == "F" ] || [ "$distro" == "f" ] 
then
	fedora_join

elif [ "$distro" == "U" ] ||[ "$distro" == "u" ] || [ "$distro" == "E" ] || [ "$distro" == "e" ]
then 

	echo "Would you like to install the required packages (Y), or join domain directly? (N)"
	read updt

	if [ "$updt" == "Y" ] || [ "$updt" == "y" ]
	then

		#Upgrades packages
		apt-get update
		#Installs the required packages
		apt-get install -y realmd sssd sssd-tools samba-common krb5-user packagekit samba-common-bin samba-libs adcli ntp
		clear
	fi
	#Asks for domain name
	echo "Introduce your domain name (ex. midominio.com)"
	read dom

	#Checks if local dns server it's commented in resolv.conf
	search=$(sed -n '/#nameserver 127.0.1.1/p' /etc/resolv.conf)

	#If not, we comment it
	if [ "$search" != "#nameserver 127.0.1.1"
	then
		echo "Commenting server 127.0.1.1 en /etc/resolv.conf"
		sed -i -e 's/nameserver 127.0.1.1/#nameserver 127.0.1.1/g' /etc/resolv.conf
	else
		echo "Server 127.0.1.1 commented"
	fi
	#Asks for domain/DNS IP address
	echo "Introduce your Domain Controller/DNS IP address"
	read dc
	#Checks if the domain/DNS it's in resolv.conf
	search=$(sed -n "/nameserver $dc/p" /etc/resolv.conf)

	#If not, we add it to resolv.conf
	if [ "$search" != "nameserver $dc" ]
	then
		echo "Adding the server $dc to /etc/resolv.conf"
		echo "nameserver $dc" >> /etc/resolv.conf
	else
		echo "The DNS $dc exists"
	fi
	#Asks for Domain Controller FQDN
	echo "Introduce your domain controller FQDN (ex. controller.mydomain.local)"
	read fqdn
	#Checks if the NTP server it's in /etc/ntp.conf
	search=$(sed -n "/server $fqdn/p" /etc/ntp.conf)

	#Adds DC as NTP server
	if [ "$search" != "server $fqdn" ]
	then
		echo "Adding ntp server in /etc/ntp.conf and restarting the service"
		echo "server $fqdn" >> /etc/ntp.conf
		#Restarts NTP service
		service ntp restart
	else
		echo "NTP server $fqdn already exists"
	fi

	#Creates /etc/realmd.conf config file
	if [ -f /etc/realmd.conf ]
	then
		echo "The file /etc/realmd.conf already exists, do you want to rewrite it (S) or Rename it (R) as realmd.conf.old.date?"
		ok=0

		while [ $ok -eq 0  ]
		do

			read opt

			if [ "$opt" == "s"  ] || [ "$opt" == "S" ]
			then

				rm /etc/realmd.conf
				write_realmd $dom
				ok=1

			elif [ "$opt" == "r" ] || [ "$opt" == "R" ]
			then

				day=$(date +"%d-%m-%Y")
				mv "/etc/realmd.conf" "/etc/realmd.conf.old.$day"
				write_realmd $dom
				ok=1

			else

				echo "Select a correct option rewrite(S) o rename(R)"
			fi
		done
	else

		echo "The file /etc/realmd.conf doesn't exists, creating a new one"
		write_realmd $dom

	fi

	#clear

	#Saves the hostname
	name=$(hostname)
	#Asks for a domain unser
	echo "Introduce the domain user name"

	read username
	domup=${dom^^}
	#Adds the machine to the domain
	realm --verbose join $dom --user-principal="$name"/"$username"@"$domup"
	#Checks if the default access options it's changed
	search=$(sed -n '/access_provider = ad/p' /etc/sssd/sssd.conf)
	#If not, changes it in /etc/sssd/sssd.conf
	if [ "$search" != "access_provider = ad" ]
	then
		echo "Changing access option to ad, restarting the service"
		sed -i -e 's/access_provider = simple/access_provider = ad/g' /etc/sssd/sssd.conf
		#Restarts the service

		service sssd restart
	else
		echo "Access option it's ad already"
	fi

	#Checks if module pam_mkhomedir it's in /etc/pam.d/common-session
	search=$(grep "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" /etc/pam.d/common-session)
	#If not adds it
	if [ "$search" != "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" ]
	then
		echo "Adding pam_mkhomedir module in /etc/pam.d/common-session"
		echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session
	else
		echo "Module pam_mkhomedir already added"
	fi

	if [ "$distro" == "E" ] || [ "$distro" == "e" ]
	then
		echo "[SeatDefaults]" >> /etc/lightdm/lightdm.conf.d/domain-custom.conf
		echo "greeter-show-manual-login=true" >> /etc/lightdm/lightdm.conf.d/domain-custom.conf
		echo "allow-guest=false" >> /etc/lightdm/lightdm.conf.d/domain-custom.conf
	else

		#Creates lightdm config for graphical login
		#clear
		if [ -f /etc/lightdm/lightdm.conf.d/lightdm.conf ]
		then
			echo "The file /etc/lightdm/lightdm.conf.d/lightdm.conf already exists, qdo you want to rewrite it (S) or Rename it (R) as etc/lightdm/lightdm.conf.d/lightdm.conf.old.date ?"
			ok=0

			while [ $ok -eq 0  ]
			do

				read opt

				if [ "$opt" == "s"  ] || [ "$opt" == "S" ]
				then

					rm /etc/lightdm/lightdm.conf.d/lightdm.conf
					write_lightdm
					ok=1

				elif [ "$opt" == "r" ] || [ "$opt" == "R" ]
				then

					day=$(date +"%d-%m-%Y")
					mv "/etc/lightdm/lightdm.conf.d/lightdm.conf" "/etc/lightdm/lightdm.conf.d/lightdm.conf.old.$day"
					write_lightdm
					ok=1

				else

					echo "Select a correct option rewrite(S) o rename(R)"
				fi
			done
		else

			echo "The file /etc/lightdm/lightdm.conf.d/lightdm.conf doesn't exists, creating a new one"
			write_lightdm

		fi
	fi
fi
#clear
echo "It's necessary to reboot the system, then login as DOMAIN\user"
echo "Reboot now(Y/N)?"
read ans

if [ "$ans" == "y" ] || [ "$ans" == "Y" ]
then
	reboot
fi
