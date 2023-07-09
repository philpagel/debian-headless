#!/bin/sh -e
make download
make image
mv ./*-hl.iso /output
