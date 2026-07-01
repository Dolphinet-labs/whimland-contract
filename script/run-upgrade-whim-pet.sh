#!/usr/bin/env bash
# Upgrade all NFTManager proxies for WhimPet (petBurn + setPetSystem).
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-../Whimland-Frontend-user-mobile/.env.local}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ENV_FILE not found: $ENV_FILE" >&2
  exit 1
fi

read_key() {
  local var=$1
  local val
  val=$(grep "^${var}=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
  [[ "$val" != 0x* ]] && val="0x$val"
  echo "$val"
}

RPC_URL="${RPC_URL:-https://rpc.dolphinode.world}"
export WHIMPET_ADDR="${WHIMPET_ADDR:-0xFf66ebBEB2dA357b8f21E36c89340b5914dc7984}"
export NFT_IMPL_ADDR="${NFT_IMPL_ADDR:-0xe996AD9579C0EBbDE916A37F2381BB2099f5467E}"
export PROXIES_FILE="${PROXIES_FILE:-script/data/nft-manager-proxies-1520.txt}"

export PROXY_ADMIN_KEYS="$(read_key MASTER_MINT_SECRET),$(read_key 2247ckey),$(read_key contract_sequencer_key)"
export NFT_MANAGER_OWNER_KEY="$(read_key MASTER_MINT_SECRET)"
export PROXY_ADMIN_KEY="$NFT_MANAGER_OWNER_KEY"

if [[ -z "$PROXY_ADMIN_KEYS" || -z "$NFT_MANAGER_OWNER_KEY" ]]; then
  echo "Missing MASTER_MINT_SECRET / 2247ckey / contract_sequencer_key in $ENV_FILE" >&2
  exit 1
fi

forge script script/upgradeNFTManagersForWhimPet.s.sol:UpgradeNFTManagersForWhimPet \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --slow \
  -vvv
