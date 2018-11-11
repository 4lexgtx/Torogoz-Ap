#!/bin/bash

#ESTE SCRIP SE EJECUTA DESPUES DE HABER INSTLADO EL HOTSPOT ADMIN 
#EN UNA DADO CASO QUE SE HAYA CAMBIADO DE RED YA QUE SE APLICAN LAS CONFIGURACIONES
#CON LA IP QUE SE TIENE EN ETH0 A LA HORA DE INSTALARLO HACIENDO IMPOSIBLE ACCEDDER TENEIANDO 
#CONECTADA LA RASPBERRY A OTRA RED DIFERENTE


#ejecutar cada vez que se conecte a una nueva red para que se configure la uneva i
MY_IP=`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`
sed -i "s/192.168.128.46/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Backend/src/config.json
sed -i "s/127.0.0.1/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.dev.json
sed -i "s/127.0.0.1/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.prod.json
sed -i "s/192.168.128.46/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.dev.json
sed -i "s/192.168.128.46/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.prod.json
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && HOST='`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`' pm2 start --name frontend npm -- start"

#EJECUTAR PARA VOLOVER APLICAR LOS CAMBIOS HECHOS 

##########################BACKEND############################

display_message "Starting backend using PM2"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start --name backend npm -- start"


display_message "Starting packages installation with npm"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && export NODE_ENV= && npm install"


##########################FRONTEND############################

display_message "Start packages installation with npm"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && export NODE_ENV= && npm install"


display_message "Rebuilding node-sass for Raspberry Pi"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && npm rebuild node-sass"


display_message "Starting interface via PM2"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && HOST='`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`' pm2 start --name frontend npm -- start"


display_message "Saving PM2 configuration"
su - kupiki -c "cd /home/kupiki && pm2 save"


display_message "Adding server as a service"
su - kupiki -c "pm2 startup systemd"
#

display_message "Generating service files for PM2"
/usr/bin/pm2 startup systemd -u kupiki --hp /home/kupiki


display_message "Make service executable"
chmod -x /etc/systemd/system/pm2-kupiki.service


display_message "Creating backend script folder"
mkdir /etc/kupiki && chmod 700 /etc/kupiki


display_message "Cloning backend script in /etc/kupiki"
cp /root/Kupiki-Hotspot-Admin-Backend-Script/kupiki.sh /etc/kupiki/

chmod 700 /etc/kupiki/kupiki.sh



##########################BACKEND############################

#ESCRIP DEL BACKEND
	#Líneas de privilegio de usuario
	#La cuarta línea, que dicta los privilegios rootdel usuario sudo, es diferente de las líneas anteriores. Echemos un vistazo a lo que significan los diferentes campos:

	#root ALL=(ALL:ALL) ALL
	#El primer campo indica el nombre de usuario al que se aplicará la regla ( root).
	#demo ALL=(ALL:ALL) ALL
	#El primer "TODO" indica que esta regla se aplica a todos los hosts.
	#demo ALL=(ALL:ALL) ALL
	#Este "TODO" indica que el rootusuario puede ejecutar comandos como todos los usuarios.
	#demo ALL=(ALL:ALL) ALL
	#Este "TODO" indica que el rootusuario puede ejecutar comandos como todos los grupos.
	#demo ALL=(ALL:ALL) ALL
	#El último "TODO" indica que estas reglas se aplican a todos los comandos.##/
	#NOPASSWD = SIN CONTRASEÑA

display_message "Removing all lines for kupiki in /etc/sudoers"
sed -i 's/^kupiki ALL.*//g' /etc/sudoers


display_message "Updating /etc/sudoers"
echo '
kupiki ALL=(ALL) NOPASSWD:/etc/kupiki/kupiki.sh
' >> /etc/sudoers



display_message "Creating the upgrade script for Kupiki Hotspot Admin"

######se quito del echo siguiet
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git fetch --all"
#devuelve todos los cambios a las ramas desdcegadasd
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git reset --hard origin/master"
#cd /root/Kupiki-Hotspot-Admin-Script/
#git pull

######se quito del echo siguiet

echo '
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && pm2 stop 0"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && export NODE_ENV= && npm install"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && gulp build"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && pm2 start 0"
cp /root/Kupiki-Hotspot-Admin-Script/kupiki.sh /etc/kupiki/
chmod 700 /etc/kupiki/kupiki.sh
' > /root/updateKupiki.sh

# CON EL SCRIPT UPDATEKUPIKI.SH SE ACTUALIZAN LOS CAMBIO HECHOS
# entonces para que en cada reinicio se actualize hay que agregarlo al rc.local



chmod +x /root/updateKupiki.sh


display_message "Installing some freeradius tools"
apt-get install -y freeradius-utils


display_message "Adding Collectd plugin"
sed -i "s/^#LoadPlugin unixsock/LoadPlugin unixsock/" /etc/collectd/collectd.conf


echo '
<Plugin unixsock>
        SocketFile "/var/run/collectd-unixsock"
        SocketGroup "collectd"
        SocketPerms "0660"
        DeleteSocket false
</Plugin>' >> /etc/collectd/collectd.conf

# COLLECTED es un servicio que recibe estadisticas del sistema y las pon e a dicpisicion
display_message "Restarting Collectd"
service collectd restart


display_message "Restarting Mysql"
service mysql restart

exit 0