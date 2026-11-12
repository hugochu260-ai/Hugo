// Stores every fleet, in creation order, and the current fleet.
import java.util.Vector;

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
