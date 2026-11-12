import java.util.Vector;

/**
 * ITP4507 SDFMS
 *
 * Concrete command: list every fleet in creation order, without drivers.
 * The heading comes from the factory that created the fleet, so a new
 * fleet type appears here with no change to this command and with no
 * extra operation on {@link VehicleFleet}.
 */
public class DisplayAllFleetsCommand implements Command {
    private FleetSystem system;
    private VehicleFleetFactory fleetFactory;

    /**
     * @param system       where the fleets are stored
     * @param fleetFactory supplies the one-line heading for each fleet
     */
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
