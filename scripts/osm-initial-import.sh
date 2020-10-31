#!/usr/bin/env bash
set -e

pbf_dir="/srv/pbf"
sql_dir="/srv/sql"
log_file="/var/log/osm-initial-import.log"
pbf_file_url=

function show_help() {
  echo "osm-initial-import -p <pbf_file_url> [-H <database_host>] [-s]"
  echo "  pbf_file_url: look for small dumps unless you want the whole world, which can take up to 30 hours processing"
  echo "  database_host: hostname of the postgresql database, default to `hostname -f`"
  echo ""
  echo ""
  echo "  example:"
  echo "      osm-initial-import \\"
  echo "        -p http://download.geofabrik.de/asia/israel-and-palestine-latest.osm.pbf \\"
}

while getopts "d:hH:s:w:p:-:" opt; do
  case "${opt}" in
  p)  pbf_file_url="${OPTARG}"
      ;;
  h)  show_help
      exit 0
      ;;
  H)  database_host="${OPTARG}"
      ;;
  esac
done
if [ "$scripts_only" = false ]; then

if [ "${pbf_file_url}" == "" ] ; then
    echo "pbf file URL is mandatory (-p)"
    exit -1
fi

fi
regex='(.*)/(.*)$'
[[ $pbf_file_url =~ $regex ]]
download_url=${BASH_REMATCH[1]}
filename=${BASH_REMATCH[2]}
function download_pbf() {
    echo "starting download of PBF from ${download_url}"
    cd ${pbf_dir}
    if [ ! -f "$pbf_dir/$filename.md5" ]; then
        curl ${proxy} -O ${pbf_file_url}.md5
    fi
    if [ ! -f "$pbf_dir/$filename" ]; then
        curl ${proxy} -O ${pbf_file_url}
    fi
    echo "starting md5sum check"
    md5sum -c ${filename}.md5
    if [ $? -ne 0 ] ; then
        echo "Download of PBF file failed, md5sum is invalid"
        exit -1
    fi
    echo "download of PBF from planet.openstreetmap.org completed"
}

function reset_postgres() {
  echo "starting reset of prosgresql database"
  psql -h ${database_host} -U ${PGUSER} -d ${PGDATABASE} -c 'DROP TABLE IF EXISTS admin, planet_osm_line, planet_osm_point, planet_osm_polygon, planet_osm_roads, water_polygons CASCADE;'
  echo "reset of prosgresql database completed"
}

function initial_osm_import() {
  echo "starting initial OSM import"
  psql -h ${database_host} -U ${PGUSER} -d ${PGDATABASE} -c 'CREATE EXTENSION IF NOT EXISTS postgis; CREATE EXTENSION IF NOT EXISTS hstore;' && \
  imposm import \
    -connection postgis://${PGUSER}:${PGPASSWORD}@${database_host}:5432/${PGDATABASE}?prefix=NONE \
    -mapping /etc/imposm/mapping.yml \
    -overwritecache \
    -read ${pbf_dir}/${filename} \
    -diff \
    -write

  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "imposm3 failed to complete initial import"
    exit -1
  fi
  echo "initial OSM import completed, starting production deploy"
  imposm import \
    -connection postgis://${PGUSER}:${PGPASSWORD}@${database_host}:5432/${PGDATABASE}?prefix=NONE \
    -mapping /etc/imposm/mapping.yml \
    -overwritecache \
    -deployproduction

  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "imposm3 failed to deploy import"
    exit -1
  fi
  echo "initial OSM import deployed to production schema"
}

function import_water_lines() {
    echo "starting water line import"
    echo "WARNING: water-polygons-split-3857.zip size is 539M"
    cd ${pbf_dir}
    if [ ! -f "$pbf_dir/water-polygons-split-3857.zip" ]; then
        curl -O https://osmdata.openstreetmap.de/download/water-polygons-split-3857.zip
    fi
    if [ ! -f "$pbf_dir/water-polygons-split-3857/water_polygons.shp" ]; then
        unzip water-polygons-split-3857.zip
    fi
    shp2pgsql -c -s 3857 -g way water-polygons-split-3857/water_polygons.shp water_polygons | psql -h ${database_host} -U ${PGUSER} -d ${PGDATABASE}
    echo "water line import completed"
}

function custom_functions_and_indexes() {
  echo "starting creation of custom functions and indexes"
  for sql_file in `ls ${sql_dir}`; do
      echo "  executing: ${sql_file}"
      psql -h ${database_host} -U ${PGUSER} -Xd ${PGDATABASE} -f ${sql_dir}/${sql_file}
  done
  echo "creation of custom functions and indexes completed"
}

download_pbf
reset_postgres
initial_osm_import
import_water_lines
custom_functions_and_indexes
