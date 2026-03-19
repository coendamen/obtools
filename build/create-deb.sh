#!/bin/bash

set -e

DISTRO=$(lsb_release -s -i)

VERSION=$1
REVISION=$2
NAME=$3
OUTPUT_FILE=$4

echo "create-deb.sh called with VERSION=$VERSION REVISION=$REVISION NAME=$NAME OUTPUT_FILE=$OUTPUT_FILE"


# Output dir must be absolute because we're about to cd
OUTPUT_DIR="$PWD/$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"
echo Build package in $PWD to $OUTPUT_DIR

# Copy both the source and current output to a temp dir and shift to that
TMPDIR=$(mktemp -d)/build
mkdir -p "$TMPDIR"

#chmod -R 777 $TMPDIR

SOURCE_DIR=$PWD

#CURRENT_USER=$(whoami)
#echo $0
#echo "---------- listing current contents in $CURRENT_FPDIR and user is $CURRENT_USER ---------"
#$ls -l DEBIAN

#echo "---------- listing current contents in $OUTPUT_DIR and user is $CURRENT_USER ---------"
#$ls -l $OUTPUT_DIR

cp -R . "$TMPDIR"
# Tup FUSE may create directories with restrictive permissions; fix them now
# while we are still outside the cd (TMPDIR is a real /tmp path)
chmod -R u+rwX "$TMPDIR"

#echo "---------- listing $TMPDIR/DEBIAN contents ---------"
#ls -l $TMPDIR/DEBIAN

# Copy output except for mocks and tests that might be built but not
# packaged (this is awfully specific but I can't see a way round it generally)
if find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 | read; then
  rsync --exclude="mocks" --exclude="tests" --exclude="modules" \
        "$OUTPUT_DIR"/ "$TMPDIR"
fi

cd $TMPDIR

DEBDIR=debian

CHANGELOG=$DEBDIR/changelog
COMPAT=$DEBDIR/compat
RULES=$DEBDIR/rules

CURRENT_FPDIR=$PWD
echo "current workdir is $CURRENT_FPDIR"
echo "---------- copying debian files to $DEBDIR  ---------"

rm -rf "$DEBDIR"
cp -a DEBIAN "$DEBDIR"

# Under Tup/FUSE, source DEBIAN files can appear as zero-byte placeholders.
# Fallback to host mount namespace path if control is empty.
if [ ! -s "$DEBDIR/control" ]; then
  ALT_DEBIAN="/proc/1/root$SOURCE_DIR/DEBIAN"
  if [ -f "$ALT_DEBIAN/control" ]; then
    rm -rf "$DEBDIR"
    cp -a "$ALT_DEBIAN" "$DEBDIR"
  fi
fi

chmod -R u+rwX,go+rX "$DEBDIR"
chmod -x debian/dirs || true
chmod -x debian/install || true

ls -l $DEBDIR

if [ ! -e $CHANGELOG ]
then
  cat << EOF > $DEBDIR/changelog
$NAME ($VERSION-$REVISION) stable; urgency=low

  * See documentation.

 -- ObTools support <support@obtools.com>  `date -R`
EOF
fi

if [ ! -e $COMPAT ]
then
  cat << EOF > $COMPAT
10
EOF
fi

if [ ! -e $RULES ]
then
  cat << 'EOF' > $RULES
#!/usr/bin/make -f

%:
	dh $@
EOF
  chmod a+x $DEBDIR/rules
fi

FAKEROOT=-rfakeroot-ng

[ -x /usr/bin/fakeroot ] && FAKEROOT=-r/usr/bin/fakeroot
[ -x /usr/local/bin/fakeroot ] && FAKEROOT=-r/usr/bin/local/fakeroot

if [ -f /usr/local/bin/pseudo ]; then
  export PSEUDO_PREFIX=/usr/local
  FAKEROOT=-rpseudo
fi

if [ `id -u` -eq 0 ]; then
  FAKEROOT=
fi

DEB_BUILD_OPTIONS=noautodbgsym  dpkg-buildpackage -uc -b $FAKEROOT -tc

PACKAGE=${NAME}_${VERSION}-${REVISION}_*.deb
mv $TMPDIR/../$PACKAGE "$OUTPUT_DIR"/

rm -rf "$TMPDIR"
