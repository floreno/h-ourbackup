#!/bin/sh
# /backup/backup.sh

# User-defined options
# Report E-Mail
REPORTMAIL="XXXXXXXX@XXXXXXXXX.XX"

# Backup-Space Username
HETZNER_USERNAME="uXXXXXXX"

# Backup-Space Subdirectory (useful for multiple backupped machines)
HETZNER_SUBDIR="/XXXXXXX/"

# local Backup-Folder
BACKUPDIR="/backup"

# HETZNER_MOUNTPOINT defines where the Backup-Space is being mounted via SSHFS
HETZNER_MOUNTPOINT="${BACKUPDIR}/hetzner-backup"

# ENCFS_MOUNTPOINT defines the path for EncFS to mount the decrypted Backup-Space
BCKFS_MOUNTPOINT="${BACKUPDIR}/backups"

# MySQL root-user password
MYSQL_PWD="XXXXXXXXXXXXXXXXXXXXXXX"

DATE=`date "+%Y-%m-%d-%H"`
BSRV="uXXXXXX@XXXXXXX.XX"

# mysqldump --extended-insert --force --log-error=log.txt -uBenutzer -pPasswort --all-databases | ssh -C benutzer@neuerServer "mysql -uBenutzer -pPasswort"

# Clean last MySQL Backup
rm /var/customers/dbs/*
databases=`mysql -u root -p${MYSQL_PWD} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`
for db in ${databases}; do
  logger -t "h(ourBackup)" "Dumping MySQL-DB ${db}"
  mysqldump -u root -p${MYSQL_PWD} ${db} --lock-all-tables --routines --events --triggers --force | gzip > "/var/customers/dbs/${db}.sql.gz"
#	MySQL-restore command
#  gunzip ${db}.sql.gz | mysql -u root -p${MYSQL_PWD} ${db}
done

# FS-Check 
umount -l ${BCKFS_MOUNTPOINT}
fsck -p ${HETZNER_MOUNTPOINT}/filesystem.img >> ${BACKUPDIR}/fsck.log
if [ $? -eq 4 ]; then
  logger -t "h(ourBackup)" "ERROR: Filesystem needs manual repair. Aborting."
  echo "Filesystem needs manual repair ${date} ${BSRV}" | \
  mail -s "ERROR Filesystem needs manual repair" floreno@web.de
  exit 1
fi

mount ${BCKFS_MOUNTPOINT}
if [ $? -ne 0 ]; then
  logger -t "h(ourBackup)" "ERROR: Unable to mount backup-image-filesystem. Aborting."
  exit 1
fi

rsync -azP \
  --quiet \
  --delete \
  --delete-excluded \
  --exclude-from=${BACKUPDIR}/exclude \
  --log-file=${BCKFS_MOUNTPOINT}/incomplete_backup.log \
  --link-dest=${BCKFS_MOUNTPOINT}/current \
  / ${BCKFS_MOUNTPOINT}/incomplete_backup

case $? in
	0|24)
		echo "success"
		mv ${BCKFS_MOUNTPOINT}/incomplete_backup ${BCKFS_MOUNTPOINT}/backup-${DATE} \
		&& mv ${BCKFS_MOUNTPOINT}/incomplete_backup.log ${BCKFS_MOUNTPOINT}/backup-${DATE}.log \
		&& rm -f ${BCKFS_MOUNTPOINT}/current \
		&& ln -s ${BCKFS_MOUNTPOINT}/backup-${DATE} ${BCKFS_MOUNTPOINT}/current
		logger -t "iBackup" "INFO: Delete old backups"
		${BDIR}/cleaner.bash

		echo "backup-${DATE} > "`find ${BCKFS_MOUNTPOINT}/backup-${DATE} -type f -links 1 -printf "%s\n" | awk '{s=s+$1} END {print s}'` >> ${BACKUPDIR}/space-used

		# get remote disk-usage and alarm usage over 70%
		DUSE=`echo "df" | sftp ${BSRV} 2>&1 | tail -n 1 | awk '{ print $5 }' | cut -d'%' -f1`
		if [ ${DUSE} -ge 70 ]; then
			logger -t "h(ourBackup)" "Running out of Backup-Space. ${date} ${BSRV} (${DUSE}%)"
			echo "Running out of Backup-Space. ${date} ${BSRV} (${DUSE}%)" | \
			mail -s "Alert: Backup-Space ${DUSE}%" ${REPORTMAIL}
		else
			logger -t "h(ourBackup)" "Backup-Space OK. ${BSRV} (${DUSE}%)"
		fi
		;;
	*)
		mail -s "ERROR RSYNC" ${REPORTMAIL}
		;;
esac
