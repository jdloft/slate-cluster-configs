STATSD_HOST="localhost"
STATSD_PORT="${if (cfg.statsdExporter == "node") then (toString cfgExporters.statsdPort) else (toString cfg.netdataStatsdPort)}"
MAGIC="${if cfg.useTestnetMagic then "--testnet-magic ${toString cfg.testnetMagicNumber}" else "--mainnet"}"
OPCERT="${cfg.opcertFile}"
# Default decoded metric settings in case they are not obtainable
CERT_ISSUE_NUM="-1"
KES_CREATED_PERIOD="-1"
# Default genesis metric settings in case they are not obtainable
ACTIVE_SLOTS_COEFF="-1"
EPOCH_LENGTH="-1"
MAX_KES_EVOLUTIONS="-1"
SECURITY_PARAM="-1"
SLOTS_PER_KES_PERIOD="-1"
SLOT_LENGTH="-1"
# Default protocol metric settings in case they are not obtainable
A_0="-1"
DECENTRALISATION_PARAM="-1"
E_MAX="-1"
KEY_DECAY_RATE="-1"
KEY_DEPOSIT="-1"
KEY_MIN_REFUND="-1"
MAX_BLOCK_BODY_SIZE="-1"
MAX_BLOCK_HEADER_SIZE="-1"
MAX_TX_SIZE="-1"
MIN_FEE_A="-1"
MIN_FEE_B="-1"
MIN_UTXO_VALUE="-1"
N_OPT="-1"
POOL_DECAY_RATE="-1"
POOL_DEPOSIT="-1"
POOL_MIN_REFUND="-1"
PROTOCOL_VERSION_MINOR="-1"
PROTOCOL_VERSION_MAJOR="-1"
RHO="-1"
TAU="-1"
# Default protocol and era metrics
IS_BYRON="-1"
IS_SHELLEY="-1"
IS_CARDANO="-1"
LAST_KNOWN_BLOCK_VERSION_MAJOR="-1"
LAST_KNOWN_BLOCK_VERSION_MINOR="-1"
LAST_KNOWN_BLOCK_VERSION_ALT="-1"
# Default cardano-cli versioning
CARDANO_CLI_VERSION_MAJOR="-1"
CARDANO_CLI_VERSION_MINOR="-1"
CARDANO_CLI_VERSION_PATCH="-1"
statsd() {
  local UDP="-u" ALL="''${*}"
  echo "Pushing statsd metrics to port: $STATSD_PORT; udp=$UDP"
  # If the string length of all parameters given is above 1000, use TCP
  [ "''${#ALL}" -gt 1000 ] && UDP=
  while [ -n "''${1}" ]; do
    printf "%s\n" "''${1}"
    shift
  done | ncat "''${UDP}" --send-only ''${STATSD_HOST} ''${STATSD_PORT} || return 1
  return 0
}
protocol_params() {
  BASE_CMD="cardano-cli query protocol-parameters $MAGIC"
  for era in shelley allegra mary; do
    OUTPUT=$($BASE_CMD --$era-era 2>/dev/null)
    if [ $? -eq 0 ]; then
      echo $OUTPUT
      return 0
    fi
  done
  return 1
}
# main
#
if VERSION_OUTPUT=$(cardano-cli version); then
  VERSION=$(echo $VERSION_OUTPUT | head -n 1 | cut -f 2 -d " ")
  CARDANO_CLI_VERSION_MAJOR=$(echo $VERSION | cut -f 1 -d ".")
  CARDANO_CLI_VERSION_MINOR=$(echo $VERSION | cut -f 2 -d ".")
  CARDANO_CLI_VERSION_PATCH=$(echo $VERSION | cut -f 3 -d ".")
