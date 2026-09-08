#!/usr/bin/env bash

ASSET_ALLOWLIST=(
  'Localization/zh-CN/game.json'
  'Localization/zh-Hans/game.json'
  'Localization/en/game.json'
  'DataTable/Inventory/DT_ItemType.json'
  'DataTable/Inventory/DT_ItemConfig.json'
  'DataTable/Inventory/DT_CapitalItemConfig.json'
  'DataTable/Fork/DT_ForkItemData.json'
  'DataTable/Fork/DT_ForkLotteryPoolData.json'
  'DataTable/Character/DT_Character.json'
  'DataTable/Character/Appearance/DT_AppearanceData.json'
  'DataTable/Vehicle/DT_VehicleData.json'
  'DataTable/Vehicle/DT_vehicleModuleData.json'
  'DataTable/CombatAward/DT_CombatAwardEntranceConfig.json'
  'DataTable/Drop/Client/ClientDropGroupDataTable.json'
  'DataTable/Drop/DropSequenceDataTable.json'
  'DataTable/Monopoly/DT_MonopolyCellDataTable.json'
  'DataTable/Gacha/GachaIllustrate.json'
  'DataTable/Gacha/DT_LotteryDataTable*.json'
)

asset_is_allowlisted() {
  local path="$1"
  local pattern
  for pattern in "${ASSET_ALLOWLIST[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$path" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}
