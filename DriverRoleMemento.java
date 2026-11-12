// Saves one driver's role and writes it back on restore.
public class DriverRoleMemento {
    private Driver originator;
    private int role;

    public DriverRoleMemento(Driver originator) {
        this.originator = originator;
        this.role = originator.getRole();
    }

    public void restore() {
        originator.setRole(role);
    }
}
