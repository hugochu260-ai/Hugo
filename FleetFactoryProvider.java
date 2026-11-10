import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Registry of fleet factories.
 * <p>
 * The create-fleet command asks this provider for a factory by the type code
 * the user typed. Registration order is the order shown in the type prompt.
 * A new fleet type is added by registering another {@link FleetComponentFactory};
 * the command classes do not change.
 * </p>
 */
public class FleetFactoryProvider {

    private final Map<String, FleetComponentFactory> factories =
            new LinkedHashMap<String, FleetComponentFactory>();

    public void register(FleetComponentFactory factory) {
        factories.put(factory.getTypeCode().toLowerCase(), factory);
    }

    public FleetComponentFactory getFactory(String typeCode) {
        if (typeCode == null) {
            return null;
        }
        return factories.get(typeCode.toLowerCase());
    }

    public FleetComponentFactory getFactoryForFleet(VehicleFleet fleet) {
        if (fleet == null) {
            return null;
        }
        return getFactory(fleet.getTypeCode());
    }

    /**
     * Builds the type prompt from the registered factories so the menu stays
     * aligned with the factories that can actually create a fleet.
     */
    public String buildTypePrompt() {
        StringBuilder builder = new StringBuilder("Enter fleet type (");
        boolean first = true;
        for (FleetComponentFactory factory : factories.values()) {
            if (!first) {
                builder.append(" | ");
            }
            first = false;
            builder.append(factory.getTypeCode());
            builder.append(" = ");
            builder.append(factory.getTypeLabel());
        }
        builder.append(") :- ");
        return builder.toString();
    }
}
