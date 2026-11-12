// Shows the current fleet, including its drivers.
public class ShowFleetCommand implements Command {
    private FleetSystem system;

    public ShowFleetCommand(FleetSystem system) {
        this.system = system;
    }

    @Override
    public boolean execute() {
        VehicleFleet fleet = system.getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }
        fleet.showFleet();
        return true;
    }
}
