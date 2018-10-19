#!/bin/bash -e
# shellcheck disable=SC2155,SC1001,SC2015,SC2128
##############################################################################
# Copyright (c) 2018 Mirantis Inc., Enea AB and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
# Library of shell functions dedicated to j2 template handling
#

# ZaaS: Convert Pharos-compatible POD Descriptor File (PDF) to reclass model input
UTILS_GEN_CONFIG_SCRIPT="./utils/generate_config.py"
PHAROS_VALIDATE_SCHEMA_SCRIPT='./utils/validate_schema.py'

function generate_cookiecutter_templates {
  local storage_dir=$1; shift
  local target_lab=$1; shift
  local target_pod=$1; shift
  local lab_config_uri=$1

  BASE_CONFIG_PDF="${lab_config_uri}/labs/${target_lab}/${target_pod}.yaml"
  BASE_CONFIG_IDF="${lab_config_uri}/labs/${target_lab}/idf-${target_pod}.yaml"
  LOCAL_PDF="${storage_dir}/$(basename "${BASE_CONFIG_PDF}")"
  LOCAL_IDF="${storage_dir}/$(basename "${BASE_CONFIG_IDF}")"

  if ! curl --create-dirs -o "${LOCAL_PDF}" "${BASE_CONFIG_PDF}"; then
      notify_e "[ERROR] Could not retrieve PDF (Pod Descriptor File)!"
  elif ! curl -o "${LOCAL_IDF}" "${BASE_CONFIG_IDF}"; then
      notify_e "[ERROR] POD has no IDF (Installer Descriptor File)!"
  fi

  PHAROS_SCHEMA_PDF="${lab_config_uri}/labs/${target_lab}/${target_pod}.schema.yaml"
  PHAROS_SCHEMA_IDF="${lab_config_uri}/labs/${target_lab}/idf-${target_pod}.schema.yaml"
  LOCAL_SCHEMA_PDF="${storage_dir}/$(basename "${PHAROS_SCHEMA_PDF}")"
  LOCAL_SCHEMA_IDF="${storage_dir}/$(basename "${PHAROS_SCHEMA_IDF}")"

  if ! curl --create-dirs -o "${LOCAL_SCHEMA_PDF}" "${PHAROS_SCHEMA_PDF}"; then
      notify_e "[ERROR] Could not retrieve PDF SCHEMA file!"
  elif ! curl -o "${LOCAL_SCHEMA_IDF}" "${PHAROS_SCHEMA_IDF}"; then
      notify_e "[ERROR] Could not retrieve IDF SCHEMA file!"
  fi

  # Check first if configuration files are valid
  if [[ ! "$target_pod" =~ "virtual" ]]; then
    if ! "${PHAROS_VALIDATE_SCHEMA_SCRIPT}" -y "${LOCAL_PDF}" \
      -s "${LOCAL_SCHEMA_PDF}"; then
      notify_e "[ERROR] PDF does not match yaml schema!"
    elif ! "${PHAROS_VALIDATE_SCHEMA_SCRIPT}" -y "${LOCAL_IDF}" \
      -s "${LOCAL_SCHEMA_IDF}"; then
      notify_e "[ERROR] IDF does not match yaml schema!"
    fi
  fi

  BASE_COOKIECUTTER_TEMPLATE="${lab_config_uri}/labs/${target_lab}/${target_pod}-cookiecutter.json.j2"
  LOCAL_COOKIECUTTER_TEMPLATE="${storage_dir}/$(basename "${BASE_COOKIECUTTER_TEMPLATE}")"
  LOCAL_COOKIECUTTER_YAML="${storage_dir}/cookiecutter.yaml"
  LOCAL_COOKIECUTTER_JSON="${storage_dir}/cookiecutter.json"

  if curl --create-dirs -o "${LOCAL_COOKIECUTTER_TEMPLATE}" "${BASE_COOKIECUTTER_TEMPLATE}"; then
      if ! "${UTILS_GEN_CONFIG_SCRIPT}" -y "${LOCAL_PDF}" \
          -j "${LOCAL_COOKIECUTTER_TEMPLATE}" -f "json" > "${LOCAL_COOKIECUTTER_JSON}"; then
          notify_e "[ERROR] Could not convert PDF to cookiecutter input json!"
      fi
      if ! "${UTILS_GEN_CONFIG_SCRIPT}" -y "${LOCAL_PDF}" \
          -j "${LOCAL_COOKIECUTTER_TEMPLATE}" -f "yaml" > "${LOCAL_COOKIECUTTER_YAML}"; then
          notify_e "[ERROR] Could not convert PDF to cookiecutter input yaml!"
      fi

  else
     notify_i "[WARN] Could not retrieve basic cookiecutter template, will use a default one!"
  fi

  [[ -f ${LOCAL_COOKIECUTTER_YAML} ]] && {
     set +x
     notify_i "[INFO] cookiecutter patameters:"
     notify_i " $(cat $LOCAL_COOKIECUTTER_YAML)"
  }

}
