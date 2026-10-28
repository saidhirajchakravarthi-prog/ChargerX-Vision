/// Composite identity for charger-owned component state.
///
/// Component IDs are only guaranteed to identify a component within a charger.
typedef ChargerComponentKey = ({String chargerKey, String componentId});

ChargerComponentKey chargerComponentKey(
  String chargerKey,
  String componentId,
) => (chargerKey: chargerKey, componentId: componentId);
