## Deploying CNS Manager with basic auth

Below are the steps to configure, deploy & run cns-manager on a vanilla Kubernetes cluster with basic auth.

### Prepare the config

1. Capture kubeconfig of the cluster in which CNS manager is being deployed in a file named `sv_kubeconfig`.  
   Refer to sample config file provided under config folder.

2. Create a file named vc_creds.json and copy into it the credentials to your VC.  
   Refer to sample config file provided under config folder.

```
{
    "vc": "<vc-ip>",
    "user": "<vc-user@domain>",
    "password": "<vc-password>"
}
```

### Deploy the application

* After preparing the config, use the following command to deploy CNS manager on the cluster.

```
> cd deploy
> ./deploy.sh <namespace> <path-to-sv_kubeconfig> <path-to-vc_creds.json> basicauth <(tls flag)true|false> <BasicAuth Username(required with basicauth)> <BasicAuth Password(required with basicauth)> <path-to-tls.key(required if tls enabled)> <path-to-tls.pem(required if tls enabled)> 
```

Note: The basicauth username and password used here is what admin chooses while deploying this application, and it may
not be same as the vCenter username and password.

For example

```
> ./deploy.sh cns-manager ../config/sv_kubeconfig ../config/vc_creds.json basicauth false 'Administrator' 'Admin123@'
```

Please ensure to use single quotes around username and password. This will ensure that any special characters in
username or password are escaped.

* The deployment script will create a bunch of Kubernetes objects. The sample output should look like as described
  below.  
  Once the deployment is successful, verify that CNS manager pod is running in the namespace.

```
> ./deploy.sh cns-manager ../config/sv_kubeconfig ../config/vc_creds.json basicauth false 'Administrator' 'Admin123@'

secret/sv-kubeconfig created
secret/vc-creds created
secret/basicauth-creds created
configmap/nginx-conf created
service/cns-manager created
Waiting for external IP to be assigned to CNS manager service...
CNS manager service is assigned external IP: 192.168.130.5:8081
configmap/swagger-api created
serviceaccount/cns-manager created
rolebinding.rbac.authorization.k8s.io/cns-manager-syspriv-rolebinding created
customresourcedefinition.apiextensions.k8s.io/orphanvolumestats.cnsmanager.cns.vmware.com created
customresourcedefinition.apiextensions.k8s.io/volumemigrationjobs.cnsmanager.cns.vmware.com created
customresourcedefinition.apiextensions.k8s.io/volumemigrationtasks.cnsmanager.cns.vmware.com created
customresourcedefinition.apiextensions.k8s.io/snapshotdeletionjobs.cnsmanager.cns.vmware.com created
customresourcedefinition.apiextensions.k8s.io/snapshotdeletiontasks.cnsmanager.cns.vmware.com created
role.rbac.authorization.k8s.io/cns-manager created
rolebinding.rbac.authorization.k8s.io/cns-manager-rolebinding created
configmap/cnsmanager-config created
deployment.apps/cns-manager created

> kubectl get pods -n cns-manager  
NAME                           READY  STATUS    RESTARTS        AGE 
cns-manager-6ff456dc97-nrj65   3/3    Running       0           54s

> kubectl get service cns-manager -n cns-manager
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                       AGE
cns-manager   LoadBalancer   172.24.97.207   192.168.130.5   8081:30982/TCP,443:32754/TCP,2114:31806/TCP   42h
```

* After the deployment is successful, the External IP of the service can be used to access CNS manager APIs.  
  In the above example, the CNS manager endpoint will be `http://192.168.130.5:8081`
* The Swagger UI for invoking APIs can be accessed at <CNS_Manager_Endpoint>/ui/  
  This will need basic auth credentials selected during deployment.

Alternatively, the APIs can also be invoked using some other client like *curl*, with basicauth credentials passed in
command line arguments.  
For instance:

```
curl -X 'GET' '<CNS_Manager_Endpoint>/1.0.0/datastoreresources?datacenter=VSAN- DC&datastore=vsanDatastore' -H 'accept: application/json' -u "Admistrator:Admin123@"
```

Please note that the Swagger UI is accessible through URL <CNS_Manager_Endpoint>/ui/  
and the backend APIs are accessible with URL prefix <CNS_Manager_Endpoint>/1.0.0/