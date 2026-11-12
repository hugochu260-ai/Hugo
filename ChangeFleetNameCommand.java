// Renames the current fleet. Undo and redo restore the saved name mementos.
import java.util.Scanner;

public class ChangeFleetNameCommand implements UndoableCommand {
    private Scanner scanner;
    private FleetSystem system;
    private FleetNameMemento beforeMemento;
    private FleetNameMemento afterMemento;
    private String description;

    public ChangeFleetNameCommand(Scanner scanner, FleetSystem system) {
        this.scanner = scanner;
        this.system = system;
        this.description = "";
    }

    @Override
    public boolean execute() {
        VehicleFleet fleet = system.getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }

        System.out.print("Please input new name of the current fleet:- ");
        String newName = scanner.nextLine().trim();
        if (newName.length() == 0) {
            System.out.println("Fleet name cannot be empty!");
            return false;
        }

        beforeMemento = new FleetNameMemento(fleet);
        fleet.setName(newName);
        afterMemento = new FleetNameMemento(fleet);
        description = "Change fleet name, " + fleet.getFleetID() + ", " + newName;
        System.out.println("Fleet name is updated.");
        return true;
    }

    @Override
    public void undo() {
        beforeMemento.restore();
    }

    @Override
    public void redo() {
        afterMemento.restore();
    }

    @Override
    public String toString() {
        return description;
    }
}
