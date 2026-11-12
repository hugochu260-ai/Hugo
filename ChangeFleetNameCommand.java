import java.util.Scanner;

/**
 * ITP4507 SDFMS
 *
 * Concrete command: change the name of the current fleet.
 * This command is the caretaker of two {@link FleetNameMemento} objects.
 * Undo restores the name from before the change. Redo restores the name
 * from after the change.
 */
public class ChangeFleetNameCommand implements UndoableCommand {
    private Scanner scanner;
    private FleetSystem system;
    private FleetNameMemento beforeMemento;
    private FleetNameMemento afterMemento;
    private String description;

    /**
     * @param scanner console input
     * @param system  where the current fleet is kept
     */
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
