#!/bin/bash
# ==========================================================================
# Flang HLFIR Bounds Sanitizer — One-Click Build and Demo
#
# System Target: 6 Cores | 8GB RAM | Docker BuildKit Cached Profile
# ==========================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "  ███████╗██╗      █████╗ ███╗   ██╗ ██████╗ "
echo "  ██╔════╝██║     ██╔══██╗████╗  ██║██╔════╝ "
echo "  █████╗  ██║     ███████║██╔██╗ ██║██║  ███╗"
echo "  ██╔══╝  ██║     ██╔══██║██║╚██╗██║██║   ██║"
echo "  ██║     ███████╗██║  ██║██║ ╚████║╚██████╔╝"
echo "  ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ "
echo -e "${YELLOW}       HLFIR-Aware Array Bounds Sanitizer     ${NC}"
echo "========================================================"
echo -e "${CYAN}[i] System Target: 6 Cores | 8GB RAM | Cached Profile${NC}"
echo "========================================================"

export DOCKER_BUILDKIT=1

echo -e "${YELLOW}[*] Building Docker Image (Memory-Optimized Mode)...${NC}"
docker build --memory=7g --memory-swap=10g -t flang-bounds-sanitizer .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Build Successful. Starting demonstration...${NC}"
    docker run --rm flang-bounds-sanitizer
else
    echo -e "${RED}[!] Build failed or was interrupted.${NC}"
    echo -e "${GREEN}[i] BuildKit caching is enabled. Run './run.sh' again to resume from where it stopped.${NC}"
    exit 1
fi
