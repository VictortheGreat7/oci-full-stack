#!/usr/bin/env bash

set -euo pipefail

#############################################
# Configuration
#############################################

USER_NAME=""
USER_EMAIL=""
GROUP_NAME=""
POLICY_NAME=""
COMPARTMENT_NAME=""

# OKE deployment region
DEPLOY_REGION="${OCI_REGION:-us-ashburn-1}"

# Required
TENANCY_OCID="${TENANCY_OCID:?TENANCY_OCID must be exported}"

WORKDIR=""

PRIVATE_KEY="${WORKDIR}/oci_api_key.pem"
PUBLIC_KEY="${WORKDIR}/oci_api_key_public.pem"

CREDENTIALS_JSON="${WORKDIR}/oci-credentials.json"
OCI_CONFIG="${WORKDIR}/config"


#############################################
# Initial setup
#############################################

mkdir -p "$WORKDIR"
chmod 700 "$WORKDIR"

command -v oci >/dev/null || {
    echo "OCI CLI missing"
    exit 1
}

command -v openssl >/dev/null || {
    echo "OpenSSL missing"
    exit 1
}

command -v uv >/dev/null || {
    echo "uv missing"
    exit 1
}


#############################################
# Helpers
#############################################

fail() {
    echo
    echo "ERROR: $1"
    exit 1
}


retry() {

    local attempts=5
    local delay=10

    until "$@"; do

        attempts=$((attempts-1))

        if [ "$attempts" -le 0 ]; then
            return 1
        fi

        echo "Retrying in ${delay}s..."
        sleep "$delay"

    done
}


#############################################
# OCI pre-flight checks
#############################################

echo "Running OCI pre-flight checks..."

echo "Using profile: ${OCI_CLI_PROFILE:-DEFAULT}"
echo "Using config : ${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"

# Authentication
oci iam region-subscription list >/dev/null 2>&1 || \
    fail "OCI CLI authentication failed."

# Tenancy access
oci iam tenancy get \
    --tenancy-id "$TENANCY_OCID" >/dev/null 2>&1 || \
    fail "Cannot access tenancy '$TENANCY_OCID'."

# IAM permissions
oci iam group list --limit 1 >/dev/null 2>&1 || \
    fail "Current OCI credentials do not have sufficient IAM privileges."

echo "Pre-flight checks passed."


#############################################
# Resolve IAM home region
#############################################

echo "Resolving OCI home region..."

IAM_REGION=$(oci iam region-subscription list \
    --query 'data[?"is-home-region"==`true`]."region-name" | [0]' \
    --raw-output)


[ -n "$IAM_REGION" ] || fail "Could not determine IAM home region"


echo "IAM region:"
echo "$IAM_REGION"


# IAM operations require home region

export OCI_CLI_REGION="$IAM_REGION"


#############################################
# Compartment
#############################################

echo "Checking compartment..."

COMPARTMENT_OCID=$(oci iam compartment list \
    --compartment-id "$TENANCY_OCID" \
    --compartment-id-in-subtree true \
    --all \
    --query 'data[?name==`'"$COMPARTMENT_NAME"'` && "lifecycle-state"==`"ACTIVE"`].id | [0]' \
    --raw-output)


if [ -z "$COMPARTMENT_OCID" ] || [ "$COMPARTMENT_OCID" == "null" ]; then

    echo "Creating compartment..."

    COMPARTMENT_OCID=$(oci iam compartment create \
        --name "$COMPARTMENT_NAME" \
        --description "Resources managed by Crossplane" \
        --compartment-id "$TENANCY_OCID" \
        --query "data.id" \
        --raw-output)


    echo "Waiting for IAM propagation..."
    sleep 15

else

    echo "Existing compartment:"
    echo "$COMPARTMENT_OCID"

fi


#############################################
# IAM Group
#############################################

echo "Checking IAM group..."

GROUP_OCID=$(oci iam group list \
    --name "$GROUP_NAME" \
    --query "data[0].id" \
    --raw-output)


if [ -z "$GROUP_OCID" ] || [ "$GROUP_OCID" == "null" ]; then

    GROUP_OCID=$(oci iam group create \
        --name "$GROUP_NAME" \
        --description "Crossplane OCI service account group" \
        --query "data.id" \
        --raw-output)

else

    echo "Existing group:"
    echo "$GROUP_OCID"

fi


#############################################
# IAM User
#############################################

echo "Checking IAM user..."

USER_OCID=$(oci iam user list \
    --name "$USER_NAME" \
    --query "data[0].id" \
    --raw-output)


if [ -z "$USER_OCID" ] || [ "$USER_OCID" == "null" ]; then

    USER_OCID=$(oci iam user create \
        --name "$USER_NAME" \
        --description "Crossplane OCI service account" \
        --email "$USER_EMAIL" \
        --query "data.id" \
        --raw-output)

else

    echo "Existing user:"
    echo "$USER_OCID"

fi


#############################################
# Group membership
#############################################

echo "Checking group membership..."

MEMBERSHIP=$(oci iam group list-users \
    --group-id "$GROUP_OCID" \
    --query 'data[?"user-id"==`'"$USER_OCID"'`] | length(@)' \
    --raw-output)


if [ "$MEMBERSHIP" == "0" ]; then

    retry oci iam group add-user \
        --group-id "$GROUP_OCID" \
        --user-id "$USER_OCID"

fi


#############################################
# IAM Policy
#############################################

echo "Checking policy..."


