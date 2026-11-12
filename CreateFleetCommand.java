// Creates a fleet, selects it, and can undo and redo that create.
import java.util.Scanner;

public class CreateFleetCommand implements UndoableCommand {
    private Scanner scanner;
    private FleetSystem system;
    private VehicleFleetFactory fleetFactory;
    private VehicleFleet createdFleet;
    private VehicleFleet previousCurrent;
    private String description;

    public CreateFleetCommand(Scanner scanner, FleetSystem system,
            VehicleFleetFactory fleetFactory) {
        this.scanner = scanner;
        this.system = system;
        this.fleetFactory = fleetFactory;
        this.description = "";
    }

    @Override
    public boolean execute() {
        System.out.print(fleetFactory.getTypePrompt());
        String typeCode = scanner.nextLine().trim();
        VehicleFleetFactory.FleetType type = fleetFactory.getType(typeCode);
        if (type == null) {
            System.out.println("Invalid fleet type!");
            return false;
        }

        System.out.print("Fleet ID:- ");
        String fleetID = scanner.nextLine().trim();
        if (fleetID.length() == 0) {
            System.out.println("Fleet ID cannot be empty!");
            return false;
        }
        if (system.findFleet(fleetID) != null) {
            System.out.println("Fleet ID already exists!");
            return false;
        }

        System.out.print("Fleet Name:- ");
        String fleetName = scanner.nextLine().trim();
        if (fleetName.length() == 0) {
            System.out.println("Fleet name cannot be empty!");
            return false;
        }

        createdFleet = fleetFactory.createFleet(type, fleetID);
        createdFleet.setName(fleetName);
        previousCurrent = system.getCurrentFleet();
        system.addFleet(createdFleet);
        system.setCurrentFleet(createdFleet);

        description = "Create " + type.getTypeName() + " fleet, "
                + fleetID + ", " + fleetName;
        System.out.println(type.getCreatedMessage());
        System.out.println("Current fleet is changed to " + fleetID + ".");
        return true;
    }

    @Override
    public void undo() {
        system.removeFleet(createdFleet);
        if (system.getCurrentFleet() == createdFleet) {
            system.setCurrentFleet(previousCurrent);
        }
    }

    @Override
    public void redo() {
        if (system.findFleet(createdFleet.getFleetID()) == null) {
            system.addFleet(createdFleet);
        }
        system.setCurrentFleet(createdFleet);
    }

    @Override
    public String toString() {
        return description;
    }
}
