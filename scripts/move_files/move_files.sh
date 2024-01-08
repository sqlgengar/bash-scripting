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

Dentro del direcorio que continene los archivos a copiar, no se toman todos, sino que se puede filtar cuales copiar por medio de la fecha de creacion,
en formato YYYY-MM-DD, por medio de las variables

date_init
date_end

Ademas se puede configurar cada cuantos archivos se crea un comprimido temporal, con la variable "max_files_chunk"

Se creara el archivo "log_script", para pode visualizar los eventos del script.
Se creara la carpeta "compress_files", esta va a contener todos los archivos comprimidos intermedios.
Se creara el archivo "file_names.txt", el cual contiene todos los nombres de los archivos a copiar.
Se creara el archivo "move_fails.txt", el cual es un log de todos los nombre de los archivos que no se copiaron, o se crearon incorrectamente.

COMMENT

# Fine tunning
path_source='./source/'
path_destiny='./destiny/'
date_init='2023-01-01'
date_end='2023-12-31'
max_files_chunk=1000

# Variables del script
path_log_script='./log_script.txt'
path_data_compress='./compress_files/'
path_fails='./move_fails.txt'
file_names='./file_names.txt'
count_files=0
count_group_files=0
compress_file="$path_data_compress$count_group_files.tar"

# Creacion de recursos para el script
rm -rf "$path_data_compress"
mkdir "$path_data_compress"
rm -f "$path_fails"
touch "$path_fails"
rm -f "$path_log_script"
touch "$path_log_script"

# Chequeo incial
if [ ! -d "$path_source" ] || [ ! -d "$path_destiny" ]; then
    echo "[!] DIRECTORIOS NO EXISTEN" >> "$path_log_script"

    echo "[#] LIMPIAR RECURSOS" >> "$path_log_script"
    rm -rf "$path_data_compress"
    rm -f "$file_names"
    rm -f "$path_fails"

    echo "[!] SCRIPT DONE" >> "$path_log_script"

    exit 1
fi
if [ -n "$(find "$path_source" -maxdepth 0 -empty)" ]; then
    echo "[!] DIRECTORIO VACIOS" >> "$path_log_script"

    echo "[#] LIMPIAR RECURSOS" >> "$path_log_script"
    rm -rf "$path_data_compress"
    rm -f "$file_names"
    rm -f "$path_fails"

    echo "[!] SCRIPT DONE" >> "$path_log_script"

    exit 1
fi

echo "[#] CREACION DE ARCHIVO TEMPORAL CON NOMBRE DE ARCHIVOS" >> "$path_log_script"
find "$path_source" -type f -newermt "$date_init" ! -newermt "$date_end" -exec basename {} \; > "$file_names"

echo "[#] CREACION DE ARCHIVOS COMPRIMIDOS" >> "$path_log_script"
exec 3< "$file_names"

while read -r file <&3; do
    path="$path_source$file"

    if [ "$count_files" -eq 0 ]; then
        echo "[+] CREANDO $(basename "$compress_file") ..." >> "$path_log_script"
        tar -cvf "$compress_file" -C "$path_source" "$(basename "$path")" >> "$path_log_script"

        ((count_files++))

        continue
    fi
    if [ "$((count_files % max_files_chunk))" -eq 0 ]; then
        ((count_group_files++))
        compress_file="$path_data_compress$count_group_files.tar"

        echo "[+] CREANDO $(basename "$compress_file") ..." >> "$path_log_script"
        tar -cvf "$compress_file" -C "$path_source" "$(basename "$path")" >> "$path_log_script"

        ((count_files++))

        continue
    fi

    echo "[.] AGREGANDO A $(basename "$compress_file") ..." >> "$path_log_script"
    tar -rvf "$compress_file" -C "$path_source" "$(basename "$path")" >> "$path_log_script"

    ((count_files++))
done
exec 3<&-

echo "[#] DESCOMPRESION DE ARCHIVOS" >> "$path_log_script"
amount_compress_files="$count_group_files"

for ((i=0; i<=amount_compress_files; i++)); do
    compress_file="$path_data_compress$i.tar"

    echo "[+] DESCOMPRIMIENDO $(basename "$compress_file") ..." >> "$path_log_script"
    tar -xvf "$compress_file" -C "$path_destiny" >> "$path_log_script"
done

echo "[#] CHEQUEAR ARCHIVOS" >> "$path_log_script"
exec 3< "$file_names"

while read -r file <&3; do
    file_destiny="$path_destiny$file"
    file_source="$path_source$file"

    crc32_destiny=$(crc32 "$file_destiny")
    crc32_source=$(crc32 "$file_source")

    echo "[.] CHEQUEANDO $(basename "$file_destiny") ..." >> "$path_log_script"
    if [ ! -e "$file_destiny" ] || [ "$crc32_destiny" != "$crc32_source" ]; then
        echo "$file" >> move_fails.txt
    fi
done
exec 3<&-

echo "[#] LIMPIAR RECURSOS" >> "$path_log_script"
rm -rf "$path_data_compress"
rm -f "$file_names"

echo "[!] SCRIPT DONE" >> "$path_log_script"
exit 0