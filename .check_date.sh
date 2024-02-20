#!/usr/bin/env bash
grep $(date -u -I) modpack.conf && grep $(date -u -I) inspector/mod.conf && grep $(date -u -I) replacer/mod.conf
exit $?
