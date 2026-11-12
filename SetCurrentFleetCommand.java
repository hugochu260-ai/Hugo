import java.util.Scanner;

/**
 * ITP4507 SDFMS
 *
 * Concrete command: select the current fleet by id.
 * The sample undo list does not include this action, so the class does
 * not implement {@link UndoableCommand}.
 */
public class SetCurrentFleetCommand implements Command {
    private Scanner scanner;
    private FleetSystem system;

    /**
     * @param scanner console input
     * @param system  where fleets are stored
     */
    public SetCurrentFleetCommand(Scanner scanner, FleetSystem system) {
        this.scanner = scanner;
        this.system = system;
    }

    @Override
    public boolean execute() {
        System.out.print("Please input fleet ID:- ");
        String fleetID = scanner.nextLine().trim();
        VehicleFleet fleet = system.findFleet(fleetID);
        if (fleet == null) {
            System.out.println("Fleet " + fleetID + " is not found!");
            return false;
        }
        system.setCurrentFleet(fleet);
        System.out.println("Changed current fleet to " + fleet.getFleetID() + ".");
        return true;
    }
}
