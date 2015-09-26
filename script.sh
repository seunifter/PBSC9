#!/usr/bin/env bash

##########################################################
#														 #
#Drupal 6 to 7 automated 								 #
#														 #
##########################################################
#Programa de Becas de Formación en Seguridad Informática #
# 					9na generacion						 #
##########################################################
#	Emmanuel Arenas Garcia								 #
#		earenas@bec.seguridad.unam.mx					 #
#		emmanuelarenasgarcia@gmail.com					 #
#	Eduardo Lagos Flores								 #
#		elagos@bec.seguridad.unam.mx					 #
##########################################################




#verificacion de permisos 
if [ "$(whoami)" != "root" ]; then
	echo "Se requiere provilegios de administracion"
	exit 1
fi
echo "eres admin"



#Determinar version de apache:
echo " Version de apache:"
dpkg -s apache2 | grep Version

#Determinar version de php:
echo " Version de php:"
dpkg -s php5 | grep Version

#verificar los sitios de apache habilitados
cd /etc/apache2/sites-enabled
	#Buscar sitios con la palabra drupal y contar los encontrados
	#en caso de encontrar solo un drupal, ese sera clasificado como sitio unico
	# en caso de encontrar varios, se determinara como Drupal multisitio
	#si no se encontraron sitios, se determinara que no existe drupal"
if [ "$(grep -i  "drupal" . -lR | wc -l)" -eq 0 ]; then
	echo "No se encontraron sitios"
else
	if [ "$(grep "/var/www/drupal" . -lR | wc -l)" -eq 1 ]; then
		echo "Drupal single site"
	else
		echo "Drupal multisite"
	fi
fi
cd /var/www/drupal  > /dev/null


#Determinar la version del drupal (con base al changelog)
echo "Version de Drupal"
cat CHANGELOG.txt | grep "Drupal" -m 1


#Respaldo de la base de datos de cada drupal

usr=echo -e ""
