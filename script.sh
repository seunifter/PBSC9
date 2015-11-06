#!/usr/bin/env bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>log.out 2>&1
##########################################################
#Drupal 6 to 7 automated                                 #
#                                                        #
##########################################################
#Programa de Becas de Formacion Seguridad Informatica    #
#                                       9na generacion   #
##########################################################
#       Emmanuel Arenas Garcia                           #
#               earenas@bec.seguridad.unam.mx            #
#               emmanuelarenasgarcia@gmail.com           #
#       Eduardo Lagos Flores                             #
#               elagos@bec.seguridad.unam.mx             #
##########################################################

#verificacion de permisos 
if [ "$(whoami)" != "root" ]; then
        echo "Se requiere provilegios de administracion">&3
        exit 1
fi
echo "eres admin"

echo "########################################">&3
echo "#        Determinando Versiones        #">&3
echo "########################################">&3

#Determinar version de apache:
echo " Version de apache:">&3
dpkg -s apache2 | grep Version>&3

#Determinar version de php:
echo " Version de php:">&3
dpkg -s php5 | grep Version>&3

 
echo "########################################">&3
echo "#   Obteniendo Informacion de sitios   #">&3
echo "########################################">&3
#verificar los sitios de apache habilitados
cd /etc/apache2/sites-enabled


        #Buscar sitios con la palabra drupal y contar los encontrados
        #en caso de encontrar solo un drupal, ese sera clasificado como sitio unico
        # en caso de encontrar varios, se determinara como Drupal multisitio
        #si no se encontraron sitios, se determinara que no existe drupal"
if [ "$(grep -i  "drupal" . -lR | wc -l)" -eq 0 ]; then
        echo "No se encontraron sitios"
else
        if [ "$(grep "/drupal" . -lR | wc -l)" -eq 1 ]; then
                echo "Drupal single site">&3
        else
                echo "Drupal multisite">&3
        fi
fi
cd -


#cd /var/www/drupal  > /dev/null
#Determinar la version del drupal (con base al changelog)
#echo "Version de Drupal"
#cat CHANGELOG.txt | grep "Drupal" -m 1
#guardar en un arreglo los archivos de VirtualHostst Habilitados
sites_enabled=($(apache2ctl -S | awk '{print $NF}' | sed -e 's/(\(.*\)\:\(.*\)/\1/' | grep / |uniq))
folder_drupal_sites=()
for i in "${sites_enabled[@]}"
do
   :
        string=($(cat $i | grep -i 'DocumentRoot\|ServerName' | awk '{print $NF}' | paste -d '/sites/' - /dev/null /dev/null /dev/null /dev/null /dev/null /dev/null  - |grep -i 'drupal'))
        if [ $(echo $string | grep -i drupal |wc -l) -gt 0 ]
        then
        folder_drupal_sites+=($string)
        fi 
done
echo ${folder_drupal_sites[@]}



echo "########################################">&3
echo "#         Generando Respaldos          #">&3
echo "########################################">&3

#############################################################################################################################################################
# El servidor de BackEnd requiere tener un usuario con permisos de creacióe bases de datos, creacióe usuarios y de super usuario. No debe ser el usuario postgres. 
# En caso de no tenerlo crearlo de la siguiente manera:
# 			CREATE USER usr_admin  WITH ENCRYPTED PASSWORD 'P@ssw0rd'; ALTER ROLE usr_admin WITH CREATEDB, CREATEUSER, SUPERUSER;
# Debe existir un archivo de configuracióexport.conf, localizado en el mismo directorio del script.
# El archivo debe incluir la lía con el usuario admin de Postgres: psql_admin%usuario%password%dir_ip
#############################################################################################################################################################