fi
if CONFIG=$(pgrep -a cardano-node | grep -oP ".*--config \K.*\.json"); then
  echo "Cardano node config file is: $CONFIG"
  PROTOCOL=$(jq -r '.Protocol' < "$CONFIG")
  LAST_KNOWN_BLOCK_VERSION_MAJOR=$(jq -r '."LastKnownBlockVersion-Major"'  < "$CONFIG")
  LAST_KNOWN_BLOCK_VERSION_MINOR=$(jq -r '."LastKnownBlockVersion-Minor"'  < "$CONFIG")
  LAST_KNOWN_BLOCK_VERSION_ALT=$(jq -r '."LastKnownBlockVersion-Alt"'  < "$CONFIG")
  if [ "$PROTOCOL" = "Cardano" ]; then
    IS_CARDANO="1"
    GENESIS=$(jq -r '.ShelleyGenesisFile' < "$CONFIG")
    MODE="--cardano-mode"
    if protocol_params; then
      IS_SHELLEY="1"
      IS_BYRON="0"
    else
      IS_SHELLEY="0"
      IS_BYRON="1"
    fi
  elif [ "$PROTOCOL" = "TPraos" ]; then
    IS_SHELLEY="1"
    IS_CARDANO="0"
    GENESIS=$(jq -r '.GenesisFile' < "$CONFIG")
    MODE="--shelley-mode"
  elif [ "$PROTOCOL" = "RealPBFT" ]; then
    echo "Byron era not supported" && exit 1
  else
    echo "Unknown protocol: $PROTOCOL" && exit 1
  fi
  echo "Cardano node shelley genesis file is: $GENESIS"
  if [ -f "$GENESIS" ]; then
    if [ "$IS_SHELLEY" = "1" ]; then
      ACTIVE_SLOTS_COEFF=$(jq '.activeSlotsCoeff' < "$GENESIS")
    else
      ACTIVE_SLOTS_COEFF="1"
    fi
    EPOCH_LENGTH=$(jq '.epochLength' < "$GENESIS")
    SLOTS_PER_KES_PERIOD=$(jq '.slotsPerKESPeriod' < "$GENESIS")
    SLOT_LENGTH=$(jq '.slotLength' < "$GENESIS")
    MAX_KES_EVOLUTIONS=$(jq '.maxKESEvolutions' < "$GENESIS")
    SECURITY_PARAM=$(jq '.securityParam' < "$GENESIS")
  fi
fi
if [ -f "$OPCERT" ]; then
  echo "Cardano node opcert file is: $OPCERT"
  DECODED=$(cardano-cli text-view decode-cbor --in-file "$OPCERT")
  CERT_ISSUE_NUM=$(sed '7q;d' <<< "$DECODED" | awk -F '[()]' '{print $2}')
  KES_CREATED_PERIOD=$(sed '8q;d' <<< "$DECODED" | awk -F '[()]' '{print $2}')
fi
if PROTOCOL_CONFIG=$(protocol_params); then
  A_0=$(jq '.a0' <<< "$PROTOCOL_CONFIG")
  DECENTRALISATION_PARAM=$(jq '.decentralisationParam' <<< "$PROTOCOL_CONFIG")
  E_MAX=$(jq '.eMax' <<< "$PROTOCOL_CONFIG")
  KEY_DECAY_RATE=$(jq '.keyDecayRate' <<< "$PROTOCOL_CONFIG")
  KEY_DEPOSIT=$(jq '.keyDeposit' <<< "$PROTOCOL_CONFIG")
  KEY_MIN_REFUND=$(jq '.keyMinRefund' <<< "$PROTOCOL_CONFIG")
  MAX_BLOCK_BODY_SIZE=$(jq '.maxBlockBodySize' <<< "$PROTOCOL_CONFIG")
  MAX_BLOCK_HEADER_SIZE=$(jq '.maxBlockHeaderSize' <<< "$PROTOCOL_CONFIG")
  MAX_TX_SIZE=$(jq '.maxTxSize' <<< "$PROTOCOL_CONFIG")
  MIN_FEE_A=$(jq '.minFeeA' <<< "$PROTOCOL_CONFIG")
  MIN_FEE_B=$(jq '.minFeeB' <<< "$PROTOCOL_CONFIG")
  MIN_UTXO_VALUE=$(jq '.minUTxOValue' <<< "$PROTOCOL_CONFIG")
  N_OPT=$(jq '.nOpt' <<< "$PROTOCOL_CONFIG")
  POOL_DECAY_RATE=$(jq '.poolDecayRate' <<< "$PROTOCOL_CONFIG")
  POOL_DEPOSIT=$(jq '.poolDeposit' <<< "$PROTOCOL_CONFIG")
  POOL_MIN_REFUND=$(jq '.poolMinRefund' <<< "$PROTOCOL_CONFIG")
  PROTOCOL_VERSION_MINOR=$(jq '.protocolVersion.minor' <<< "$PROTOCOL_CONFIG")
  PROTOCOL_VERSION_MAJOR=$(jq '.protocolVersion.major' <<< "$PROTOCOL_CONFIG")
  RHO=$(jq '.rho' <<< "$PROTOCOL_CONFIG")
  TAU=$(jq '.tau' <<< "$PROTOCOL_CONFIG")
