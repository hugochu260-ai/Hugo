/**
 * ITP4507 SDFMS
 *
 * A driver assigned to one fleet.
 * The attributes and operations below are the ones on the class diagram.
 * Role {@code 0} means the driver has not been given a role yet.
 *
 * Memento originator for the driver's role: a {@link DriverRoleMemento}
 * reads the role through {@link #getRole()} and writes it back through
 * {@link #setRole(int)}. The field itself stays private.
 */
public class Driver {
    private String driverID;
    private String driverName;
    private int role;

    /**
     * @param driverID the driver id. The name is set with {@link #setName(String)}.
     */
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
}