#Obtener parametros para respaldos
usr_admin=$(cat export.conf  |grep -v "#"| grep psql_admin | cut -d "%" -f 2) # Variable que contiene el username del usuario con permisos especiales sobre psql
echo $usr_admin
pwd_admin=$(cat export.conf |grep -v "#" | grep psql_admin | cut -d "%" -f 3) # Variable que contiene el password del usuario con permisos especiales sobre psql
ip_admin=$(cat export.conf  |grep -v "#" | grep psql_admin | cut -d "%" -f 4) # Variable que contiene la IP del servidor remoto de psql
site_backup_folder=$(cat export.conf  |grep -v "#" | grep site_backup_folder | cut -d "=" -f 2)
site_backup_prefix=$(cat export.conf  |grep -v "#" | grep site_backup_prefix | cut -d "=" -f 2)
db_backup_folder=$(cat export.conf  |grep -v "#" | grep db_backup_folder | cut -d "=" -f 2)
db_backup_prefix=$(cat export.conf  |grep -v "#" | grep db_backup_prefix | cut -d "=" -f 2)

	 mkdir $site_backup_folder
	 mkdir $db_backup_folder
echo $folder_drupal_sites[@]
#folder_drupal_sites=("${folder_drupal_sites[@]:1}")
for i in "${folder_drupal_sites[@]}"
do :
	echo "sitio" $i
	sitio=($(echo "$i" | sed "s/.*\///"))
	tar -czf $site_backup_folder/$site_backup_prefix$sitio.tar.gz $i
	echo "Site Backup: Completed">&3
        uri=$(echo "$(cat  $i/settings.php| grep '$db_url' | grep -v '*' | sed -e "s/\(.*\)'\(.*\)'\(.*\)/\2/" | sed 's/\%/\\x/g'| sed 's/\(.*\)\/\/\(.*\):\(.*\)@\(.*\):\(.*\)\/\(.*\)/\2,\3,\4,\5,\6/g')")
        usr=$(echo -e $(echo $uri | awk -F "," '{print $1}'))
        pwd=$(echo -e $(echo $uri | awk -F "," '{print $2}'))
        ip=$(echo $uri | awk -F "," '{print $3}')
        puerto=$(echo $uri | awk -F "," '{print $4}')
        basedd=$(echo -e $(echo $uri | awk -F "," '{print $5}'))
        echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	echo $usr $pwd $ip $puerto $basedd

        #Respaldo de la base de datos de cada drupal
        echo "Generando respaldos"
        dump="export PGPASSWORD="$pwd" ; pg_dump -C -U "$usr" -h "$ip" "$basedd" > "$db_backup_folder"/"$db_backup_prefix$basedd".sql"
	echo $dump
echo "DB Backup: Completed">&3
echo "Completado"
echo "Creando nuevos usuarios de la bdd"
		# <--------------------- Generamos un nuevo usuario y una nueva base de datos para el sitio nuevo -------------------------------->
		export PGPASSWORD=$pwd_admin ; psql -U $usr_admin -d postgres -h $ip_admin -c "CREATE USER d7$usr WITH ENCRYPTED PASSWORD '$pwd'"
echo "Completado"
echo "Creando nueva base de datos"
		export PGPASSWORD=$pwd_admin ; psql -U $usr_admin  -d postgres -h $ip_admin -c "CREATE DATABASE d7$basedd WITH OWNER d7$usr;"
done

echo "########################################">&3
echo "#        Instalando Componentes        #">&3
echo "########################################">&3

