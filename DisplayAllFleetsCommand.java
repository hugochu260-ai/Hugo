import java.util.List;

/**
 * Prints one summary line for every fleet, in the order the fleets were created.
 */
public class DisplayAllFleetsCommand implements Command {

    private final SystemContext context;

    public DisplayAllFleetsCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        List<VehicleFleet> fleets = context.getManager().getFleets();
        if (fleets.isEmpty()) {
            System.out.println("No fleet record.");
            return true;
        }
        for (int i = 0; i < fleets.size(); i++) {
            System.out.println(fleets.get(i).getSummary());
        }
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
