/**
 * Changes one driver's role and keeps that change undoable with the Memento pattern.
 * <p>
 * The command is the Caretaker. Before the role changes it asks the driver
 * (the Originator) for a memento, then calls the fleet's
 * {@link VehicleFleet#updateDriverRole()}. A second memento captures the new
 * role so redo restores it the same way undo restores the old one.
 * </p>
 */
public class ModifyDriverRoleCommand implements Command {

    private final SystemContext context;
    private Driver driver;
    private DriverRoleMemento beforeRole;
    private DriverRoleMemento afterRole;
    private String record = "";

    public ModifyDriverRoleCommand(SystemContext context) {
        this.context = context;
    }

    @Override
    public boolean execute() {
        VehicleFleet fleet = context.getManager().getCurrentFleet();
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
        String roleText = context.readLine(fleet.getRolePrompt());
        if (roleText == null) {
            return false;
        }
        Integer role = InputNumbers.parseInt(roleText);
        if (role == null || !fleet.isValidRole(role.intValue())) {
            System.out.println("Invalid role!");
            return false;
        }

        beforeRole = driver.createRoleMemento();
        fleet.prepareRoleUpdate(driver, role.intValue());
        fleet.updateDriverRole();
        afterRole = driver.createRoleMemento();
        record = "Modify driver role, " + driver.getDriverID() + ", "
                + fleet.getRoleListName(driver.getRole());
        System.out.println("Driver role is updated.");
        return true;
    }

    @Override
    public void undo() {
        driver.setRoleMemento(beforeRole);
    }

    @Override
    public void redo() {
        driver.setRoleMemento(afterRole);
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
