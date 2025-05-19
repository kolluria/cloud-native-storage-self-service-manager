#!/bin/bash

if [ $# -lt 5 ]
then
	echo "./deploy.sh <namespace> <SV kubeconfig file> <VC creds file> <basicauth|oauth2> <(tls flag)true|false>
	<BasicAuth Username(required with basicauth)> <BasicAuth Password(required with basicauth)>
	<path-to-tls.key(required if tls enabled)> <path-to-tls.pem(required if tls enabled)>"
	exit 1
fi

NAMESPACE=$1
SV_KUBECONFIG_FILE=$2
VC_CREDS_FILE=$3
AUTH_MECHANISM=$4
TLS_FLAG=$5

if ! [ "$AUTH_MECHANISM" == "basicauth" ] && ! [ "$AUTH_MECHANISM" == "oauth2" ]
then
	echo "Auth mechanism needs to be either basicauth or oauth2."
	exit 1
fi

# Set variables depending on the values of auth mechanism and tls flag.
if [ "$AUTH_MECHANISM" == "basicauth" ]
then
	BASICAUTH_USERNAME=$6
	BASICAUTH_PASSWORD=$7

	if [ "$TLS_FLAG" == "true" ]
	then
		TLS_KEY=$8
		TLS_CERT=$9
	fi
else
	if [ "$TLS_FLAG" == "true" ]
	then
		TLS_KEY=$6
		TLS_CERT=$7
	fi
fi

# Create a secret that has SV cluster's admin kubeconfig.
# Edit the sv_kubeconfig file as per your deployment.
kubectl -n "$NAMESPACE" create secret generic sv-kubeconfig --from-file=$SV_KUBECONFIG_FILE
if [ $? -ne 0 ]
then
	echo "Failed to create sv-kubeconfig secret."
	exit 1
fi

# Create a secret that has the vCenter's admin creds.
# Edit vc_creds.json as per your requirement.
kubectl -n "$NAMESPACE" create secret generic vc-creds --from-file="$VC_CREDS_FILE"
if [ $? -ne 0 ]
then
	echo "Failed to create vc-creds secret."
	exit 1
fi

# If auth mechanism is basicauth, create a secret that has basic auth credentials hashed using SHA512
# password algorithm. Create a temp file with credentials and remove it after creating the secret.
if [ "$AUTH_MECHANISM" == "basicauth" ]
then
    # Assign manifest folder
    MANIFEST_FOLDER="basic-auth"
    echo -n "$BASICAUTH_USERNAME": >> basicauth_creds
    # `-6` specifies SHA512 password algorithm
    openssl passwd -6 "$BASICAUTH_PASSWORD" >> basicauth_creds
    kubectl -n "$NAMESPACE" create secret generic basicauth-creds --from-file=basicauth_creds
    if [ $? -ne 0 ]
    then
        echo "Failed to create basicauth-creds secret."
        exit 1
    fi
    rm basicauth_creds
else
    # Assign manifest folder
    MANIFEST_FOLDER="oauth2"
fi

# Create a config map for nginx-conf
kubectl -n "$NAMESPACE" create configmap nginx-conf --from-file=$MANIFEST_FOLDER/nginx.conf
if [ $? -ne 0 ]
then
	echo "Failed to create nginx-conf config map."
	exit 1
fi

# If ssl is set to true, create a secret to store ssl key and cert.
if [ "$TLS_FLAG" == "true" ]
then
	kubectl -n "$NAMESPACE" create secret tls cnsmanager-tls --key "$TLS_KEY" --cert "$TLS_CERT"
	if [ $? -ne 0 ]	
	then	
		echo "Failed to create cnsmanager-tls secret."	
		exit 1	
	fi
fi

# Create LoadBalancer service for CNS manager
kubectl -n "$NAMESPACE" apply -f $MANIFEST_FOLDER/service.yaml
if [ $? -ne 0 ]
then
  echo "Failed to create LoadBalancer service for CNS manager."
  exit 1
fi

# Wait for the external IP to be assigned to the service.
echo "Waiting for external IP to be assigned to CNS manager service..."
CNS_MANAGER_ENDPOINT=""

while [ -z "$CNS_MANAGER_ENDPOINT" ]
do
  IP=$(kubectl -n "$NAMESPACE" get svc cns-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -n "$IP" ] && CNS_MANAGER_ENDPOINT=$IP:8081
  [ -z "$CNS_MANAGER_ENDPOINT" ] && sleep 10
done

echo "CNS manager service is assigned external IP: $CNS_MANAGER_ENDPOINT"

# Create a config map for the CNS manager swagger API spec.
sed "s/%CNS_MANAGER_ENDPOINT%/$CNS_MANAGER_ENDPOINT/g" swagger-template.yaml > swagger.yaml
kubectl -n "$NAMESPACE" create configmap swagger-api --from-file=swagger.yaml
if [ $? -ne 0 ]
then
	echo "Failed to create swagger-api config map."
	exit 1
fi
rm swagger.yaml

# Deploy CNS manager
sed -e "s#%CNS_MANAGER_ENDPOINT%#$CNS_MANAGER_ENDPOINT#g" \
    -e "s#%CNS_MANAGER_NAMESPACE%#$NAMESPACE#g" \
	-e "s#%AUTH_TYPE%#$AUTH_MECHANISM#g" \
		$MANIFEST_FOLDER/deploy-template.yaml > deploy.yaml
kubectl -n "$NAMESPACE" apply -f deploy.yaml
if [ $? -ne 0 ]
then
	echo "Failed to deploy CNS manager."
	exit 1
fi
rm deploy.yaml
