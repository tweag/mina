#!/bin/bash

# This script makes a .deb archive for the Mina Archive process
# and releases it to the AWS .deb repository packages.o1test.net

set -euo pipefail

# Set up variables for build
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../.."

source "buildkite/scripts/export-git-env-vars.sh"

cd _build

PROJECT="mina-archive"
BUILD_DIR="deb_build"

###### archiver deb

mkdir -p "${BUILD_DIR}/DEBIAN"
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PROJECT}
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libjemalloc1, libgomp1, libssl1.1, libpq-dev
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Mina Archive Process
 Compatible with Mina Daemon
 Built from ${GIT_HASH} by ${BUILDKITE_BUILD_URL:-"Mina CI"}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILD_DIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILD_DIR}/usr/local/bin"
pwd
ls
cp ./_build/default/src/app/archive/archive.exe "${BUILD_DIR}/usr/local/bin/mina-archive"
cp ./_build/default/src/app/archive/archive.exe "${BUILD_DIR}/usr/local/bin/coda-archive"
cp ./_build/default/src/app/archive_blocks/archive_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-archive-blocks"
cp ./_build/default/src/app/extract_blocks/extract_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-extract-blocks"
cp ./_build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe "${BUILD_DIR}/usr/local/bin/mina-missing-blocks-auditor"
cp ./_build/default/src/app/replayer/replayer.exe "${BUILD_DIR}/usr/local/bin/mina-replayer"
cp ./_build/default/src/app/swap_bad_balances/swap_bad_balances.exe "${BUILD_DIR}/usr/local/bin/mina-swap-bad-balances"
chmod --recursive +rx "${BUILD_DIR}/usr/local/bin"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}_${VERSION}.deb
ls -lh mina*.deb

###### archiver deb with testnet signatures

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/DEBIAN"
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PROJECT}-devnet
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libjemalloc1, libgomp1, libssl1.1, libpq-dev
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Mina Archive Process
 Compatible with Mina Daemon
 Built from ${GIT_HASH} by ${BUILDKITE_BUILD_URL:-"Mina CI"}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILD_DIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILD_DIR}/usr/local/bin"
pwd
ls
cp ./_build/default/src/app/archive/archive_testnet_signatures.exe "${BUILD_DIR}/usr/local/bin/mina-archive"
cp ./_build/default/src/app/archive/archive_testnet_signatures.exe "${BUILD_DIR}/usr/local/bin/coda-archive"
cp ./_build/default/src/app/archive_blocks/archive_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-archive-blocks"
cp ./_build/default/src/app/extract_blocks/extract_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-extract-blocks"
cp ./_build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe "${BUILD_DIR}/usr/local/bin/mina-missing-blocks-auditor"
cp ./_build/default/src/app/replayer/replayer.exe "${BUILD_DIR}/usr/local/bin/mina-replayer"
cp ./_build/default/src/app/swap_bad_balances/swap_bad_balances.exe "${BUILD_DIR}/usr/local/bin/mina-swap-bad-balances"
chmod --recursive +rx "${BUILD_DIR}/usr/local/bin"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}-devnet_${VERSION}.deb
ls -lh mina*.deb

###### archiver deb with mainnet signatures

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/DEBIAN"
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PROJECT}-mainnet
Version: ${VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends: libjemalloc1, libgomp1, libssl1.1, libpq-dev
License: Apache-2.0
Homepage: https://minaprotocol.com/
Maintainer: O(1)Labs <build@o1labs.org>
Description: Mina Archive Process
 Compatible with Mina Daemon
 Built from ${GIT_HASH} by ${BUILDKITE_BUILD_URL:-"Mina CI"}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILD_DIR}/DEBIAN/control"

echo "------------------------------------------------------------"
# Binaries
mkdir -p "${BUILD_DIR}/usr/local/bin"
pwd
ls
cp ./_build/default/src/app/archive/archive_mainnet_signatures.exe "${BUILD_DIR}/usr/local/bin/mina-archive"
cp ./_build/default/src/app/archive/archive_mainnet_signatures.exe "${BUILD_DIR}/usr/local/bin/coda-archive"
cp ./_build/default/src/app/archive_blocks/archive_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-archive-blocks"
cp ./_build/default/src/app/extract_blocks/extract_blocks.exe "${BUILD_DIR}/usr/local/bin/mina-extract-blocks"
cp ./_build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe "${BUILD_DIR}/usr/local/bin/mina-missing-blocks-auditor"
cp ./_build/default/src/app/replayer/replayer.exe "${BUILD_DIR}/usr/local/bin/mina-replayer"
cp ./_build/default/src/app/swap_bad_balances/swap_bad_balances.exe "${BUILD_DIR}/usr/local/bin/mina-swap-bad-balances"
chmod --recursive +rx "${BUILD_DIR}/usr/local/bin"

# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILD_DIR}"

# Build the package
echo "------------------------------------------------------------"
dpkg-deb --build "${BUILD_DIR}" ${PROJECT}-mainnet_${VERSION}.deb
ls -lh mina*.deb
