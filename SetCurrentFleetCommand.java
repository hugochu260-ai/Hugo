/**
 * Selects the current fleet by fleet ID. The selection is not undoable:
 * it does not change fleet data, and the sample history does not list it.
 */
public class SetCurrentFleetCommand implements Command {

    private final SystemContext context;

    public SetCurrentFleetCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        String fleetID = context.readLine("Please input fleet ID:- ");
        if (fleetID == null) {
            return false;
        }
        VehicleFleet fleet = context.getManager().findFleet(fleetID);
        if (fleet == null) {
            System.out.println("Fleet " + fleetID + " is not found!");
            return false;
        }
        context.getManager().setCurrentFleet(fleet);
        System.out.println("Changed current fleet to " + fleet.getFleetID() + ".");
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
