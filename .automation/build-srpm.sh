#!/bin/bash -xe

# Either a branch name or a specific tag
ENGINE_VERSION="master"

# Directory, where build artifacts will be stored, should be passed as the 1st parameter
ARTIFACTS_DIR=${1:-exported-artifacts}

# Directory of the local maven repo
LOCAL_MAVEN_REPO="$(pwd)/repository"


[ -d ${ARTIFACTS_DIR} ] || mkdir -p ${ARTIFACTS_DIR}
[ -d rpmbuild/SOURCES ] || mkdir -p rpmbuild/SOURCES

# Fetch required engine version
git clone https://github.com/oVirt/ovirt-engine
cd ovirt-engine
git checkout ${ENGINE_VERSION}

# Prepare the version string (with support for SNAPSHOT versioning)
GIT_HASH=$(git rev-list HEAD | wc -l)
VERSION=$(mvn help:evaluate  -q -DforceStdout -Dexpression=project.version)
VERSION=${VERSION/-SNAPSHOT/-0.${GIT_HASH}.$(date +%04Y%02m%02d%02H%02M)}
IFS='-' read -ra VERSION <<< "$VERSION"
RELEASE=${VERSION[1]-1}

# Build engine project to download all dependencies to the local maven repo
mvn \
    clean \
    install \
    -P gwt-admin \
    --no-transfer-progress \
    -Dgwt.userAgent=gecko1_8 \
    -Dgwt.compiler.localWorkers=1 \
    -Dgwt.jvmArgs='-Xms1G -Xmx3G' \
    -Dmaven.repo.local=${LOCAL_MAVEN_REPO}

# Archive the fetched repository without artifacts produced as a part of engine build
cd ${LOCAL_MAVEN_REPO}/..

rm -rf repository/org/ovirt/engine/api/common-parent
rm -rf repository/org/ovirt/engine/api/interface
rm -rf repository/org/ovirt/engine/api/interface-common-jaxrs
rm -rf repository/org/ovirt/engine/api/restapi-apidoc
rm -rf repository/org/ovirt/engine/api/restapi-definition
rm -rf repository/org/ovirt/engine/api/restapi-jaxrs
rm -rf repository/org/ovirt/engine/api/restapi-parent
rm -rf repository/org/ovirt/engine/api/restapi-types
rm -rf repository/org/ovirt/engine/api/restapi-webapp
rm -rf repository/org/ovirt/engine/build-tools-root
rm -rf repository/org/ovirt/engine/checkstyles
rm -rf repository/org/ovirt/engine/core
rm -rf repository/org/ovirt/engine/engine-server-ear
rm -rf repository/org/ovirt/engine/extension
rm -rf repository/org/ovirt/engine/make
rm -rf repository/org/ovirt/engine/ovirt-checkstyle-extension
rm -rf repository/org/ovirt/engine/ovirt-findbugs-filters
rm -rf repository/org/ovirt/engine/root
rm -rf repository/org/ovirt/engine/ui

tar czf rpmbuild/SOURCES/ovirt-engine-build-dependencies-$VERSION.tar.gz repository

# Set version and release
sed \
    -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@RELEASE@|${RELEASE}|g" \
    < ovirt-engine-build-dependencies.spec.in \
    > ovirt-engine-build-dependencies.spec

# Build source package
rpmbuild \
    -D "_topdir rpmbuild" \
    -bs ovirt-engine-build-dependencies.spec
