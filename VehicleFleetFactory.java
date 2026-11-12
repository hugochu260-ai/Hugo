import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * ITP4507 SDFMS
 *
 * Factory for vehicle fleets.
 * The lecture's factory method is the {@link FleetType#createFleet(String)}
 * operation. Each concrete fleet type supplies its own implementation, so
 * {@link CreateFleetCommand} never contains {@code new DeliveryVanFleet}
 * or {@code new RefrigeratedTruckFleet}.
 *
 * The two built-in types are registered in the constructor. A further type,
 * such as a motorcycle fleet, is added by writing the new subclass and
 * calling {@link #register(FleetType)}. DeliveryVanFleet and
 * RefrigeratedTruckFleet are not edited. That is the Open-Closed Principle
 * as required for new fleet types.
 *
 * Role names, the created-fleet sentence and the display title also live
 * here. They are not operations of {@link VehicleFleet}. The numbers match
 * the private role constants on the matching subclass: 1 and 2.
 *
 * The type prompt is built from the registered types, in registration order.
 * With the two built-in types it is exactly:
 * {@code Enter fleet type (v = delivery van | r = refrigerated truck) :- }
 */
public final class VehicleFleetFactory {
    /**
     * One creatable fleet type. A new fleet is a new implementation of this
     * interface plus one {@link VehicleFleetFactory#register(FleetType)} call.
     */
    public interface FleetType {
        /** @return the code the user types, for example {@code "v"} */
        String getTypeCode();

        /** @return the lower-case name used in the prompt and the undo text */
        String getTypeName();

        /**
         * @return the heading used when the fleet is shown, for example
         *         {@code "Delivery Van Fleet"}
         */
        String getTypeTitle();

        /** @return the sentence printed after a fleet of this type is created */
        String getCreatedMessage();

        /**
         * @param role a role number
         * @return the lower-case role name used in the undo list, or {@code null}
         *         when this fleet does not use that number
         */
        String getRoleName(int role);

        /**
         * @param role a role number typed by the user
         * @return {@code true} when this fleet accepts that role
         */
        boolean isValidRole(int role);

        /**
         * @param fleetID the id of the new fleet
         * @return a new fleet of this type
         */
        VehicleFleet createFleet(String fleetID);
    }

    private LinkedHashMap<String, FleetType> types;
    private Map<VehicleFleet, FleetType> created;

    /**
     * Registers the delivery van fleet and the refrigerated truck fleet.
     */
    public VehicleFleetFactory() {
        types = new LinkedHashMap<String, FleetType>();
        created = new HashMap<VehicleFleet, FleetType>();
        register(new DeliveryVanType());
        register(new RefrigeratedTruckType());
    }

    /**
     * @param type a fleet type to make available
     */
    public final void register(FleetType type) {
        types.put(type.getTypeCode(), type);
    }

    /**
     * @param typeCode the code typed by the user
     * @return the type, or {@code null} when the code is not registered
     */
    public FleetType getType(String typeCode) {
        if (typeCode == null) {
            return null;
        }
        return types.get(typeCode);
    }

    /**
     * Creates a fleet and remembers which type it is, so later commands can
     * ask for the role name and the display title without a new operation
     * on {@link VehicleFleet}.
     *
     * @param type    the registered type
     * @param fleetID the id of the new fleet
     * @return the new fleet
     */
    public VehicleFleet createFleet(FleetType type, String fleetID) {
        VehicleFleet fleet = type.createFleet(fleetID);
        created.put(fleet, type);
        return fleet;
    }

    /**
     * @param fleet a fleet this factory created
     * @return its type, or {@code null} when this factory did not create it
     */
    public FleetType typeOf(VehicleFleet fleet) {
        if (fleet == null) {
            return null;
        }
        return created.get(fleet);
    }

    /**
     * One-line heading shared by display-all.
     * Show-fleet prints the same heading and then the drivers.
     *
     * @param fleet a fleet this factory created
     * @return the heading, for example {@code "Delivery Van Fleet CITY (F001)"}
     */
    public String getSummary(VehicleFleet fleet) {
        FleetType type = typeOf(fleet);
        String title = type.getTypeTitle();
        return title + " " + fleet.getName() + " (" + fleet.getFleetID() + ")";
    }

    /**
     * @return the fleet-type prompt, with a trailing space and no newline
     */
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

    /** Factory method product: a delivery van fleet. */
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

    /** Factory method product: a refrigerated truck fleet. */
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
