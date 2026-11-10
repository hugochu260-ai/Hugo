/**
 * Renames the current fleet and keeps the previous name in a Memento.
 * <p>
 * {@link VehicleFleet} is the Originator. This command is the Caretaker:
 * it stores the name from before the change and the name from after it,
 * then asks the fleet to restore one or the other.
 * </p>
 */
public class ChangeFleetNameCommand implements Command {

    private final SystemContext context;
    private VehicleFleet fleet;
    private FleetNameMemento beforeName;
    private FleetNameMemento afterName;
    private String record = "";

    public ChangeFleetNameCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        fleet = context.getManager().getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }
        String name = context.readLine("Please input new name of the current fleet:- ");
        if (name == null) {
            return false;
        }
        if (name.length() == 0) {
            System.out.println("Fleet name cannot be empty!");
            return false;
        }
        beforeName = fleet.createNameMemento();
        fleet.setName(name);
        afterName = fleet.createNameMemento();
        record = "Change fleet name, " + fleet.getFleetID() + ", " + fleet.getName();
        System.out.println("Fleet name is updated.");
        return true;
    }

    @Override
    public void undo() {
        fleet.setNameMemento(beforeName);
    }

    @Override
    public void redo() {
        fleet.setNameMemento(afterName);
    }

    @Override
    public boolean isUndoable() {
        return true;
    }

    @Override
    public String getRecord() {
        return record;
    }
}
