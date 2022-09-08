#!/bin/bash -xe

# Either a branch name or a specific tag
ENGINE_VERSION="master"

# Directory, where build artifacts will be stored, should be passed as the 1st parameter
ARTIFACTS_DIR=${1:-exported-artifacts}

# Directory of the local maven repo
LOCAL_MAVEN_REPO="$(pwd)/repository"

# Fetch required engine version
git clone https://github.com/oVirt/ovirt-engine
cd ovirt-engine
git checkout ${ENGINE_VERSION}

# Load engine version and git commit hash
GIT_HASH=$(git rev-list HEAD | wc -l)

# Prepare the version string (with support for SNAPSHOT versioning)
VERSION=$(mvn help:evaluate  -q -DforceStdout -Dexpression=project.version)
VERSION=${VERSION/-SNAPSHOT/-0.${GIT_HASH}.$(date +%04Y%02m%02d%02H%02M)}
IFS='-' read -ra VERSION <<< "$VERSION"
RELEASE=${VERSION[1]-1}

# Build engine project to download all dependencies to the local maven repo
mvn clean package -P gwt-admin -Dgwt.userAgent=gecko1_8 -Dmaven.repo.local=${LOCAL_MAVEN_REPO}

# Archive the fetched repository
cd ${LOCAL_MAVEN_REPO}/..
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
