#!/bin/bash -xe

# Package version is static and should be aligned with engine version that is
# used to build maven cache
PKG_VERSION="4.5.7"

# Either a branch name or a specific tag in ovirt-engine project for which
# the maven cache is built
ENGINE_VERSION="master"

# Additional dependencies, which are going to be added to engine and which need
# to be included in ovirt-engine-build-dependencies, so proper build can pass
ADDITIONAL_DEPENDENCIES="
com.puppycrawl.tools:checkstyle:10.20.0
io.bit3:jsass:5.11.1
"

# Directory, where build artifacts will be stored, should be passed as the 1st parameter
ARTIFACTS_DIR=${1:-exported-artifacts}

# Directory of the local maven repo
LOCAL_MAVEN_REPO="$(pwd)/repository"


[ -d ${LOCAL_MAVEN_REPO} ] || mkdir -p ${LOCAL_MAVEN_REPO}
[ -d ${ARTIFACTS_DIR} ] || mkdir -p ${ARTIFACTS_DIR}
[ -d rpmbuild/SOURCES ] || mkdir -p rpmbuild/SOURCES

# Fetch required engine version
git clone --depth=1 --branch=${ENGINE_VERSION} https://github.com/oVirt/ovirt-engine
cd ovirt-engine

# Mark current directory as safe for git to be able to execute git commands
git config --global --add safe.directory $(pwd)

# Prepare the release, which contain git hash of engine commit and current date
PKG_RELEASE="0.$(date +%04Y%02m%02d%02H%02M).git$(git rev-parse --short HEAD)"
#PKG_RELEASE="1"

# Set the location of the JDK that will be used for compilation:
export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-11}"

# Archive the fetched repository without artifacts produced as a part of engine build
cd ${LOCAL_MAVEN_REPO}/..

# Save additional deps in a file
echo ${ADDITIONAL_DEPENDENCIES} > ADDITIONAL_DEPENDENCIES

tar czf rpmbuild/SOURCES/ovirt-engine-build-dependencies-${PKG_VERSION}.tar.gz ADDITIONAL_DEPENDENCIES repository ovirt-engine

# Set version and release
sed \
    -e "s|@VERSION@|${PKG_VERSION}|g" \
    -e "s|@RELEASE@|${PKG_RELEASE}|g" \
    < ovirt-engine-build-dependencies.spec.in \
    > ovirt-engine-build-dependencies.spec

# Build source package
rpmbuild \
    -D "_topdir rpmbuild" \
    -bs ovirt-engine-build-dependencies.spec
