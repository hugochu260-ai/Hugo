/**
 * Adds a driver to the current fleet.
 * <p>
 * The driver object comes from the fleet's Abstract Factory. The initial role
 * is applied through the polymorphic {@link VehicleFleet#updateDriverRole()}
 * operation. Undo drops the driver; redo inserts the same object at its
 * original index.
 * </p>
 */
public class AddDriverCommand implements Command {

    private final SystemContext context;
    private VehicleFleet fleet;
    private Driver driver;
    private int index;
    private String record = "";

    public AddDriverCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        fleet = context.getManager().getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }
        String line = context.readLine("Please input driver information (id, name):- ");
        if (line == null) {
            return false;
        }
        int comma = line.indexOf(',');
        if (comma < 0) {
            System.out.println("Invalid driver information!");
            return false;
        }
        String driverID = line.substring(0, comma).trim();
        String driverName = line.substring(comma + 1).trim();
        if (driverID.length() == 0 || driverName.length() == 0) {
            System.out.println("Invalid driver information!");
            return false;
        }
        String roleText = context.readLine(fleet.getRolePrompt());
        if (roleText == null) {
            return false;
        }
        Integer role = InputNumbers.parseInt(roleText);
        if (role == null || !fleet.isValidRole(role.intValue())) {
            System.out.println("Invalid role!");
            return false;
        }
        if (fleet.findDriver(driverID) != null) {
            System.out.println("Driver " + driverID + " already exists in the current fleet!");
            return false;
        }

        FleetComponentFactory factory = context.getFleetFactories().getFactoryForFleet(fleet);
        if (factory == null) {
            driver = new DriverFactory().createDriver(driverID);
        } else {
            driver = factory.createDriver(driverID);
        }
        driver.setName(driverName);
        fleet.addDriver(driver);
        fleet.prepareRoleUpdate(driver, role.intValue());
        fleet.updateDriverRole();
        index = fleet.indexOfDriver(driver);
        record = "Add driver, " + driver.getDriverID() + ", " + driver.getName()
                + ", " + fleet.getRoleListName(driver.getRole());
        System.out.println("Driver is added.");
        return true;
    }

    @Override
    public void undo() {
        fleet.dropDriver(driver);
    }

    @Override
    public void redo() {
        fleet.insertDriver(index, driver);
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
