#!/bin/bash

SRC=$1/subprojects/libapi/api
DEST=$1/vapi
LIB=$1/build/subprojects/libapi
DOC=$DEST/doc

g-ir-scanner ${SRC}/http.[ch] ${SRC}/util.[ch] ${SRC}/marshal.[ch] ${SRC}/mqtt.[ch] \
             ${SRC}/json.[ch] ${SRC}/thrift.[ch] ${SRC}/api.[ch] ${SRC}/internal.h ${SRC}/id.h \
            --no-libtool \
            -o Fb.gir \
            --library-path=$LIB \
            --library=com.github.aprilis.messenger.api \
            -lz \
            `pkg-config --libs gobject-2.0` \
            `pkg-config --libs glib-2.0` \
            `pkg-config --libs json-glib-1.0` \
            `pkg-config --libs libsoup-2.4` \
            --warn-all \
            `pkg-config --cflags gobject-2.0` \
            `pkg-config --cflags glib-2.0` \
            `pkg-config --cflags json-glib-1.0` \
            `pkg-config --cflags libsoup-2.4` \
            --include=GObject-2.0 \
            --include=GLib-2.0 \
            --include=Gio-2.0 \
            --include=Soup-2.4 \
            --include=Json-1.0 \
            -nFb \
            --nsversion=1.0
            
vapigen --pkg gobject-2.0 --pkg glib-2.0 --pkg gio-2.0 --pkg libsoup-2.4 --pkg json-glib-1.0 --library Fb Fb.gir --metadatadir ${SRC}/metadata
rm -rf $DOC
valadoc --pkg gobject-2.0 --pkg glib-2.0 --pkg gio-2.0 --pkg libsoup-2.4 --pkg json-glib-1.0 Fb.gir --metadatadir ${SRC}/metadata -o $DOC
mv Fb.vapi $DEST
rm Fb.gir