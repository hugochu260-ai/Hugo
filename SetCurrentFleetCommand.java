// Selects the current fleet by id. This command is not undoable.
import java.util.Scanner;

public class SetCurrentFleetCommand implements Command {
    private Scanner scanner;
    private FleetSystem system;

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
