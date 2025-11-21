#!/bin/bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

_info() {
    echo -e "${BLUE}[INFO] $*${NC}"
}

_error() {
    echo -e "${RED}[ERROR] $*${NC}" >&2
}

_warning() {
    echo -e "${YELLOW}[WARNING] $*${NC}"
}

_success() {
    echo -e "${GREEN}[SUCCESS] $*${NC}"
}