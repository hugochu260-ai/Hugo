// Driver from the class diagram. The role is an int.
public class Driver {
    private String driverID;
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
}
