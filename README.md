# Services - Security Elasticsearch

This repository contains instructions on how to implement security in Elasticsearch, creating SSL certificates with cert-manager for: Elastic, Kibana. Additionally, an example of access control for documents where two users are only allowed to view data that arrives with the same namespace configured in the user's metadata is shown.

## How to get started
Clone this repository and change into the directory

1. Install Cert-Manager
```
$ ./01-install-cert-manager.sh

NAME                                           READY   STATUS              RESTARTS   AGE
pod/cert-manager-85ffc76c75-zrj54              0/1     ContainerCreating   0          5s
pod/cert-manager-cainjector-855dc46d64-2fvs8   1/1     Running             0          5s
pod/cert-manager-webhook-59589dbd6-wcng2       0/1     ContainerCreating   0          5s

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/cert-manager           ClusterIP   100.65.195.49    <none>        9402/TCP   6s
service/cert-manager-webhook   ClusterIP   100.64.200.198   <none>        443/TCP    5s

NAME                                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager              1         1         1            1           5s
deployment.apps/cert-manager-cainjector   1         1         1            1           5s
deployment.apps/cert-manager-webhook      1         1         1            0           5s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/cert-manager-85ffc76c75              1         1         1       5s
replicaset.apps/cert-manager-cainjector-855dc46d64   1         1         1       5s
replicaset.apps/cert-manager-webhook-59589dbd6       1         1         0       5s

```

2. Create the namespaces: es, dev1, and dev2.
```
kubectl apply -f 02-namespaces.yaml
```

3. Deploy the Certificate Issuer

```
kubectl apply -f 03-cert-issuer.yaml
```

4. Generate the certificates

```
kubectl apply -f 04-certs.yaml
```

5. Deploy the Master Node ConfigMap, Deployment, and Service

```
kubectl apply -f 05-es-master.yaml
```
6. Deploy the Data Node ConfigMap, Deployment, and Service

```
kubectl apply -f 06-es-data.yaml
```

7. Deploy the Client Node ConfigMap

```
kubectl apply -f 07-es-client-configmap.yaml
```

8. Deploy the Client Node StatefulSet and Service
 
```
kubectl apply -f 08-es-client.yaml
```

9. Auto generate the Elasticsearch Passwords

```
./09-auto-generate-passwords.sh

Changed password for user apm_system
PASSWORD apm_system = n2FMY063QhZb2AqVgjaL

Changed password for user kibana
PASSWORD kibana = rrJRdQR2YUnJyM4CHanM

Changed password for user logstash_system
PASSWORD logstash_system = QAVlqyQwaQQWYhMb0Mfz

Changed password for user beats_system
PASSWORD beats_system = mZdfAMHy3LF4ArGo8e1c

Changed password for user remote_monitoring_user
PASSWORD remote_monitoring_user = Pz0L7m1UMi7Ut6NP0iOB

Changed password for user elastic
PASSWORD elastic = DXhKanXVTTxFrkjHSfu4

```
10. Create secrets for the passwords.  

```
kubectl create secret generic "es-pw-elastic" -n "es" --from-literal password="PASTED_FROM_09_AUTO_GENERATE_ELASTICSEARCH_PASSWORDS_SH"
kubectl create secret generic "es-pw-logstash-writer" -n "es" --from-literal password="CREATE_PASSWORD_FOR_LOGSTASH_WRITER"
```
11. Enable SSL on the Client node.

```
kubectl apply -f 11-es-client-configmap-ssl.yaml
```

12. Restart the client node to pick up the new configmap.

```
kubectl rollout restart deployment.app/es-client -n es
```

13. Deploy Kibana

```
kubectl apply -f 13-kibana.yaml
```

14. Login to Kibana, login with the elastic user and the password from step 9, and open dev_tools and run the following command.

```
POST /_security/role/devrole
{
  "indices" : [
    {
      "names" : [ "logstash-*" ],
      "privileges" : [ "read" ],
      "query" : {
        "template" : {
          "source" : {
            "term" : { "kubernetes.namespace" : "{{_user.metadata.namespace}}" }
          }
        }
      }
    }
  ]
}

POST /_security/user/developer1
{
  "password" : "9a2b3c4d5e6f7g8h9i0j",
  "roles" : [ "devrole", "kibana_system", "kibana_user", "transport_client" ],
  "full_name" : "developer 1",
  "email" : "developer1@example.com",
  "metadata" : {
    "namespace" : "dev1"
  }
}



POST /_security/user/developer2
{
  "password" : "9a2b3c4d5e6f7g8h9i0j",
  "roles" : [ "devrole", "kibana_system", "kibana_user", "transport_client" ],
  "full_name" : "developer 2",
  "email" : "developer2@example.com",
    "metadata" : {
        "namespace" : "dev2"
    }
}


POST /_security/role/logstash_writer
{
  "cluster": ["manage_index_templates", "monitor"],
  "indices": [
    {
      "names": [ "logstash-*" ],
      "privileges": ["write","delete","create_index"]
    }
  ]
}

POST /_security/user/logstash_writer
{
  "password" : "CREATE_PASSWORD_FOR_LOGSTASH_WRITER",
  "roles" : [ "logstash_writer"],
  "full_name" : "Internal Logstash User"
}

```

15. Deploy Logstash

```
kubectl apply -f 15-logstash.yaml
```

16. Deploy Filebeat

```
kubectl apply -f 16-filebeat.yaml
```

17. Deploy couter app to generate logs on dev1
```
kubectl apply -f 17-counter-pod-dev1.yaml
``` 

18. Deploy couter app to generate logs on dev2
```
kubectl apply -f 18-counter-pod-dev2.yaml
```
20. Create a Kibana Index Pattern for logstash-*.

21. Check the logs in Kibana.
```
Time                       namespace    message
Oct 10, 2022 @ 01:28:40.739 dev2        Thanks for visiting devopscube! 465
Oct 10, 2022 @ 01:28:40.117 dev1        Thanks for visiting devopscube! 469
```

22. Login to Kibana as developer1 and check the logs.
```
Time                       namespace    message
Oct 10, 2022 @ 01:33:04.292 dev1    Thanks for visiting devopscube! 733
Oct 10, 2022 @ 01:33:03.290 dev1    Thanks for visiting devopscube! 732
Oct 10, 2022 @ 01:33:02.290 dev1    Thanks for visiting devopscube! 731
```
only logs from dev1 are visible.

23. Login to Kibana as developer2 and check the logs.
```
Oct 10, 2022 @ 01:35:26.182 dev2    Thanks for visiting devopscube! 870
Oct 10, 2022 @ 01:35:25.182 dev2    Thanks for visiting devopscube! 869
Oct 10, 2022 @ 01:35:24.181 dev2    Thanks for visiting devopscube! 868
```

only logs from dev2 are visible.

## References

* https://github.com/C2-Labs/k8s-security-elasticsearch
* https://www.elastic.co