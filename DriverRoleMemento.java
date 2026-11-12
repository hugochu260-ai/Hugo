/**
 * ITP4507 SDFMS
 *
 * Memento for one driver's role.
 * This follows the lecture form: the memento keeps the originator and a
 * copy of the state, and {@link #restore()} writes that state back.
 *
 * <pre>
 * public Memento(Originator o) {
 *     orig = o;
 *     state = orig.state;
 * }
 * public void restore() {
 *     orig.state = this.state;
 * }
 * </pre>
 *
 * The role is read and written through Driver's accessors, because the
 * encapsulation rule keeps the field private.
 */
public class DriverRoleMemento {
    private Driver originator;
    private int role;

    /**
     * Saves the driver's role as it is at this moment.
     *
     * @param originator the driver whose role is saved
     */
    public DriverRoleMemento(Driver originator) {
        this.originator = originator;
        this.role = originator.getRole();
    }

    /**
     * Puts the saved role back onto the same driver.
     */
    public void restore() {
        originator.setRole(role);
    }
}
