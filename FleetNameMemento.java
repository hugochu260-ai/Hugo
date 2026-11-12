/**
 * ITP4507 SDFMS
 *
 * Memento for a fleet name. Same lecture form as {@link DriverRoleMemento}:
 * the originator and the saved name are kept here, and {@link #restore()}
 * writes the name back through {@link VehicleFleet#setName(String)}.
 */
public class FleetNameMemento {
    private VehicleFleet originator;
    private String fleetName;

    /**
     * Saves the fleet name as it is at this moment.
     *
     * @param originator the fleet whose name is saved
     */
    public FleetNameMemento(VehicleFleet originator) {
        this.originator = originator;
        this.fleetName = originator.getName();
    }

    /**
     * Puts the saved name back onto the same fleet.
     */
    public void restore() {
        originator.setName(fleetName);
    }
}
