// Creates fleet objects. Role names, the created message and the display title live here.
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

public final class VehicleFleetFactory {

    public interface FleetType {

        String getTypeCode();

        String getTypeName();

        String getTypeTitle();

        String getCreatedMessage();

        String getRoleName(int role);

        boolean isValidRole(int role);

        VehicleFleet createFleet(String fleetID);
    }

    private LinkedHashMap<String, FleetType> types;
    private Map<VehicleFleet, FleetType> created;

    public VehicleFleetFactory() {
        types = new LinkedHashMap<String, FleetType>();
        created = new HashMap<VehicleFleet, FleetType>();
        register(new DeliveryVanType());
        register(new RefrigeratedTruckType());
    }

    public final void register(FleetType type) {
        types.put(type.getTypeCode(), type);
    }

    public FleetType getType(String typeCode) {
        if (typeCode == null) {
            return null;
        }
        return types.get(typeCode);
    }

    public VehicleFleet createFleet(FleetType type, String fleetID) {
        VehicleFleet fleet = type.createFleet(fleetID);
        created.put(fleet, type);
        return fleet;
    }

    public FleetType typeOf(VehicleFleet fleet) {
        if (fleet == null) {
            return null;
        }
        return created.get(fleet);
    }

    public String getSummary(VehicleFleet fleet) {
        FleetType type = typeOf(fleet);
        String title = type.getTypeTitle();
        return title + " " + fleet.getName() + " (" + fleet.getFleetID() + ")";
    }

    public String getTypePrompt() {
        StringBuilder prompt = new StringBuilder("Enter fleet type (");
        boolean first = true;
        for (FleetType type : types.values()) {
            if (!first) {
                prompt.append(" | ");
            }
            first = false;
            prompt.append(type.getTypeCode());
            prompt.append(" = ");
            prompt.append(type.getTypeName());
        }
        prompt.append(") :- ");
        return prompt.toString();
    }

    private static class DeliveryVanType implements FleetType {
        public String getTypeCode() {
            return "v";
        }

        public String getTypeName() {
            return "delivery van";
        }

        public String getTypeTitle() {
            return "Delivery Van Fleet";
        }

        public String getCreatedMessage() {
            return "Delivery van fleet is created.";
        }

        public String getRoleName(int role) {
            if (role == 1) {
                return "van driver";
            }
            if (role == 2) {
                return "courier driver";
            }
            return null;
        }

        public boolean isValidRole(int role) {
            return getRoleName(role) != null;
        }

        public VehicleFleet createFleet(String fleetID) {
            return new DeliveryVanFleet(fleetID);
        }
    }

    private static class RefrigeratedTruckType implements FleetType {
        public String getTypeCode() {
            return "r";
        }

        public String getTypeName() {
            return "refrigerated truck";
        }

        public String getTypeTitle() {
            return "Refrigerated Truck Fleet";
        }

        public String getCreatedMessage() {
            return "Refrigerated truck fleet is created.";
        }

        public String getRoleName(int role) {
            if (role == 1) {
                return "refrigerated-truck driver";
            }
            if (role == 2) {
                return "cold-chain delivery driver";
            }
            return null;
        }

        public boolean isValidRole(int role) {
            return getRoleName(role) != null;
        }

        public VehicleFleet createFleet(String fleetID) {
            return new RefrigeratedTruckFleet(fleetID);
        }
    }
}
