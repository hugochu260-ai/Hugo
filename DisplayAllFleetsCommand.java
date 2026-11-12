// Lists every fleet in creation order, without drivers.
import java.util.Vector;

public class DisplayAllFleetsCommand implements Command {
    private FleetSystem system;
    private VehicleFleetFactory fleetFactory;

    public DisplayAllFleetsCommand(FleetSystem system, VehicleFleetFactory fleetFactory) {
        this.system = system;
        this.fleetFactory = fleetFactory;
    }

    @Override
    public boolean execute() {
        Vector<VehicleFleet> fleets = system.getFleets();
        if (fleets.isEmpty()) {
            System.out.println("No fleet record!");
            return true;
        }
        for (int i = 0; i < fleets.size(); i++) {
            System.out.println(fleetFactory.getSummary(fleets.get(i)));
        }
        return true;
    }
}
