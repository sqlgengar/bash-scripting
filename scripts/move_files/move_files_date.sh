#!/usr/bin/env bash

: <<'COMMENT'

Este script esta pensado para copiar muchos archivos chicos de un unico directorio a otro path.
Por lo cual va a escribir todos los eventos en un log y poder dejar el script en detach.
Para poder utilizar crc32 en Debian, se debe instalar este paquete "libarchive-zip-perl".
Se recomienda utilizar paths relativos.
El script creara recursos en la misma carpeta que se ejecute, no se recomentida utilizar la carpeta del usuario /root/.
La seleccion de la carpate donde se buscan los archivos y donde se copian se hacen por medio de la variables

path_source
path_destiny

Dentro del directorio que contine los archivos a copiar, no se toman todos, sino que se puede filtar cuales copiar por medio de la fecha de creacion,
en formato YYYY-MM-DD, por medio de las variables

date_init
date_end

Se creara el archivo "log_script", para pode visualizar los eventos del script.
Se creara el archivo "file_names.txt", el cual contiene todos los nombres de los archivos a copiar.
Se creara el archivo "move_fails.txt", el cual es un log de todos los nombre de los archivos que no se copiaron, o se crearon incorrectamente.

COMMENT

# Fine tunning.
path_source='./source/'
path_destiny='./destiny/'
date_init='2023-01-01'
date_end='2023-12-31'

# Variables del script.
path_log_script='./log_script.txt'
file_names='./file_names.txt'
path_fails='./move_fails.txt'

# Creacion de recursos para el script.
rm -f "$path_log_script"
touch "$path_log_script"
rm -f "$path_fails"
touch "$path_fails"

# Chequeo incial.
if [ ! -d "$path_source" ] || [ ! -d "$path_destiny" ]; then
    echo "[!] DIRECTORIOS NO EXISTEN" >> "$path_log_script"

    echo "[#] LIMPIAR RECURSOS" >> "$path_log_script"
    rm -f "$path_fails"

    echo "[!] SCRIPT DONE" >> "$path_log_script"

    exit 1
fi
if [ -n "$(find "$path_source" -maxdepth 0 -empty)" ]; then
    echo "[!] DIRECTORIO VACIOS" >> "$path_log_script"

    echo "[#] LIMPIAR RECURSOS" >> "$path_log_script"
    rm -f "$path_fails"

    echo "[!] SCRIPT DONE" >> "$path_log_script"

    exit 1
fi

# Logica para mover archivos
echo "[#] CREACION DE ARCHIVO TEMPORAL CON NOMBRE DE ARCHIVOS" >> "$path_log_script"
find "$path_source" -type f -newermt "$date_init" ! -newermt "$date_end" -exec basename {} \; > "$file_names"

echo "[#] MOVER ARCHIVOS" >> "$path_log_script"
exec 3< "$file_names"

while read -r file <&3; do
    path="$path_source$file"

    echo "[+] MOVIENDO ARCHIVO $path A $path_destiny" >> "$path_log_script"
    cp --preserve="all" "$path" "$path_destiny"
done
exec 3<&-

# Chequeo final.
echo "[#] CHEQUEAR ARCHIVOS" >> "$path_log_script"
exec 3< "$file_names"

while read -r file <&3; do
    file_destiny="$path_destiny$file"
    file_source="$path_source$file"

    crc32_destiny=$(crc32 "$file_destiny")
    crc32_source=$(crc32 "$file_source")

    echo "[.] CHEQUEANDO $(basename "$file_destiny") ..." >> "$path_log_script"
    if [ ! -e "$file_destiny" ] || [ "$crc32_destiny" != "$crc32_source" ]; then
        echo "$file" >> "$path_fails"
    fi
done
exec 3<&-

echo "[!] SCRIPT DONE" >> "$path_log_script"
exit 0