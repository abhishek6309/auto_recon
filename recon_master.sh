#!/bin/bash

if [ -z "$1" ]
then
        echo "Usage: ./recon.sh <IP>"
        exit 1
fi

printf "\n----- NMAP -----\n\n" > results

echo "Running Nmap..."
nmap $1 | tail -n +5 | head -n -3 >> results

while read line
do
        if [[ $line == *open* ]] && [[ $line == *http* ]]
        then
                echo "Running Gobuster..."
                gobuster dir -u $1 -w /usr/share/wordlists/dirb/common.txt -qz > temp1

        echo "Running WhatWeb..."
        whatweb $1 -v > temp2
        fi
done < results

if [ -e temp1 ]
then
        printf "\n----- DIRS -----\n\n" >> results
        cat temp1 >> results
        rm temp1
fi

if [ -e temp2 ]
then
    printf "\n----- WEB -----\n\n" >> results
        cat temp2 >> results
        rm temp2
fi

cat results

echo 
echo "[+] Check ASN..."
whois -h whois.cymru.com $(dig +short $1)
echo
mkdir subdo

if [[ -d "subdo" ]]; then
	echo "[+] Check Subdomains..."
	assetfinder --subs-only $1 >> subdo/subdomains.txt
fi
sort -u subdo/subdomains.txt -o subdo/domains.txt

mkdir live_subdo
if [[ -d "live_subdo" ]]; then
    echo "[+] Check Live Subdomains..."
    cat subdo/domains.txt | sort -u | httprobe -s -p https:443 | tr -d ":443" | tee -a  >> live_subdo/https.txt
else
    cat subdo/domains.txt | sort -u | httprobe -s -p http:80 | tr -d ":80" | tee -a  >> live_subdo/http.txt
fi

mkdir sucses
if [[ -d "sucses" ]]; 
then
    cat live_subdo/https.txt | grep -Po "(\w+\.\w+\.\w+)$" | sort -u >> sucses/https.txt
else
    cat live_subdo/http.txt | grep -Po "(\w+\.\w+\.\w+)$" | sort -u >> sucses/http.txt
fi

mkdir dir_response
if [[ -d "dir_response" ]]; then
    echo "[+] Check Status Response..."
    cat sucses/https.txt | assetfinder | hakrawler -plain | hakcheckurl | grep -v 404 >> dir_response/dir_https.txt
else
    cat sucses/http.txt | assetfinder | hakrawler -plain | hakcheckurl | grep -v 404 >> dir_response/dir_http.txt
fi
echo "[+] Done Saved Output: dir_response/dir_https.txt"
echo "[+] Get All urls..."
echo "[+] Wait...(10/30m)"
cat sucses/https.txt | getallurls -subs | concurl -c 20 -- -s -L -o /dev/null -k -w '%{https_code},%{size_download}' | tee -a >> out.txt
if [[ -d "file" ]]; then
  cat sucses/http.txt | getallurls -subs | concurl -c 20 -- -s -L -o /dev/null -k -w '%{http_code},%{size_download}' | tee -a >> out1.txt
  else
     echo "[+] http.txt Not Founds..."
fi


