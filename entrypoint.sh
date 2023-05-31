#!/bin/bash

DTRACK_URL=$1
DTRACK_KEY=$2
LANGUAGE=$3
DELETE=$4
NPM_TOKEN=$5
NODE_VERSION=$6
PYTHON_VERSION=$7

INSECURE="--insecure"
#VERBOSE="--verbose"

# Access directory where GitHub will mount the repository code
cd $GITHUB_WORKSPACE

# Run check for delete variable first so that install doesn't need to be run
PROJECT=$(curl -X GET -G --data-urlencode "name=$GITHUB_REPOSITORY"  \
                         --data-urlencode "version=$GITHUB_BASE_REF" \
                         "$DTRACK_URL/api/v1/project/lookup" -H  "accept: application/json" -H  "X-Api-Key: $DTRACK_KEY")

PROJECT_EXISTS=$(echo $PROJECT | jq ".active")

if [[ -n "$PROJECT_EXISTS" ]]; then
    PROJECT_UUID=$(echo $PROJECT | jq -r ".uuid")
else
    PROJECT_UUID=$(curl \
        -d "{  \"name\": \"$GITHUB_REPOSITORY\",  \"version\": \"$GITHUB_BASE_REF\"}" \
        -X PUT "$DTRACK_URL/api/v1/project" \
        -H  "accept: application/json" \
        -H  "Content-Type: application/json" \
        -H  "X-Api-Key: $DTRACK_KEY" | jq -r ".uuid"
    )
fi


if [[ $DELETE == "true" ]]; then
    DELETE_CODE=$(curl -X DELETE --head -w "%{http_code}" "$DTRACK_URL/api/v1/project/$PROJECT_UUID" -H  "accept: application/json" -H  "X-Api-Key: $DTRACK_KEY")
    echo "DELETE_CODE is $DELETE_CODE"
    if [[ $DELETE_CODE == "HTTP/2 204" ]]; then
        exit 0
    else
        echo $PROJECT
        echo $PROJECT_EXISTS
        echo $GITHUB_HEAD_REF
        echo $PROJECT_UUID
        exit 1
    fi
fi

case $LANGUAGE in
    "nodejs")
        echo "[*] Installing and configuring nvm..."

        # install nvm
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        echo "[*] Configuring .npmrc with token..."
        echo "//npm.pkg.github.com/:_authToken=${NPM_TOKEN}" > ~/.npmrc

        echo "[*] Installing node-${NODE_VERSION}"
        nvm install ${NODE_VERSION}
        nvm alias default ${NODE_VERSION}
        nvm use default

        echo "[*] Installing all the modules..."
        npm install

        if [ ! $? = 0 ]; then
            echo "[-] Error installing node modules. Pop smoke!"
            exit 1
        fi

        echo "[*] Processing NodeJS SBOM..."
        npm install --global @cyclonedx/cyclonedx-npm

        path="bom.xml"
 
        BoMResult=$(cyclonedx-npm --output-format XML --ignore-npm-errors --short-PURLs --output-file bom.xml)
        ;;

    "python")
        echo "[*] Installing and configuring pyenv..."
        
        curl https://pyenv.run | bash
        export PYENV_ROOT="$HOME/.pyenv" >> ~/.profile
        command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH" >> ~/.profile
        eval "$(pyenv init -)" >> ~/.profile

        pyenv install $PYTHON_VERSION
        pyenv global $PYTHON_VERSION

        echo "[*] Finding all the requirements.txt files..."
        # output and input filenames must be distinct or we get an infinite loop
        find . -name "requirements.txt" -exec cat > test.txt {} +
        mv test.txt requirements.txt

        if [ ! $? = 0 ]; then
            echo "[-] Error concatenating requirements files in repo. Pop smoke!"
            exit 1
        fi

        echo "[*] Processing Python SBOM..."
        
        pip install cyclonedx-bom

        path="bom.xml"
        # this may need to be modified to use -e switch for license information
        BoMResult=$(cyclonedx-py -r -i requirements.txt -o bom.xml)
        ;;

    "golang")
        echo "[*] Go version: $(go version)"

        echo "[*]  Processing Go SBOM..."
        
        # Install cyclonedx-gomod module to generate SBOM. Use main branch for now
        go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest
        
        path="bom.xml"
        # TODO: make licenses configurable
        BoMResult=$(cyclonedx-gomod mod -licenses=true -type library -output bom.xml)
        ;;
    *)
        "[-] Project type not supported: $LANGUAGE"

        #exit 1
        ;;
esac

baseline_project=$(curl $INSECURE $VERBOSE -s --location --request GET -G "$DTRACK_URL/api/v1/metrics/project/$PROJECT_UUID/current" \
    --header "X-Api-Key: $DTRACK_KEY")

echo "[*] SBOM file succesfully generated"

# UPLOAD SBOM to Dependency track server
# TODO: Note autoCreate requires appropriate permissions and create variable

echo "[*] Uploading SBOM to Dependency Track server..."

upload_bom=$(curl $INSECURE $VERBOSE -s --location --request POST $DTRACK_URL/api/v1/bom \
--header "X-Api-Key: $DTRACK_KEY" \
--header "Content-Type: multipart/form-data" \
--form "autoCreate=true" \
--form "projectName=$GITHUB_REPOSITORY" \
--form "projectVersion=$GITHUB_BASE_REF" \
--form "bom=@bom.xml")

token=$(echo $upload_bom | jq ".token" | tr -d "\"")

echo "[*] SBOM succesfully uploaded with token $token"

if [ -z $token ]; then
    echo "[-]  The SBOM has not been successfully processed by OWASP Dependency Track. Pop smoke!"
    exit 1
fi

echo "[*] Checking SBOM processing status"

processing=$(curl $INSECURE $VERBOSE -s --location --request GET $DTRACK_URL/api/v1/bom/token/$token \
--header "X-Api-Key: $DTRACK_KEY" | jq '.processing')

while [ $processing = true ]; do
    sleep 5
    processing=$(curl $INSECURE $VERBOSE -s --location --request GET $DTRACK_URL/api/v1/bom/token/$token \
--header "X-Api-Key: $DTRACK_KEY" | jq '.processing')
    if [ $((++c)) -eq 50 ]; then
        echo "[-]  Timeout while waiting for processing result. Please check the Dependency Track status."
        exit 1
    fi
done

echo "[*] Dependency Track processing completed!"

echo "[*] Retrieving project information"
project=$(curl $INSECURE $VERBOSE -s --location --request GET "$DTRACK_URL/api/v1/project/lookup?name=$GITHUB_REPOSITORY&version=$GITHUB_BASE_REF" \
--header "X-Api-Key: $DTRACK_KEY")
