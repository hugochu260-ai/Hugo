// Adds a driver to the fleet that is current when the command runs.
import java.util.Scanner;

public class AddDriverCommand implements UndoableCommand {
    private Scanner scanner;
    private FleetSystem system;
    private DriverFactory driverFactory;
    private VehicleFleetFactory fleetFactory;
    private VehicleFleet fleet;
    private Driver driver;
    private String description;

    public AddDriverCommand(Scanner scanner, FleetSystem system, DriverFactory driverFactory,
            VehicleFleetFactory fleetFactory) {
        this.scanner = scanner;
        this.system = system;
        this.driverFactory = driverFactory;
        this.fleetFactory = fleetFactory;
        this.description = "";
    }

    @Override
    public boolean execute() {
        fleet = system.getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }

        System.out.print("Please input driver information (id, name):- ");
        String line = scanner.nextLine().trim();
        int comma = line.indexOf(',');
        if (comma < 0) {
            System.out.println("Invalid driver information!");
            return false;
        }
        String driverID = line.substring(0, comma).trim();
        String name = line.substring(comma + 1).trim();
        if (driverID.length() == 0 || name.length() == 0) {
            System.out.println("Invalid driver information!");
            return false;
        }
        if (FleetDrivers.find(fleet, driverID) != null) {
            System.out.println("Driver " + driverID + " already exists in the current fleet!");
            return false;
        }

        VehicleFleetFactory.FleetType type = fleetFactory.typeOf(fleet);

        fleet.updateDriverRole();
        String roleText = scanner.nextLine().trim();
        int role;
        try {
            role = Integer.parseInt(roleText);
        } catch (NumberFormatException ex) {
            System.out.println("Invalid role!");
            return false;
        }
        if (type == null || !type.isValidRole(role)) {
            System.out.println("Invalid role!");
            return false;
        }

        driver = driverFactory.createDriver(driverID, name);
        driver.setRole(role);
        fleet.addDriver(driver);
        description = "Add driver, " + driverID + ", " + name + ", " + type.getRoleName(role);
        System.out.println("Driver is added.");
        return true;
    }

    @Override
    public void undo() {
        fleet.dropDriver(driver);
    }

    @Override
    public void redo() {
        fleet.addDriver(driver);
    }

    @Override
    public String toString() {
        return description;
    }
}
