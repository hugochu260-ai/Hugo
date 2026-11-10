/**
 * Removes a driver from the current fleet.
 * Undo inserts the same driver object at the index it had before the delete.
 */
public class DeleteDriverCommand implements Command {

    private final SystemContext context;
    private VehicleFleet fleet;
    private Driver driver;
    private int index;
    private String record = "";

    public DeleteDriverCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        fleet = context.getManager().getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }
        String driverID = context.readLine("Please input driver ID:- ");
        if (driverID == null) {
            return false;
        }
        driver = fleet.findDriver(driverID);
        if (driver == null) {
            System.out.println("Driver " + driverID + " is not found in the current fleet!");
            return false;
        }
        index = fleet.indexOfDriver(driver);
        fleet.dropDriver(driver);
        record = "Delete driver, " + driver.getDriverID();
        System.out.println("Driver is deleted.");
        return true;
    }

    @Override
    public void undo() {
        fleet.insertDriver(index, driver);
    }

    @Override
    public void redo() {
        fleet.dropDriver(driver);
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
