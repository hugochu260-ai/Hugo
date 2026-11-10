/**
 * A driver assigned to one vehicle fleet.
 * <p>
 * This class is the Originator of the role Memento. The role is an integer
 * code whose meaning depends on the fleet type (van driver, courier driver,
 * and so on). The fleet, not the driver, knows those names.
 * </p>
 */
public class Driver {

    private final String driverID;
    private String driverName;
    private int role;

    public Driver(String driverID) {
        this.driverID = driverID;
        this.driverName = "";
        this.role = 0;
    }

    public String getDriverID() {
        return driverID;
    }

    public int getRole() {
        return role;
    }

    public void setRole(int role) {
        this.role = role;
    }

    public String getName() {
        return driverName;
    }

    public void setName(String name) {
        this.driverName = name;
    }

    /** Captures the current role. This is the originator's createMemento operation. */
    public DriverRoleMemento createRoleMemento() {
        return new DriverRoleMemento(role);
    }

    /** Restores a role previously captured by {@link #createRoleMemento()}. */
    public void setRoleMemento(DriverRoleMemento memento) {
        setRole(memento.getRole());
    }
}
