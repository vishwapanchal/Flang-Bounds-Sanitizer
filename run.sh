#!/bin/bash
set -euo pipefail
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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
echo -e "${CYAN}[i] System Target: 12 Cores | 16GB RAM | Cached Profile${NC}"
echo "========================================================"

# Force Docker BuildKit to enable advanced persistent caching
export DOCKER_BUILDKIT=1

echo -e "${YELLOW}[*] Building Docker Image (Max Performance Mode)...${NC}"
docker build -t flang-bounds-sanitizer .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[*] Build Successful! Booting Demonstration Environment...${NC}"
    docker run --rm flang-bounds-sanitizer
else
    echo -e "\033[0;31m[!] Build failed or was interrupted.${NC}"
    echo -e "\033[0;32m[i] Don't worry! BuildKit Caching is enabled. Run './run.sh' again to resume instantly from where it stopped!${NC}"
    exit 1
fi