echo "instalando componentes necesarios para actualizar"
apt-get update
apt-get -y install php-pear
pear channel-discover pear.drush.org
pear install drush
a2enmod rewrite
cd /var/www
echo "########################################">&3
echo "#          Instalando Drupal 7         #">&3
echo "########################################">&3
echo "El nuevo drupal se instalara en /var/www">&3
echo "Sea paciente esto puede tardar varios minutos"
drush dl drupal-7
cd -
cd /var/www/drupal-7*
echo "########################################">&3
echo "#        Creando Nuevos Sitios         #">&3
echo "########################################">&3
echo "Creando los nuevos sitios"
echo ${folder_drupal_sites[@]}
for i in "${folder_drupal_sites[@]}"
do :
	a=($(echo "$i" | sed "s/.*\///"))
        sitio=($(echo "$i" | sed "s/.*\///"|tr -d '.'))
        uri=$(echo "$(cat  $i/settings.php| grep '$db_url' | grep -v '*' | sed -e "s/\(.*\)'\(.*\)'\(.*\)/\2/" |  sed 's/\(.*\)\/\/\(.*\):\(.*\)@\(.*\):\(.*\)\/\(.*\)/\2,\3,\4,\5,\6/g')")
        usr=$(echo -e $(echo $uri | awk -F "," '{print $1}'))
        pwd=$(echo  $(echo $uri | awk -F "," '{print $2}'))
        ip=$(echo $uri | awk -F "," '{print $3}')
        puerto=$(echo $uri | awk -F "," '{print $4}')
	basedd=$(echo -e $(echo $uri | awk -F "," '{print $5}'))
	x="drush -y site-install standard --db-url=pgsql://d7"$usr":$pwd@$ip:$puerto/d7$basedd --site-name="$a" --sites-subdir="$a" --account-name=admin --account-pass=admin"
	echo $x
	eval $x	>&3
#drush -y site-install standard --db-url=pgsql://$sitio_usr:$pwd@10.0.2.5:5432/$sitio_db --site-name="$a" --sites-subdir="$a" --account-name=admin --account-pass=admin
cd -
echo "se imprime la variable a"
echo $a
cd /var/www/drupal-7*/sites/$a
#
drush dl drush_sup uuid feeds node_export migrate migrate_d2d -y
#
drush en uuid feeds node_export*  migrate_d2d* migrate -y

##################aqui se modificaria el archivo settings.php
linea=$(grep -nr '^);' settings.php | cut -f1 -d:)
linea=$(($linea-1))
(head -$linea > settings.php.part1; cat > settings.php.part2) < settings.php

echo "Creando Nuevos Sitio">&3

echo "Creando archivo Settings.php"
echo "  'legacy' =>" >>settings.php.part1
echo "  array (" >>settings.php.part1
echo "    'default' =>" >>settings.php.part1
echo "    array (" >>settings.php.part1
echo "      'database' => '"$basedd"'," >>settings.php.part1
echo "      'username' => '"$usr"'," >>settings.php.part1
echo "      'password' => '"$pwd"'," >>settings.php.part1
echo "      'host' => '"$ip"'," >>settings.php.part1
echo "      'port' => '"$puerto"'," >>settings.php.part1
echo "      'driver' => 'pgsql'," >>settings.php.part1
echo "      'prefix' => ''," >>settings.php.part1
echo "    )," >>settings.php.part1
echo "  )," >>settings.php.part1
cat settings.php.part1 > settings.php
cat settings.php.part2 >> settings.php
##################terminamos demodificar el settings.php

cd /var/www/drupal-7*
drupal_path=$(pwd)
#deshabiitamos e sitio actual de apache y agregamos el nuevo sitio
a2dissite $a
echo "Habilitando nuevos sitios en Apache">&3
service apache2 reload
rm /etc/apache2/sites-available/$a
echo "<VirtualHost *:80>" > /etc/apache2/sites-available/$a
echo "        DocumentRoot $drupal_path" >> /etc/apache2/sites-available/$a
echo "        ServerName $a" >> /etc/apache2/sites-available/$a
echo "        ServerAlias $a" >> /etc/apache2/sites-available/$a
echo "                <Directory $drupal_path>" >> /etc/apache2/sites-available/$a
echo "                        Options -Indexes FollowSymLinks MultiViews" >> /etc/apache2/sites-available/$a
echo "                        AllowOverride All" >> /etc/apache2/sites-available/$a
echo "                        Order allow,deny" >> /etc/apache2/sites-available/$a
echo "                        allow from all" >> /etc/apache2/sites-available/$a
echo "                </Directory>" >> /etc/apache2/sites-available/$a
echo "</VirtualHost>" >> /etc/apache2/sites-available/$a
echo "" >> /etc/apache2/sites-available/$a
a2ensite $a
service apache2 reload
###########aqui se hace la actualizacion a manita
done
service apache2 reload
##############################################################

