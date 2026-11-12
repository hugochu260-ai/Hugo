import java.util.Scanner;

/**
 * ITP4507 SDFMS
 *
 * Concrete command: change a driver's role.
 * This command is the caretaker of two role mementos. One is taken before
 * the change and one after it. Undo and redo only call {@code restore()}.
 * They do not ask for the role again, and they do not call {@code setRole}
 * themselves. The role name in the history line comes from the factory.
 */
public class ModifyDriverRoleCommand implements UndoableCommand {
    private Scanner scanner;
    private FleetSystem system;
    private VehicleFleetFactory fleetFactory;
    private DriverRoleMemento beforeMemento;
    private DriverRoleMemento afterMemento;
    private String description;

    /**
     * @param scanner      console input
     * @param system       where the current fleet is kept
     * @param fleetFactory supplies the role names for this fleet type
     */
    public ModifyDriverRoleCommand(Scanner scanner, FleetSystem system,
            VehicleFleetFactory fleetFactory) {
        this.scanner = scanner;
        this.system = system;
        this.fleetFactory = fleetFactory;
        this.description = "";
    }

    @Override
    public boolean execute() {
        VehicleFleet fleet = system.getCurrentFleet();
        if (fleet == null) {
            System.out.println("No current fleet!");
            return false;
        }

        System.out.print("Please input driver ID:- ");
        String driverID = scanner.nextLine().trim();
        Driver driver = FleetDrivers.find(fleet, driverID);
        if (driver == null) {
            System.out.println("Driver " + driverID + " is not found in the current fleet!");
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

        beforeMemento = new DriverRoleMemento(driver);
        driver.setRole(role);
        afterMemento = new DriverRoleMemento(driver);
        description = "Modify driver role, " + driverID + ", " + type.getRoleName(role);
        System.out.println("Driver role is updated.");
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
