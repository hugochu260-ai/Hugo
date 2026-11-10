import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Receiver for fleet commands. Holds every fleet and remembers which one is current.
 */
public class FleetManager {

    private final List<VehicleFleet> fleets = new ArrayList<VehicleFleet>();
    private VehicleFleet currentFleet;

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

    public List<VehicleFleet> getFleets() {
        return Collections.unmodifiableList(fleets);
    }

    public VehicleFleet getCurrentFleet() {
        return currentFleet;
    }

    public void setCurrentFleet(VehicleFleet currentFleet) {
        this.currentFleet = currentFleet;
    }
}