fi
echo "cardano_node_decode_certIssueNum:''${CERT_ISSUE_NUM}|g"
echo "cardano_node_decode_kesCreatedPeriod:''${KES_CREATED_PERIOD}|g"
echo "cardano_node_genesis_activeSlotsCoeff:''${ACTIVE_SLOTS_COEFF}|g"
echo "cardano_node_genesis_epochLength:''${EPOCH_LENGTH}|g"
echo "cardano_node_genesis_maxKESEvolutions:''${MAX_KES_EVOLUTIONS}|g"
echo "cardano_node_genesis_securityParam:''${SECURITY_PARAM}|g"
echo "cardano_node_genesis_slotLength:''${SLOT_LENGTH}|g"
echo "cardano_node_genesis_slotsPerKESPeriod:''${SLOTS_PER_KES_PERIOD}|g"
echo "cardano_node_protocol_a0:''${A_0}|g"
echo "cardano_node_protocol_decentralisationParam:''${DECENTRALISATION_PARAM}|g"
echo "cardano_node_protocol_eMax:''${E_MAX}|g"
echo "cardano_node_protocol_keyDecayRate:''${KEY_DECAY_RATE}|g"
echo "cardano_node_protocol_keyDeposit:''${KEY_DEPOSIT}|g"
echo "cardano_node_protocol_keyMinRefund:''${KEY_MIN_REFUND}|g"
echo "cardano_node_protocol_maxBlockBodySize:''${MAX_BLOCK_BODY_SIZE}|g"
echo "cardano_node_protocol_maxBlockHeaderSize:''${MAX_BLOCK_HEADER_SIZE}|g"
echo "cardano_node_protocol_maxTxSize:''${MAX_TX_SIZE}|g"
echo "cardano_node_protocol_minFeeA:''${MIN_FEE_A}|g"
echo "cardano_node_protocol_minFeeB:''${MIN_FEE_B}|g"
echo "cardano_node_protocol_minUTxOValue:''${MIN_UTXO_VALUE}|g"
echo "cardano_node_protocol_nOpt:''${N_OPT}|g"
echo "cardano_node_protocol_poolDecayRate:''${POOL_DECAY_RATE}|g"
echo "cardano_node_protocol_poolDeposit:''${POOL_DEPOSIT}|g"
echo "cardano_node_protocol_poolMinRefund:''${POOL_MIN_REFUND}|g"
echo "cardano_node_protocol_protocolVersion_minor:''${PROTOCOL_VERSION_MINOR}|g"
echo "cardano_node_protocol_protocolVersion_major:''${PROTOCOL_VERSION_MAJOR}|g"
echo "cardano_node_protocol_rho:''${RHO}|g"
echo "cardano_node_protocol_tau:''${TAU}|g"
echo "cardano_node_config_isByron:''${IS_BYRON}|g"
echo "cardano_node_config_isShelley:''${IS_SHELLEY}|g"
echo "cardano_node_config_isCardano:''${IS_CARDANO}|g"
echo "cardano_node_config_lastKnownBlockVersionMajor:''${LAST_KNOWN_BLOCK_VERSION_MAJOR}|g"
echo "cardano_node_config_lastKnownBlockVersionMinor:''${LAST_KNOWN_BLOCK_VERSION_MINOR}|g"
echo "cardano_node_config_lastKnownBlockVersionAlt:''${LAST_KNOWN_BLOCK_VERSION_ALT}|g"
echo "cardano_node_cli_version_major:''${CARDANO_CLI_VERSION_MAJOR}|g"
echo "cardano_node_cli_version_minor:''${CARDANO_CLI_VERSION_MINOR}|g"
echo "cardano_node_cli_version_patch:''${CARDANO_CLI_VERSION_PATCH}|g"
statsd \
  "cardano_node_decode_certIssueNum:''${CERT_ISSUE_NUM}|g" \
  "cardano_node_decode_kesCreatedPeriod:''${KES_CREATED_PERIOD}|g" \
  "cardano_node_genesis_activeSlotsCoeff:''${ACTIVE_SLOTS_COEFF}|g" \
  "cardano_node_genesis_epochLength:''${EPOCH_LENGTH}|g" \
  "cardano_node_genesis_maxKESEvolutions:''${MAX_KES_EVOLUTIONS}|g" \
  "cardano_node_genesis_securityParam:''${SECURITY_PARAM}|g" \
  "cardano_node_genesis_slotLength:''${SLOT_LENGTH}|g" \
  "cardano_node_genesis_slotsPerKESPeriod:''${SLOTS_PER_KES_PERIOD}|g"
