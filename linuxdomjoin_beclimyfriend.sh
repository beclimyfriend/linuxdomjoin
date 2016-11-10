#!/bin/bash
#Easy script to join an Ubuntu Desktop to an Active Directory domain
#Script para unir fácilmente un cliente Ubuntu a Dominio de Active Directory
#Tested on Ubuntu 16.04 LTS (Xenial) and Ubuntu 14.04 (Trusty) LTS
#Testeado en Ubuntu 16.04 LTS (Xenial) y Ubuntu 14.04 (Trusty) LTS
#Visit beclimyfriend.blogspot.com for more!!
#Visita beclimyfriend.blogspot.com para más!! 

#Función que genera el archivo de configuración /etc/realmd.conf
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
#Función que genera el archivo de configuración /etc/lightdm/lightdm.conf.d/lightdm.conf
write_lightdm () {

	echo "[SeatDefaults]" >> /etc/lightdm/lightdm.conf.d/lightdm.conf
	echo "allow-guest=false" >> /etc/lightdm/lightdm.conf.d/lightdm.conf
	echo "greeter-show-manual-login=true" >> /etc/lightdm/lightdm.conf.d/lightdm.conf

}

echo "Xenialdomjoin, probado en Ubuntu 16.04 LTS (Xenial)"
echo "Visita beclimyfriend.blogspot.com para más cosas, espero que esto te haya ayudado!"
echo "Quieres instalar los paquetes necesarios (Y), o unir a dominio directamente? (N)"
read updt

if [ "$updt" == "Y" ] || [ "$updt" == "y" ]
then

	#Actualizamos los paquetes
	apt-get update
	#Instalamos los paquetes necesarios
	apt-get install -y realmd sssd sssd-tools samba-common krb5-user packagekit samba-common-bin samba-libs adcli ntp
	clear
fi
#Pedimos el nombre del dominio
echo "Introduce el nombre de tu dominio (ej. midominio.com)"
read dom

#Comprobamos si el servidor local esta comentado o no en resolv.conf
search=$(sed -n '/#nameserver 127.0.1.1/p' /etc/resolv.conf)

#Si no encuentra la linea comentada, la comentamos
if [ "$search" != "#nameserver 127.0.1.1" ]
then
	echo "Comentando el servidor 127.0.1.1 en /etc/resolv.conf"
	sed -i -e 's/nameserver 127.0.1.1/#nameserver 127.0.1.1/g' /etc/resolv.conf
else
	echo "Servidor 127.0.1.1 ya comentado"
fi
#Pedimos la dirección IP del controlador de Dominio/DNS
echo "Introduce la IP del Domain Controller/DNS"
read dc
#Comprobamos si el servidor del dominio ya esta añadido en resolv.conf
search=$(sed -n "/nameserver $dc/p" /etc/resolv.conf)

#Si no lo encuentra, lo añadimos a resolv.conf
if [ "$search" != "nameserver $dc" ]
then
	echo "Añadiendo el servidor $dc en /etc/resolv.conf"
	echo "nameserver $dc" >> /etc/resolv.conf
else
	echo "Servidor DNS $dc ya existe"
fi
#Pedimos el FQDN del Domain Controller
echo "Introduce el FQDN de tu controlador de Dominio (ej. controlador.midominio.local)"
read fqdn
#Comprobamos si el servidor de tiempo ya está añadido en /etc/ntp.conf
search=$(sed -n "/server $fqdn/p" /etc/ntp.conf)

#Añadimos el DC como servidor NTP si no lo encuentra en el archivo
if [ "$search" != "server $fqdn" ]
then
	echo "Añadiendo servidor ntp en /etc/ntp.conf y reiniciando el servicio"
	echo "server $fqdn" >> /etc/ntp.conf
	#Reiniciamos el servicio NTP
	service ntp restart
else
	echo "Servidor NTP $fqdn ya existe"
fi

#Creamos el fichero de configuración de realmd /etc/realmd.conf
if [ -f /etc/realmd.conf ]
then
	echo "El archivo /etc/realmd.conf ya existe, quieres Sobreescribirlo(S) o Renombrarlo(R) como realmd.conf.old.fecha?"
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

			day=`date +"%d-%m-%Y"`
			mv "/etc/realmd.conf" "/etc/realmd.conf.old.$day"
			write_realmd $dom
			ok=1

		else

			echo "Introduce una opción válida Sobreescribir(S) o Renombrarlo(R)"
		fi
	done
else

	echo "El archivo /etc/realmd.conf no existe, se creará uno nuevo"
	write_realmd $dom

fi

#clear

#Guardamos el nombre de la máquina
name=$(hostname)
#Preguntamos al usuario el nombre del usuario de dominio
echo "Introduce el nombre de Usuario de Dominio"

read username
domup=${dom^^}
#Añadimos la máq1uina a dominio
realm --verbose join $dom --user-principal="$name"/"$username"@"$domup"
#Comprobamos si la opción de acceso por defecto esta cambiada
search=$(sed -n '/access_provider = ad/p' /etc/sssd/sssd.conf)
#Si no está cambiada, la cambia en el archivo /etc/sssd/sssd.conf
if [ "$search" != "access_provider = ad" ]
then
	echo "Cambiando la opción de acceso por dominio y reiniciando el servicio"
	sed -i -e 's/access_provider = simple/access_provider = ad/g' /etc/sssd/sssd.conf
	#Reiniciamos servicio sssd
	service sssd restart
else
	echo "La opción de acceso ya es la de Dominio"
fi

#Comprobamos si el modulo pam_mkhomedir ya esta añadido en /etc/pam.d/common-session
search=$(grep "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" /etc/pam.d/common-session)
#Si no está añadido el modulo lo añade
if [ "$search" != "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" ]
then
	echo "Añadiendo modulo pam_mkhomedir en /etc/pam.d/common-session"
	echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session
else
	echo "Modulo pam_mkhomedir ya añadido"
fi

#Creamos fichero de configuración lightdm para hacer el login
#clear
if [ -f /etc/lightdm/lightdm.conf.d/lightdm.conf ]
then
	echo "El archivo /etc/lightdm/lightdm.conf.d/lightdm.conf ya existe, quieres Sobreescribirlo(S) o Renombrarlo(R) como realmd.conf.old.fecha?"
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

			day=`date +"%d-%m-%Y"`
			mv "/etc/lightdm/lightdm.conf.d/lightdm.conf" "/etc/lightdm/lightdm.conf.d/lightdm.conf.old.$day"
			write_lightdm
			ok=1

		else

			echo "Introduce una opción válida Sobreescribir(S) o Renombrarlo(R)"
		fi
	done
else

	echo "El archivo /etc/lightdm/lightdm.conf.d/lightdm.conf no existe, se creará uno nuevo"
	write_lightdm

fi
#clear
echo "Es necasario reiniciar el sistema, una vez hecho esto hay que iniciar sesión como DOMINIO\usuario"
echo "Quieres reiniciar ahora(Y/N)?"
read ans

if [ "$ans" == "y" ] || [ "$ans" == "Y" ]
then
	reboot
fi
