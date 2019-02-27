#!/bin/bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root" 1>&2
   exit 1
fi

echo "[START] Welcome to the vhost creation wizard!"

# Get the user input for the domain
if [[ -z "$1" ]]; then
	echo "[INPUT] Enter the vhost/domain name to create (without http:// or www.): "
	read WHOLEDOMAIN
	if [[ -z "$WHOLEDOMAIN" ]]; then
		echo "[ERROR] No domain entered! Quitting..."
		exit 1
	fi
else
	WHOLEDOMAIN=$1
fi

# Format string
WHOLEDOMAIN=${WHOLEDOMAIN/https}
WHOLEDOMAIN=${WHOLEDOMAIN/http}
WHOLEDOMAIN=${WHOLEDOMAIN/:}
WHOLEDOMAIN=${WHOLEDOMAIN///}
WHOLEDOMAIN=${WHOLEDOMAIN/www.}

# Validation
if ! [[ "$WHOLEDOMAIN" =~ [.] ]]; then
	echo "[ERROR] Domain has no extension! Quitting..."
	exit 1
fi
if [[ "$WHOLEDOMAIN" =~ [^a-zA-Z0-9.-] ]]; then
	echo "[ERROR] Domain contains invalid chars! Quitting..."
	exit 1
fi
if [[ "$WHOLEDOMAIN" =~ [.]{2,} ]]; then
	echo "[ERROR] More than 1 consecutive dot! Quitting..."
	exit 1
fi

# Explode string into array using . as delimiter
arrIN=(${WHOLEDOMAIN//./ })

# Count elements in array
total=${#arrIN[@]}
index=0
for part in "${arrIN[@]}"
do
	((index++))
	if [[ $total != $index ]]; then
		DOMAIN="$DOMAIN$part."
	fi
	if [[ $((total - 1)) == $index ]]; then
		USER=$part
	fi
done

# Trim trailing .
DOMAIN=`echo $DOMAIN | sed 's/.$//'`

# Get extension from last element in array
EXT=${arrIN[-1]}

# Some debug info
echo "[INFO] Domain: $DOMAIN"
echo "[INFO] Ext: $EXT"
echo "[INFO] User: $USER"
echo "[INFO] Creating domain: $DOMAIN.$EXT"

# Creating user if does not exist
if id "$USER" >/dev/null 2>&1; then
	echo "[INFO] User $USER already exists - skipping user creation"
else
	echo "[INFO] User $USER does not exist - Creating user"
	echo "[INPUT] Please enter the user $USER's password: "
	read -s USERPASS
	adduser $USER --disabled-password --gecos ""
	usermod -a -G www-data $USER
	echo "$USER:$USERPASS" | chpasswd
	echo "[INFO] User $USER added!"
fi

# Creating dirs with permissions:
echo "[INFO] Creating dirs with permissions"
mkdir /var/www/$DOMAIN.$EXT && mkdir /var/www/$DOMAIN.$EXT/public_html
chown $USER:www-data -R /var/www/$DOMAIN.$EXT
chmod 755 -R /var/www/$DOMAIN.$EXT

# Creating new apache conf files:
echo "[INFO] Copying apache conf files and replacing domain info"
cp /etc/apache2/sites-available/domain.ext.conf /etc/apache2/sites-available/$DOMAIN.$EXT.conf
sed -i "s/domain\.ext/$DOMAIN\.$EXT/g" /etc/apache2/sites-available/$DOMAIN.$EXT.conf

# Enable site
echo "[INFO] Enabling site with a2ensite"
a2ensite $DOMAIN.$EXT.conf

# Reload apache2 for changes to take effect
echo "[INFO] Reloading apache"
service apache2 reload

echo "[END] Script Complete!!1 Domain $DOMAIN.$EXT has been created and enabled. User $USER has been created and added to the www-data group."
exit 1
