#!/bin/sh
export APPLICATION_URL="https://${OSC_HOSTNAME}"
/app/filestash "$@"
