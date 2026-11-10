/**
 * Prints the current fleet. Query commands are not stored for undo.
 */
public class ShowFleetCommand implements Command {

    private final SystemContext context;

    public ShowFleetCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        VehicleFleet fleet = context.getManager().getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }
        fleet.showFleet();
        return true;
    }

    @Override
    public void undo() {
    }

    @Override
    public void redo() {
    }

    @Override
    public boolean isUndoable() {
        return false;
    }

    @Override
    public String getRecord() {
        return "";
    }
}
