// Saves a fleet name and writes it back on restore.
public class FleetNameMemento {
    private VehicleFleet originator;
    private String fleetName;

    public FleetNameMemento(VehicleFleet originator) {
        this.originator = originator;
        this.fleetName = originator.getName();
    }

    public void restore() {
        originator.setName(fleetName);
    }
}
