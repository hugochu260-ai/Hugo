/**
 * Memento that stores one driver's role.
 * <p>
 * Only the {@link Driver} originator creates this object and writes the saved
 * role back. Command objects keep the memento so they can request a restore,
 * without interpreting the saved value themselves.
 * </p>
 */
public class DriverRoleMemento {

    private final int role;

    public DriverRoleMemento(int role) {
        this.role = role;
    }

    public int getRole() {
        return role;
    }
}
