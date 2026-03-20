#!/bin/bash

echo "Clean git repository..."

git clean -f -d

cd obtools

git clean -f -d

cd ..

echo "Cleaning up previous build-release and .tup.db..."
rm -rf build-release
rm -rf .tup.db

echo "Preparing build-release structure..."
obtools/build/init.sh -t release

echo "Generate tup script"
tup generate script.sh

echo "Executing tup...this will take a while..."
bash script.sh

tup

echo "Generating DEB packages..."

ROOT_FOLDER=$(pwd)


echo "Starting to search for DEBIAN directories from root folder: $ROOT_FOLDER"

find . -type d -name DEBIAN | while read -r dir; do
    echo "Found DEBIAN directory: $dir"
    
    cd "$dir"
    CURRENT_BUILD_ROOT="${dir#./}" 
    # remove DEBIAN from the end
    CURRENT_BUILD_PATH="${CURRENT_BUILD_ROOT%/DEBIAN}"
    echo "CURRENT_BUILD_PATH =  $CURRENT_BUILD_PATH"
    #ls -l
    NR_NESTED_DIRS=$(awk -F'/' '{print NF}' <<< "$CURRENT_BUILD_PATH")

    # If there's no slash, awk still returns 1 — but to be safe:
    if [[ "$CURRENT_BUILD_PATH" != *"/"* ]]; then
        NR_NESTED_DIRS=1
    fi

    echo "NR_NESTED_DIRS =  $NR_NESTED_DIRS:"
    
    if [ ! -f control ]; then
        echo "Info: control file not found in $dir. Exiting loop."
        #break
    fi

    echo "Package folder: $CURRENT_BUILD_PATH"

    #cat control

    PACKAGE_NAME=$(grep '^Package:' control | awk '{print $2}')

    NESTED_DIRS=""
    for ((i=0; i<$NR_NESTED_DIRS; i++)); do
        NESTED_DIRS="../$NESTED_DIRS"
    done

    ##### Grab version and revision from package ########

    FILE="${PWD%/DEBIAN}/Tupfile"

    echo "DEBUG: FILE='$FILE'"
    ls -l "$FILE"

    # Read key/value pairs, stripping spaces
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)       # trim whitespace
        value=$(echo "$value" | xargs)   # trim whitespace

        case "$key" in
            VERSION)  VERSION="$value" ;;
            REVISION) REVISION="$value" ;;
        esac
    done < "$FILE"

    echo "VERSION:  $VERSION"
    echo "REVISION: $REVISION"
    ##############################################################

    PACKAGE=${PACKAGE_NAME}_${VERSION}-${REVISION}.deb

    mkdir -p "${NESTED_DIRS}/build-release/${CURRENT_BUILD_PATH}"

    OUTPUT_FILE="${NESTED_DIRS}/build-release/${CURRENT_BUILD_PATH}/${PACKAGE}"

    echo "Calling create-deb.sh with OUTPUT_FILE=$OUTPUT_FILE"

    cd ..
    bash ${ROOT_FOLDER}/create-deb.sh ${VERSION} ${REVISION} "$PACKAGE_NAME" "${OUTPUT_FILE}"

    cd "$ROOT_FOLDER"
done


