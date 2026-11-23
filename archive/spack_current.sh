#! /bin/bash
#
# print the hash of the current preferred install of a package
#
# $1 the spack package
#
PKG="$1"
if [ ! "$PKG" ]; then
    echo "spack_current_hash_no_package"
    exit 1
fi
[ "$PKG" == "black" ] && PKG=py-black
[ "$PKG" == "ruff" ] && PKG=py-ruff
[ "$PKG" == "uv" ] && PKG=py-uv
case "$PKG" in
    codetools) HASH=zkbjcf3;;
    git) HASH=q3orrja;;
    llvm) HASH=maysyfi;;
    muse) HASH=di7thnq;;
    postgresql) HASH=zavawja;;
    node-js) HASH=sgcv46q;;
    npm) HASH=5kcej7p;;
    qcachegrind) HASH=rubrnva;;
    py-ruff) HASH=vkkshgz;;
    py-black) HASH=7flghom;;
    py-uv) HASH=ugofxhe;;
esac
if [ "$HASH" ]; then
    echo "$PKG/$HASH"
    exit 0
else
    echo "spack_current_hash_pacakge_not_found"
    exit 1
fi
