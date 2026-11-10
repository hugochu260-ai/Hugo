/**
 * Memento that stores one fleet's name.
 * <p>
 * {@link VehicleFleet} is the originator. A change-name command is the
 * caretaker: it holds the memento and later asks the fleet to restore it.
 * </p>
 */
public class FleetNameMemento {

    private final String name;

    public FleetNameMemento(String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }
}
