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
org.assertj:assertj-core:3.27.3
org.junit.jupiter:junit-jupiter-api:5.13.4
org.junit.jupiter:junit-jupiter-engine:5.13.4
org.junit.jupiter:junit-jupiter-params:5.13.4
org.junit.platform:junit-platform-commons:1.13.4
org.junit.platform:junit-platform-engine:1.13.4
org.junit.platform:junit-platform-launcher:1.13.4
org.apache.maven.plugins:maven-dependency-plugin:3.8.1
org.apache.maven.plugins:maven-surefire-plugin:3.5.3
org.apache.maven.plugins:maven-war-plugin:3.4.0
org.codehaus.plexus:plexus-utils:1.1
com.ongres.stringprep:saslprep:1.1
com.ongres.stringprep:stringprep:1.1
com.ongres.scram:common:2.1
com.ongres.scram:client:2.1
commons-codec:commons-codec:1.17.1
commons-io:commons-io:2.16.1
org.apache.commons:commons-compress:1.27.1
org.apache.commons:commons-lang3:3.14.0
"

# Directory, where build artifacts will be stored, should be passed as the 1st parameter
ARTIFACTS_DIR=${1:-exported-artifacts}

# Directory of the local maven repo
LOCAL_MAVEN_REPO="$(pwd)/repository"


[ -d ${LOCAL_MAVEN_REPO} ] || mkdir -p ${LOCAL_MAVEN_REPO}
[ -d ${ARTIFACTS_DIR} ] || mkdir -p ${ARTIFACTS_DIR}
[ -d rpmbuild/SOURCES ] || mkdir -p rpmbuild/SOURCES

# Use java 21 for build
dnf install maven-openjdk21 -y

echo "--------------------------------"
mvn -version
java -version
echo "--------------------------------"

# Fetch required engine version
git clone --depth=1 --branch=${ENGINE_VERSION} https://github.com/oVirt/ovirt-engine
cd ovirt-engine

# Mark current directory as safe for git to be able to execute git commands
git config --global --add safe.directory $(pwd)

# Prepare the release, which contain git hash of engine commit and current date
PKG_RELEASE="0.$(date +%04Y%02m%02d%02H%02M).git$(git rev-parse --short HEAD)"
#PKG_RELEASE="1"

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

# Install additional dependencies
for dep in ${ADDITIONAL_DEPENDENCIES} ; do
    mvn dependency:get -Dartifact=${dep} -Dmaven.repo.local=${LOCAL_MAVEN_REPO}
done

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

tar czf rpmbuild/SOURCES/ovirt-engine-build-dependencies-${PKG_VERSION}.tar.gz repository

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
