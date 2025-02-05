#!/bin/bash

backup="/etc/pterodactyl/backups/$(date '+%Y-%m-%d_%H-%M-%S')"
pterodactyl="/var/www/pterodactyl"
minio=false
minio_url=""
minio_bucket=""
minio_access_key=""
minio_secret_key=""
operation=""
file=""

debug=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            debug=true
            shift
            ;;
        --minio-url)
            minio=true
            minio_url="$2"
            shift 2
            ;;
        --minio-bucket)
            minio_bucket="$2"
            shift 2
            ;;
        --minio-access-key)
            minio_access_key="$2"
            shift 2
            ;;
        --minio-secret-key)
            minio_secret_key="$2"
            shift 2
            ;;
        --pterodactyl)
            pterodactyl="$2"
            shift 2
            ;;
        export|import)
            operation="$1"
            shift
            ;;
        --file)
            file="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$debug" == true ]; then
    set -x
fi

if [ -z "$operation" ]; then
    echo -e " ${r}●${w} Valid operations are 'export' or 'import'."
    exit 1
fi

if [ ! -f "$pterodactyl/.env" ]; then
    echo -e " ${r}●${w} Pterodactyl .env file not found at $pterodactyl/"
    exit 1
fi

source "$pterodactyl/.env"

if ! mysqladmin ping -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" --silent > /dev/null 2>&1; then
    echo -e " ${r}●${w} MySQL connection failed. Check your credentials and host."
    exit 1
fi

# Debug output
if [ "$debug" == true ]; then
    set -x
fi

case "$operation" in
    export)
        mkdir -p "$backup"
        mysqldump -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" --opt "$DB_DATABASE" > "$backup/pterodactyl.sql"
        cp "$pterodactyl/.env" "$backup/.env"
        tar -czvf "$backup.tar.gz" -C "$(dirname "$backup")" "$(basename "$backup")" > /dev/null 2>&1
        rm -r "$backup"
        echo -e " ${g}●${w} Backup saved to: $backup.tar.gz"

        if [ "$minio" == true ]; then
            if [ -z "$minio_url" ] || [ -z "$minio_bucket" ] || [ -z "$minio_access_key" ] || [ -z "$minio_secret_key" ]; then
                echo -e " ${r}●${w} Missing MinIO configuration."
                exit 1
            fi

            mc alias set minio "$minio_url" "$minio_access_key" "$minio_secret_key" > /dev/null 2>&1

            if ! mc ls "minio/$minio_bucket" > /dev/null 2>&1; then
                echo -e " ${r}●${w} MinIO connection failed. Check your MinIO configuration."
                exit 1
            fi

            mc cp "$backup.tar.gz" "minio/$minio_bucket/$(basename "$backup.tar.gz")" > /dev/null 2>&1
            echo -e " ${g}●${w} Backup uploaded to MinIO bucket: $minio_bucket"
        fi
        ;;

    import)
        if [ "$minio" == true ]; then
            if [ -z "$minio_url" ] || [ -z "$minio_bucket" ] || [ -z "$minio_access_key" ] || [ -z "$minio_secret_key" ]; then
                echo -e " ${r}●${w} Missing MinIO configuration."
                exit 1
            fi

            mc alias set minio "$minio_url" "$minio_access_key" "$minio_secret_key" > /dev/null 2>&1

            backups=($(mc ls "minio/$minio_bucket" | awk '{print $6}'))
            num_backups=${#backups[@]}

            if [ $num_backups -eq 0 ]; then
                echo -e " ${r}●${w} No backups found in MinIO bucket: $minio_bucket."
                exit 1
            fi

            echo -e " ${y}●${w} Select a backup from MinIO to restore:"

            select backup in "${backups[@]}"; do
                if [ -n "$backup" ]; then
                    file="/tmp/$backup"
                    mc cp "minio/$minio_bucket/$backup" "$file" > /dev/null 2>&1
                    break
                fi
            done
        fi

        if [ -z "$file" ] || [ ! -f "$file" ]; then
            backups=("/etc/pterodactyl/backups"/*.tar.gz)
            num_backups=${#backups[@]}

            if [ $num_backups -eq 0 ]; then
                echo -e " ${r}●${w} No backup archives found in /etc/pterodactyl/backups."
                exit 1
            fi

            echo -e " ${y}●${w} Select a local backup to restore:"

            select backup in "${backups[@]}"; do
                if [ -n "$backup" ]; then
                    file="$backup"
                    break
                fi
            done
        fi

        echo -e -n " ${y}●${w} Restoring a backup ${r}WILL OVERWRITE${w} the current database and environment. ${r}PROCEED ONLY IF YOU KNOW WHAT ARE YOU DOING!!!${w} Continue? (y/N): "
        read -r confirm
        if [ "$confirm" != "y" ]; then
            echo -e " ${r}●${w} Restore cancelled."
            exit 1
        fi

        tar -xzvf "$file" -C /tmp > /dev/null 2>&1
        output="/tmp/$(basename "$file" .tar.gz)"

        if [ ! -f "$output/pterodactyl.sql" ]; then
            echo -e " ${r}●${w} Invalid backup file: missing database dump."
            exit 1
        fi

        mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" < "$output/pterodactyl.sql"
        cp "$output/.env" "$pterodactyl/.env"
        rm -r "$output"

        echo -e " ${g}●${w} Backup imported successfully."
        ;;
esac

if [ "$debug" == true ]; then
    set +x
fi