statsd \
  "cardano_node_protocol_a0:''${A_0}|g" \
  "cardano_node_protocol_decentralisationParam:''${DECENTRALISATION_PARAM}|g" \
  "cardano_node_protocol_eMax:''${E_MAX}|g" \
  "cardano_node_protocol_keyDecayRate:''${KEY_DECAY_RATE}|g" \
  "cardano_node_protocol_keyDeposit:''${KEY_DEPOSIT}|g" \
  "cardano_node_protocol_keyMinRefund:''${KEY_MIN_REFUND}|g" \
  "cardano_node_protocol_maxBlockBodySize:''${MAX_BLOCK_BODY_SIZE}|g" \
  "cardano_node_protocol_maxBlockHeaderSize:''${MAX_BLOCK_HEADER_SIZE}|g" \
  "cardano_node_protocol_maxTxSize:''${MAX_TX_SIZE}|g" \
  "cardano_node_protocol_minFeeA:''${MIN_FEE_A}|g" \
  "cardano_node_protocol_minFeeB:''${MIN_FEE_B}|g"
statsd \
  "cardano_node_protocol_minUTxOValue:''${MIN_UTXO_VALUE}|g" \
  "cardano_node_protocol_nOpt:''${N_OPT}|g" \
  "cardano_node_protocol_poolDecayRate:''${POOL_DECAY_RATE}|g" \
  "cardano_node_protocol_poolDeposit:''${POOL_DEPOSIT}|g" \
  "cardano_node_protocol_poolMinRefund:''${POOL_MIN_REFUND}|g" \
  "cardano_node_protocol_protocolVersion_minor:''${PROTOCOL_VERSION_MINOR}|g" \
  "cardano_node_protocol_protocolVersion_major:''${PROTOCOL_VERSION_MAJOR}|g" \
  "cardano_node_protocol_rho:''${RHO}|g" \
  "cardano_node_protocol_tau:''${TAU}|g"
statsd \
  "cardano_node_config_isByron:''${IS_BYRON}|g" \
  "cardano_node_config_isShelley:''${IS_SHELLEY}|g" \
  "cardano_node_config_isCardano:''${IS_CARDANO}|g" \
  "cardano_node_config_lastKnownBlockVersionMajor:''${LAST_KNOWN_BLOCK_VERSION_MAJOR}|g" \
  "cardano_node_config_lastKnownBlockVersionMinor:''${LAST_KNOWN_BLOCK_VERSION_MINOR}|g" \
  "cardano_node_config_lastKnownBlockVersionAlt:''${LAST_KNOWN_BLOCK_VERSION_ALT}|g" \
  "cardano_node_cli_version_major:''${CARDANO_CLI_VERSION_MAJOR}|g" \
  "cardano_node_cli_version_minor:''${CARDANO_CLI_VERSION_MINOR}|g" \
  "cardano_node_cli_version_patch:''${CARDANO_CLI_VERSION_PATCH}|g"