POLICY_STATEMENTS=$(uv run python <<EOF
import json

statements = [
    "Allow group ${GROUP_NAME} to manage cluster-family in compartment ${COMPARTMENT_NAME}",
    "Allow group ${GROUP_NAME} to manage instance-family in compartment ${COMPARTMENT_NAME}",
    "Allow group ${GROUP_NAME} to manage virtual-network-family in compartment ${COMPARTMENT_NAME}",
    "Allow group ${GROUP_NAME} to manage network-security-groups in compartment ${COMPARTMENT_NAME}",
    "Allow group ${GROUP_NAME} to manage volume-family in compartment ${COMPARTMENT_NAME}",
    "Allow group ${GROUP_NAME} to manage load-balancers in compartment ${COMPARTMENT_NAME}",
]

print(json.dumps(statements))
EOF
)

echo "$POLICY_STATEMENTS"


POLICY_OCID=$(oci iam policy list \
    --compartment-id "$TENANCY_OCID" \
    --name "$POLICY_NAME" \
    --query "data[0].id" \
    --raw-output)


if [ -z "$POLICY_OCID" ] || [ "$POLICY_OCID" == "null" ]; then

    echo "Creating policy..."

    oci iam policy create \
        --name "$POLICY_NAME" \
        --description "Crossplane OKE permissions" \
        --compartment-id "$TENANCY_OCID" \
        --statements "$POLICY_STATEMENTS"

else

    echo "Updating policy..."

    POLICY_VERSION_DATE=$(oci iam policy get \
        --policy-id "$POLICY_OCID" \
        --query 'data."version-date"' \
        --raw-output)

    oci iam policy update \
        --policy-id "$POLICY_OCID" \
        --statements "$POLICY_STATEMENTS" \
        --version-date "$POLICY_VERSION_DATE" \
        --force

fi


#############################################
# API Key generation
#############################################

if [ -f "$PRIVATE_KEY" ] && [ -f "$PUBLIC_KEY" ]; then

    echo "Using existing local key pair"

else

    echo "Generating RSA key pair"

    openssl genpkey \
        -algorithm RSA \
        -pkeyopt rsa_keygen_bits:2048 \
        -out "$PRIVATE_KEY"


    openssl rsa \
        -pubout \
        -in "$PRIVATE_KEY" \
        -out "$PUBLIC_KEY" \
        2>/dev/null


    chmod 600 "$PRIVATE_KEY"

fi


#############################################
# API Key upload
#############################################

echo "Checking OCI API keys..."


LOCAL_FINGERPRINT=$(openssl rsa \
    -pubin \
    -outform DER \
    -in "$PUBLIC_KEY" \
    2>/dev/null \
    | openssl md5 -c \
    | awk '{print $2}')


KEY_EXISTS=$(oci iam user api-key list \
    --user-id "$USER_OCID" \
    --query 'data[?fingerprint==`'"$LOCAL_FINGERPRINT"'`] | length(@)' \
    --raw-output)


if [ "$KEY_EXISTS" == "1" ]; then

    echo "API key already exists"

    FINGERPRINT="$LOCAL_FINGERPRINT"


else

    KEY_COUNT=$(oci iam user api-key list \
    --user-id "$USER_OCID" \
    --query 'length(data)' \
    --raw-output)

    KEY_COUNT=${KEY_COUNT:-0}


    if [ "$KEY_COUNT" -ge 3 ]; then

        if [ "${ROTATE_API_KEY:-false}" != "true" ]; then

            fail "Maximum OCI API keys reached. Set ROTATE_API_KEY=true to rotate."

        fi


        OLD_KEY=$(oci iam user api-key list \
            --user-id "$USER_OCID" \
            --query 'sort_by(data,&"time-created")[0].fingerprint' \
            --raw-output)


        oci iam user api-key delete \
            --user-id "$USER_OCID" \
            --fingerprint "$OLD_KEY" \
            --force

    fi


    echo "Uploading API key"


    FINGERPRINT=$(oci iam user api-key upload \
        --user-id "$USER_OCID" \
        --key-file "$PUBLIC_KEY" \
        --query "data.fingerprint" \
        --raw-output)


    sleep 15

fi


#############################################
# Generate Crossplane credentials
#############################################

echo "Generating credentials JSON"


uv run python <<EOF
import json

import json

data = {
    "tenancy_ocid": "$TENANCY_OCID",
    "user_ocid": "$USER_OCID",
    "fingerprint": "$FINGERPRINT",
    "region": "$DEPLOY_REGION",
    "private_key": open("$PRIVATE_KEY").read()
}

with open("$CREDENTIALS_JSON", "w") as f:
    json.dump(data, f, indent=2)

EOF


chmod 600 "$CREDENTIALS_JSON"


#############################################
# OCI config
#############################################

cat > "$OCI_CONFIG" <<EOF
[DEFAULT]
tenancy=$TENANCY_OCID
user=$USER_OCID
fingerprint=$FINGERPRINT
key_file=$PRIVATE_KEY
region=$DEPLOY_REGION
EOF


chmod 600 "$OCI_CONFIG"


#############################################
# Validate credentials
#############################################

echo "Validating credentials..."

export OCI_CLI_REGION="$DEPLOY_REGION"

oci iam region-subscription list \
    --auth api_key \
    --config-file "$OCI_CONFIG" >/dev/null


#############################################
# Done
#############################################

echo
echo "======================================"
echo "OCI Crossplane bootstrap complete"
echo "======================================"

echo
echo "User:"
echo "$USER_OCID"

echo
echo "Compartment:"
echo "$COMPARTMENT_OCID"

echo
echo "Fingerprint:"
echo "$FINGERPRINT"

echo
echo "Credentials:"
echo "$CREDENTIALS_JSON"

echo
echo "Create Kubernetes secret:"
echo

echo "kubectl create secret generic oci-creds \\"
echo "  -n crossplane-system \\"
echo "  --from-file=credentials=$CREDENTIALS_JSON"
