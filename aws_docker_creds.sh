#!/bin/bash

set -e

echo 'AWS ECR dockercfg generator'

DOCKER_CONFIG_CACHE="${DOCKER_CONFIG_CACHE-/data/cache/docker-config.json}"
mkdir -p $(dirname ${DOCKER_CONFIG_CACHE})
if [ -f "${DOCKER_CONFIG_CACHE}" ]; then
  echo 'Using cached docker config'
  cp "${DOCKER_CONFIG_CACHE}" $1
  exit 0
fi

: "${AWS_REGION:?Need to set AWS_REGION}"
: "${AWS_ACCESS_KEY_ID:?Need to set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Need to set AWS_SECRET_ACCESS_KEY}"

cat << EOF > ~/.aws/config
[default]
region = $AWS_REGION
EOF

# For multi account aws setups, use primary credentials to assume the role in
# the target account
if [[ -n $AWS_STS_ROLE || -n $AWS_STS_ACCOUNT ]]; then
  : "${AWS_STS_ROLE:?Need to set AWS_STS_ROLE}"
  : "${AWS_STS_ACCOUNT:?Need to set AWS_STS_ACCOUNT}"

  role="arn:aws:iam::${AWS_STS_ACCOUNT}:role/${AWS_STS_ROLE}"
  echo "Using STS to get credentials for ${role}"

  aws_tmp=$(mktemp -t aws-json-XXXXXX)

  aws sts assume-role --role-arn "${role}" --role-session-name aws_docker_creds > "${aws_tmp}"

  export AWS_ACCESS_KEY_ID=$(cat ${aws_tmp} | jq -r ".Credentials.AccessKeyId")
  export AWS_SECRET_ACCESS_KEY=$(cat ${aws_tmp} | jq -r ".Credentials.SecretAccessKey")
  export AWS_SESSION_TOKEN=$(cat ${aws_tmp} | jq -r ".Credentials.SessionToken")
  export AWS_SESSION_EXPIRATION=$(cat ${aws_tmp} | jq -r ".Credentials.Expiration")
fi

# fetching aws docker login
echo "Logging into AWS ECR"
$(aws ecr get-login)

# writing aws docker creds to desired path
echo "Writing Docker creds to $1"
chmod 544 ~/.docker/config.json
cp ~/.docker/config.json ${DOCKER_CONFIG_CACHE}
cp ~/.docker/config.json $1

