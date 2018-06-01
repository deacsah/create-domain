#!/bin/bash

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
	echo "[NOTICE] User $USER already exists - skipping user creation"
else
	echo "[NOTICE] User $USER does not exist - Creating user"
	echo "[INPUT] Please enter the user $USER's password: "
	read -s USERPASS
	adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
	echo "$USER:$USERPASS" | chpasswd
	echo "[NOTICE] User $USER added!"
fi

# Creating dirs with permissions:
echo "[NOTICE] Creating dirs with permissions"
mkdir /var/www/$DOMAIN.$EXT && mkdir /var/www/$DOMAIN.$EXT/public_html
chown $USER:$USER -R /var/www/$DOMAIN.$EXT
chmod 777 -R /var/www/$DOMAIN.$EXT

# Creating new apache conf files:
echo "[NOTICE] Copying apache conf files and replacing domain info"
cp /etc/apache2/sites-available/domain.ext.conf /etc/apache2/sites-available/$DOMAIN.$EXT.conf
sed -i "s/opperbazen\.nl/$DOMAIN\.$EXT/g" /etc/apache2/sites-available/$DOMAIN.$EXT.conf
ln -s /etc/apache2/sites-available/$DOMAIN.$EXT.conf /etc/apache2/sites-enabled/$DOMAIN.$EXT.conf

# Enable site
echo "[NOTICE] Enabling site with a2ensite"
a2ensite $DOMAIN.$EXT.conf

# Reload apache2 for changes to take effect
echo "[NOTICE] Reloading apache"
service apache2 reload

echo "[END] Yay!!1 Script Complete: Domain $DOMAIN.$EXT has been created and enabled. User $USER has been created."
exit 1
