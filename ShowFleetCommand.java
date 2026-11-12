/**
 * ITP4507 SDFMS
 *
 * Concrete command: show the current fleet. Not undoable.
 * The fleet subclass decides the heading and the role labels.
 */
public class ShowFleetCommand implements Command {
    private FleetSystem system;

    /**
     * @param system where the current fleet is kept
     */
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
