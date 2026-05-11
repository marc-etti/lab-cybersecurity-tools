# Web Application with Wazuh

Questa cartella contiene la web application vulnerabile usata nel laboratorio e la configurazione degli strumenti di monitoraggio/difesa collegati a Wazuh.

## Contenuto

- `app/`: codice sorgente della web application PHP.
- `Dockerfile`: immagine Docker della web app con Apache, PHP, MariaDB e strumenti di supporto.
- `entrypoint.sh`: script di avvio del container.
- `cyberbase.sql`: dump iniziale del database usato dall’applicazione.
- `apache-config.conf`: configurazione del virtual host Apache.
- `ossec.conf`: configurazione dell’agente Wazuh.
- `honeyfiles/`: file esca usati per simulare attività di post-exploitation e generare alert.