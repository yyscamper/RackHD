#!/bin/bash
#
# this script iterates through all submodules in RackHD and sets up a
# dev installation with symbolic links, and uses the branches exaclty
# where you have them checked out, rather than from a checked in branch
# in github.
#
# The intention is that you can experiment more easily with changes in
# on-core or on-tasks without having to manipulate the package.json
# in the individual applications to point to one or more relevant branches.

# enable to fail on errors in script or failure to run any command
#set -e
# enable to see script debug output
#set -x

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

# because of dependencies, need to do this in three "waves"
# on-core
#   on-tasks
#     everything else

# first wave, just install on-core
pushd "${SCRIPT_DIR}/../on-core"
npm install --production
popd

# second wave, symlink in on-core
pushd "${SCRIPT_DIR}/../on-tasks"
# if the link or directory exists already, remove it
# if node_modules doesn't exist yet, create it
if [ ! -d "${SCRIPT_DIR}/../on-tasks/node_modules" ]; then
    mkdir ${SCRIPT_DIR}/../on-tasks/node_modules
fi
npm install
# replace on-core with a symbolic link
if [ -d "${SCRIPT_DIR}/../on-tasks/node_modules/on-core" ]; then
    rm -rf "${SCRIPT_DIR}/../on-tasks/node_modules/on-core"
    ln -s "${SCRIPT_DIR}/../on-core" ./node_modules
fi
popd

# third wave, symlink in on-core and on-tasks

REPOS="on-dhcp-proxy on-http on-statsd on-syslog on-tftp on-taskgraph"
for repo in ${REPOS}; do
    pushd "${SCRIPT_DIR}/../${repo}"
    npm install
    #
    # replace on-core with a symbolic link (if it exists)
    if [ -d "${SCRIPT_DIR}/../${repo}/node_modules/on-core" ]; then
        rm -rf "${SCRIPT_DIR}/../${repo}/node_modules/on-core"
        ln -s "${SCRIPT_DIR}/../on-core" ./node_modules
    fi
    # replace on-tasks with a symbolic link (if it exists)
    if [ -d "${SCRIPT_DIR}/../${repo}/node_modules/on-tasks" ]; then
        rm -rf "${SCRIPT_DIR}/../${repo}/node_modules/on-tasks"
        ln -s "${SCRIPT_DIR}/../on-tasks" ./node_modules
    fi
    popd
done

# last set, generate documentation
pushd "${SCRIPT_DIR}/../on-http"
    npm run apidoc
    ./install-swagger-ui.sh
    ./install-web-ui.sh
    git clone --branch v2.1.5 https://github.com/swagger-api/swagger-codegen.git
    pushd ./swagger-codegen && mvn package && popd
    java -jar ./swagger-codegen/modules/swagger-codegen-cli/target/swagger-codegen-cli.jar generate -i static/monorail.yml -o on-http-api1.1 -l python --additional-properties packageName=on_http_api1_1
    java -jar ./swagger-codegen/modules/swagger-codegen-cli/target/swagger-codegen-cli.jar generate -i static/monorail-2.0.yaml -o on-http-api2.0 -l python --additional-properties packageName=on_http_api2_0
    java -jar ./swagger-codegen/modules/swagger-codegen-cli/target/swagger-codegen-cli.jar generate -i static/redfish.yaml -o on-http-redfish-1.0 -l python --additional-properties packageName=on_http_redfish_1_0
popd

