// Deletes a driver. Undo puts the drivers back in the previous order.
import java.util.List;
import java.util.Scanner;

public class DeleteDriverCommand implements UndoableCommand {
    private Scanner scanner;
    private FleetSystem system;
    private VehicleFleet fleet;
    private Driver driver;
    private List<Driver> driversBeforeDelete;
    private String description;

    public DeleteDriverCommand(Scanner scanner, FleetSystem system) {
        this.scanner = scanner;
        this.system = system;
        this.description = "";
    }

    @Override
    public boolean execute() {
        fleet = system.getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }

        System.out.print("Please input driver ID:- ");
        String driverID = scanner.nextLine().trim();
        driver = FleetDrivers.find(fleet, driverID);
        if (driver == null) {
            System.out.println("Driver " + driverID + " is not found in the current fleet!");
            return false;
        }

        driversBeforeDelete = FleetDrivers.copy(fleet);
        fleet.dropDriver(driver);
        description = "Delete driver, " + driverID;
        System.out.println("Driver is deleted.");
        return true;
    }

    @Override
    public void undo() {
        FleetDrivers.restore(fleet, driversBeforeDelete);
    }

    @Override
    public void redo() {
        fleet.dropDriver(driver);
    }

    @Override
    public String toString() {
        return description;
    }
}
