#!/bin/bash
#Script para unir equipo Fedora a dominio Active Directory de Windows
#Provado en Fedora 24/25 Beta
#Hecho por beclimyfriend.blogspot.com !! Si te ha servido visita para más!

echo "¿Quieres instalar los paquetes necesarios?(deberían estar por defecto Y/N)"
read ans
if [ "$ans" == "y" ] || [ "$ans" == "Y" ]
then
	dnf -y install realmd sssd oddjob oddjob-mkhomedir adcli samba-common-tools
fi

clear

echo "Introduce el nombre de tu interfaz de red (ej; enp0s3):"
read iface

echo "Introduce la dirección IP del DNS del dominio:"
read dns

nmcli c modify $iface ipv4.dns $dns
nmcli c down $iface
nmcli c up $iface

echo "Introduce el nombre de tu dominio (ej; midominio.local):"
read dom

echo "Mostrando los datos del dominio $dom:"
realm discover $dom
echo "Pulsa una tecla para continuar..."
read cont
ok=0

while [ $ok -eq 0 ]
do

	echo "Introduce el nombre que le quieres dar a tu máquina (ej; fedoradesk)"
	read hname
	echo "Tu equipo se llamará $hname.$dom ¿Continuar(Y/N)?"
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

sytemctl enable sssd.service

systemctl restart sssd.service

