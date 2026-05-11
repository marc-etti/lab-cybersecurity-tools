#!/bin/bash

# Esce al primo errore
set -e

# Username e password per l'utente di MySQL (MariaDB)
SQL_USERNAME="cyberuser"
SQL_PASSWORD="password_molto_sicura"

# Inserisce nome utente e password nel file php
sed -i "s/UTENTE_DATABASE/$SQL_USERNAME/" /var/www/html/db.php
sed -i "s/PASSWORD_DATABASE/$SQL_PASSWORD/" /var/www/html/db.php

# Avvia MySQL (MariaDB)
/usr/sbin/mysqld &

# Incrementare se il database non si avvia abbastanza in fretta
sleep 10

# Crea un nuovo utente e ne imposta la password, importa il database e dei dati di esempio
/usr/bin/mysql -e "CREATE USER '$SQL_USERNAME'@'localhost' IDENTIFIED BY '$SQL_PASSWORD';"
/usr/bin/mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'cyberuser'@'localhost';"
/usr/bin/mysql -e "FLUSH PRIVILEGES;"
# NON ci deve essere uno spazio fra -p e la password.
/usr/bin/mysql -u cyberuser -p$SQL_PASSWORD < /cyberbase.sql

# Avvia apache2
/usr/sbin/apache2ctl start

# Avvia l'agente Wazuh
/usr/bin/env /var/ossec/bin/wazuh-control start
/usr/bin/env /var/ossec/bin/wazuh-control status
status=$?
if [ $status -ne 0 ]; then
    echo "Failed to start agent: $status"
    exit $status
fi

echo "Agente Wazuh in esecuzione"

# Modifica la configurazione di Suricata
sed -i 's/EXTERNAL_NET: "!$HOME_NET"/EXTERNAL_NET: "any"/' /etc/suricata/suricata.yaml

# Avvia Suricata
suricata -c /etc/suricata/suricata.yaml -i eth0 &

# Shell
bash
