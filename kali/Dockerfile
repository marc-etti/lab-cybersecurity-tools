FROM kalilinux/kali-rolling

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update && apt -y install kali-linux-headless

# Per la configurazione della tastiera italiana in maniera non interattiva
COPY keyboard /etc/default/keyboard

# msfconsole e msfvenom si bloccano se runnati da /, quindi cambiamo cartella in /root
WORKDIR /root

CMD bash
