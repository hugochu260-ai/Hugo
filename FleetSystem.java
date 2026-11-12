import java.util.Vector;

/**
 * ITP4507 SDFMS
 *
 * Receiver for the fleet commands. Keeps every fleet in the order it was
 * created, and remembers which fleet is current.
 * The list is a Vector, which is the list type used in the lectures.
 * There is no public field: other classes go through the methods below.
 */
public class FleetSystem {
    private Vector<VehicleFleet> fleets;
    private VehicleFleet currentFleet;

    public FleetSystem() {
        fleets = new Vector<VehicleFleet>();
        currentFleet = null;
    }

    public VehicleFleet getCurrentFleet() {
        return currentFleet;
    }

    public void setCurrentFleet(VehicleFleet currentFleet) {
        this.currentFleet = currentFleet;
    }

    public void addFleet(VehicleFleet fleet) {
        fleets.add(fleet);
    }

    public void removeFleet(VehicleFleet fleet) {
        fleets.remove(fleet);
    }

    /**
     * @param fleetID the id to find
     * @return the fleet, or {@code null} when no fleet has that id
     */
    public VehicleFleet findFleet(String fleetID) {
        for (int i = 0; i < fleets.size(); i++) {
            VehicleFleet fleet = fleets.get(i);
            if (fleet.getFleetID().equals(fleetID)) {
                return fleet;
            }
        }
        return null;
    }

    public Vector<VehicleFleet> getFleets() {
        return fleets;
    }
}
