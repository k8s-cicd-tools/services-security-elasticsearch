#!/bin/bash
kubectl create secret generic "es-pw-elastic" -n "es" --from-literal password="PASTED_FROM_09_AUTO_GENERATE_ELASTICSEARCH_PASSWORDS_SH"
kubectl create secret generic "es-pw-logstash-writer" -n "es" --from-literal password="CREATE_PASSWORD_FOR_LOGSTASH_WRITER"