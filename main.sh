#!/bin/bash

# Basé sur le script de Mr Xhark -> @xhark de la ligne 5 à 93 repo : https://github.com/blogmotion/bm-backup-pfsense/tree/master

RUNDIR="$( cd "$( dirname "$0" )" && pwd )"

##############################
######### VARIABLES  #########

# pfSense host OR IP (note: do not include the final '/' otherwise backup will fail)
PFSENSE_HOST=https://10.0.1.254

# pfSense credentials
PFSENSE_USER='auto-backup'
PFSENSE_PASS='auto-backup'

# leave empty to not encrypt xml backup file
BACKUP_PASSWORD=''

# Set to 1 to ignore SSL errors (self signed cert, etc)
HTTPS_INSECURE=1

# backup options
BACKUP_SSHKEY=1
BACKUP_PKGINFO=1
BACKUP_EXTRADATA=1
BACKUP_RRD=0

# where to store backups
BACKUP_DIR="/save/pfsense"

######## END VARIABLES ########
###############################

######################################### NE RIEN TOUCHER SOUS CETTE LIGNE #########################################

cd /tmp || (echo "Fail to change directory... end of script" && exit 1)

curl -V $PFSENSE_HOST >/dev/null 2>&1 || { echo "ERROR : cURL MUST be installed to run this script."; exit 1; }

COOKIE_FILE="$(mktemp /tmp/pfsbck.XXXXXXXX)"
CSRF1_TOKEN="$(mktemp /tmp/csrf1.XXXXXXXX)"
CSRF2_TOKEN="$(mktemp /tmp/csrf2.XXXXXXXX)"
CONFIG_TMP="$(mktemp /tmp/config-tmp-xml.XXXXXXXX)"

unset CERT RRD PKGINFO EXTRADATA SSHKEY PW

if [ "$HTTPS_INSECURE" = "1" ] ;   then CERT="--insecure" ; fi
if [ "$BACKUP_RRD" = "0" ] ;       then RRD="&donotbackuprrd=yes" ; fi
if [ "$BACKUP_PKGINFO" = "0" ] ;   then PKGINFO="&nopackages=yes" ; fi
if [ "$BACKUP_EXTRADATA" = "1" ] ; then EXTRADATA="&backupdata=yes" ; fi
if [ "$BACKUP_SSHKEY" = "1" ] ;    then SSHKEY="&backupssh=yes" ; fi
if [ -n "$BACKUP_PASSWORD" ] ;     then PW="&encrypt=yes&encrypt_password=${BACKUP_PASSWORD}&encrypt_password_confirm=${BACKUP_PASSWORD}" ; fi

mkdir -p "$BACKUP_DIR"

# fetch login
curl -Ss --noproxy '*' $CERT --cookie-jar "$COOKIE_FILE" "$PFSENSE_HOST/diag_backup.php" \
  | grep "name='__csrf_magic'" | sed 's/.*value="\(.*\)".*/\1/' > "$CSRF1_TOKEN" \
  || echo "ERROR: FETCH"

# submit the login
curl -Ss --noproxy '*' $CERT --location --cookie-jar "$COOKIE_FILE" --cookie "$COOKIE_FILE" \
  --data "login=Login&usernamefld=${PFSENSE_USER}&passwordfld=${PFSENSE_PASS}&__csrf_magic=$(cat "$CSRF1_TOKEN")" \
 "$PFSENSE_HOST/diag_backup.php"  | grep "name='__csrf_magic'" \
  | sed 's/.*value="\(.*\)".*/\1/' > "$CSRF2_TOKEN" \
  || echo "ERROR: SUBMIT THE LOGIN"

# submit download to save config xml
XMLFILENAME=$(curl -sS -OJ --noproxy '*' $CERT --cookie-jar "$COOKIE_FILE" --cookie "$COOKIE_FILE" \
  --data "Submit=download&download=download${RRD}${PKGINFO}${EXTRADATA}${SSHKEY}${PW}&__csrf_magic=$(head -n 1 "$CSRF2_TOKEN")" \
  --write-out "%{filename_effective}" "$PFSENSE_HOST/diag_backup.php" \
  || (echo "ERROR: READING FILENAME" && exit 1) )

# check if credentials are valid
if grep -qi 'username or password' "$CONFIG_TMP"; then
        echo ; echo "   !!! AUTHENTICATION ERROR (${PFSENSE_HOST}): PLEASE CHECK LOGIN AND PASSWORD"; echo
        rm -f "$CONFIG_TMP"
        exit 1
fi

# xml file contains doctype when the URL is wrong
if grep -qi 'doctype html' "$CONFIG_TMP"; then
	echo ; echo "   !!! URL ERROR (${PFSENSE_HOST}): HTTP OR HTTPS ?"; echo
	rm -f "$CONFIG_TMP"
	exit 1
fi

# definitive config file name
mv "/tmp/${XMLFILENAME}" $BACKUP_DIR && echo "Backup OK : ${BACKUP_DIR}/${XMLFILENAME} " || echo "Backup NOK !!! ERROR !!!"

# cleaning tmp and cookie files
rm -f "$COOKIE_FILE" "$CSRF1_TOKEN" "$CSRF2_TOKEN"





#Créer une archive de tout les fichiers : 
DATE=`date +"%d-%m-%y"`

source_dir="/save/sauvegarde"
backup_dir="/bucket"     #Lien vers le bucket Digital Ocean

timestamp=$(date +"%d-%m-%y")
new_backup_dir="$backup_dir/$timestamp"

mkdir -p /temp/save

mv /save/pfsense/* /temp/save
mv /save/cisco/* /temp/save
mv /save/proxmox/* /temp/save


cd /save/temp

tar -czvf del.tar.gz /temp/save/

gpg --output $timestamp.sauvegarde.tar.gz.gpg --encrypt --recipient 'public key' del.tar.gz

rm del.tar.gz            # suppression des temporaires de sauvegarde 
rm -rf /temp/save/*      # Suppression des temporaires de sauvegarde

rsync -a --link-dest="$backup_dir/latest" "$source_dir/$timestamp.sauvegarde.tar.gz.gpg" "$new_backup_dir"   #sauvegarde la sauvegarde incrémentiel sur le bucket

ln -sfn "$new_backup_dir" "$backup_dir/latest"

find "/save/sauvegarde" -name "*.sauvegarde.tar.gz.gpg" -type f -mtime +2 -exec rm {} \; # garde deux jours les exemaplaires de la sauvegarde avant de les supprimer















