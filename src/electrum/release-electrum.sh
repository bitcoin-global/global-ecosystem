#!/bin/bash

### =================================================
### Global config
export ELECTRUM_VERSION=4.0.2
export BITCOIN_VERSION=0.19.2

### =================================================
### Install GHR
wget https://github.com/tcnksm/ghr/releases/download/v0.13.0/ghr_v0.13.0_linux_amd64.tar.gz -O ghr.tar.gz
tar xzf ghr.tar.gz
sudo mv ghr_v0.13.0_linux_amd64/ghr /usr/bin/ghr
rm -r ghr.tar.gz ghr_v0.13.0_linux_amd64/

### Configure GitHub authentication
export GITHUB_TOKEN=${GITHUB_TOKEN}
git config --global url."https://api:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
git config --global url."https://git:${GITHUB_TOKEN}@github.com/".insteadOf "git@github.com:"
git config --global user.name  "bitcoin-global-bot"
git config --global user.email "bot@bitcoin-global.io"

### =================================================
### Build releases
rm -rf ./electrum
git clone https://github.com/bitcoin-global/global-electrum.git ./electrum
cd electrum/
git tag -d $ELECTRUM_VERSION || echo "doesn't exist"
git tag $ELECTRUM_VERSION || echo "same tag"
git push -f --tags
git checkout $ELECTRUM_VERSION

### Images
docker build -t electrum-wine-builder-img       contrib/build-wine
docker build -t electrum-linux-builder-img      contrib/build-linux/sdist
# docker build -t electrum-android-builder-img    contrib/android

### Windows
docker run -it --rm \
    -v $PWD:/opt/wine64/drive_c/electrum \
    -w /opt/wine64/drive_c/electrum/contrib/build-wine \
    --name electrum-wine-builder-cont \
    electrum-wine-builder-img \
    ./build.sh

### Linux
docker run -it --rm \
    -v $PWD:/opt/wine64/drive_c/electrum \
    -w /opt/wine64/drive_c/electrum/contrib/build-linux/sdist \
    --name electrum-linux-builder-cont \
    electrum-linux-builder-img \
    ./build.sh

## ### Android
## ./contrib/pull_locale
## ./contrib/make_packages
## mkdir --parents /c/repos/global-electrum/.buildozer/.gradle
## docker run -it --rm \
##     --name electrum-android-builder-cont \
##     -v /c/repos/global-electrum:/home/user/wspace/electrum \
##     -v /c/repos/global-electrum/.buildozer/.gradle:/home/user/.gradle \
##     -v ~/.keystore:/home/user/.keystore \
##     --workdir /home/user/wspace/electrum \
##     electrum-android-builder-img \
##     ./contrib/android/make_apk

### =================================================
### Sign and publish

### Import keys
gpg --import ~/.gpg/public.key
gpg --import ~/.gpg/private.key
gpg --import ~/.gpg/sub.key

### Collect binaries
mv ./contrib/build-wine/signed/*-portable.exe ./dist/electrum-global-${ELECTRUM_VERSION}-portable.exe || echo "Already imported"
mv ./contrib/build-wine/signed/*-setup.exe ./dist/electrum-global-${ELECTRUM_VERSION}-setup.exe || echo "Already imported"
mv ./contrib/build-wine/signed/*.exe ./dist/electrum-global-${ELECTRUM_VERSION}.exe || echo "Already imported"
mv ./dist/*.tar.gz ./dist/electrum-global-${ELECTRUM_VERSION}.tar.gz || echo "Already imported"

### Sign
cd ./dist
shasum -a 256 electrum-global-* > SHA256SUMS
gpg2 --pinentry-mode loopback --yes --clearsign --output SHA256SUMS.asc --sign SHA256SUMS
rm -rf SHA256SUMS

############################################################################################
### Generate release report
FROM_COMMIT=$(git describe --tags --abbrev=0)
RELEASE_DATA=$(git log $FROM_COMMIT..HEAD --no-merges \
            --pretty=format:'* **[`%h`](https://github.com/bitcoin-global/global-electrum/commit/%H)**  %s' \
            -i -E --grep=".*: .*")
COMMITTERS=$(git log --format="* %an" $FROM_COMMIT..HEAD | sort | uniq | grep -i -E -v "bitcoin-global-bot" )
DATE=$(date '+%Y-%m-%d')

echo -e "## Release v$ELECTRUM_VERSION ($DATE)\n\n" > release.md
echo -e "### :globe_with_meridians: Getting started\n" >> release.md
echo -e "* [Getting started](https://bitcoin-global.io/#getting-started)" >> release.md
echo -e "* [Download Bitcoin Global](https://github.com/bitcoin-global/bitcoin-global/releases/tag/v$BITCOIN_VERSION)" >> release.md
echo -e "* [Download Electrum Global](https://github.com/bitcoin-global/global-electrum/releases/tag/v$ELECTRUM_VERSION)" >> release.md
echo -e "* [Requirements](https://bitcoin-global.io/#requirements)" >> release.md
echo -e "### :checkered_flag: Release notes:\n $RELEASE_DATA\n\n" >> release.md
echo -e "### :busts_in_silhouette: Committers:\n $COMMITTERS\n\n---" >> release.md
echo -e '### :link: Release hashes and signatures\n\n```gpg' >> release.md
cat ./SHA256SUMS.asc >> release.md
echo -e '```\n\nSigned by public key `DC17 1097 7C99 4CF2 DD8A 59DA 9791 24CB 5F7F BF39` (<fhivemind@users.noreply.github.com>)' >> release.md

### Publish
ghr -t ${GITHUB_TOKEN} -u bitcoin-global -r global-electrum -n v$ELECTRUM_VERSION -b "$(cat ./release.md)" -delete v$ELECTRUM_VERSION .
