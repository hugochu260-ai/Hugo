import java.util.AbstractList;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Vector;

/**
 * Abstract fleet of delivery vehicles and the drivers assigned to it.
 * <p>
 * Commands depend on this type only, so a new fleet variety can be introduced
 * by subclassing rather than by editing the commands (Open-Closed Principle).
 * {@code updateDriverRole()} and {@code showFleet()} are abstract operations:
 * each concrete fleet interprets roles and prints them in its own vocabulary.
 * </p>
 * <p>
 * This class is also the Originator of the fleet-name Memento.
 * {@code drivers} is an {@link AbstractList}; {@link Vector} is the concrete list.
 * </p>
 */
public abstract class VehicleFleet {

    private final String fleetID;
    private String fleetName;
    private final AbstractList<Driver> drivers;

    private final List<Integer> roleCodes = new ArrayList<Integer>();
    private final List<String> roleListNames = new ArrayList<String>();
    private final List<String> roleHeadings = new ArrayList<String>();

    private Driver pendingDriver;
    private int pendingRole;

    public VehicleFleet(String fleetID) {
        this.fleetID = fleetID;
        this.fleetName = "";
        this.drivers = new Vector<Driver>();
    }

    /**
     * Registers a role this fleet understands. Subclasses call this from
     * their constructor so display order and validation stay together.
     */
    protected final void defineRole(int code, String listName, String heading) {
        roleCodes.add(Integer.valueOf(code));
        roleListNames.add(listName);
        roleHeadings.add(heading);
    }

    public String getFleetID() {
        return fleetID;
    }

    public String getName() {
        return fleetName;
    }

    public void setName(String name) {
        this.fleetName = name;
    }

    public void addDriver(Driver driver) {
        drivers.add(driver);
    }

    public void dropDriver(Driver driver) {
        drivers.remove(driver);
    }

    /**
     * Puts a driver back at the index it occupied before a delete, so undo
     * restores the original listing order.
     */
    public void insertDriver(int index, Driver driver) {
        drivers.add(index, driver);
    }

    public int indexOfDriver(Driver driver) {
        return drivers.indexOf(driver);
    }

    public Iterator<Driver> getDrivers() {
        return drivers.iterator();
    }

    public Driver findDriver(String driverID) {
        Iterator<Driver> iterator = getDrivers();
        while (iterator.hasNext()) {
            Driver driver = iterator.next();
            if (driver.getDriverID().equals(driverID)) {
                return driver;
            }
        }
        return null;
    }

    /**
     * Applies a role change that was prepared with {@link #prepareRoleUpdate}.
     * Concrete fleets accept only their own role codes.
     */
    public abstract void updateDriverRole();

    /** Prints this fleet and its drivers grouped by role. */
    public abstract void showFleet();

    /**
     * Records which driver and role {@link #updateDriverRole()} should apply.
     * The command sets this, then calls the polymorphic update operation.
     */
    public void prepareRoleUpdate(Driver driver, int role) {
        this.pendingDriver = driver;
        this.pendingRole = role;
    }

    protected final Driver getPendingDriver() {
        return pendingDriver;
    }

    protected final int getPendingRole() {
        return pendingRole;
    }

    public boolean isValidRole(int role) {
        return roleIndex(role) >= 0;
    }

    /** Lower-case role name used in the undo list, for example {@code van driver}. */
    public String getRoleListName(int role) {
        int index = roleIndex(role);
        if (index < 0) {
            return "unknown role";
        }
        return roleListNames.get(index);
    }

    public String getRolePrompt() {
        StringBuilder builder = new StringBuilder("Role (");
        for (int i = 0; i < roleCodes.size(); i++) {
            if (i > 0) {
                builder.append(" | ");
            }
            builder.append(roleCodes.get(i).intValue());
            builder.append(" = ");
            builder.append(roleListNames.get(i));
        }
        builder.append(") :- ");
        return builder.toString();
    }

    /**
     * Shared listing used by each subclass {@code showFleet()}. Headings and
     * the fleet title still come from the concrete fleet.
     */
    protected final void printFleet() {
        System.out.println(getSummary());
        for (int i = 0; i < roleCodes.size(); i++) {
            int code = roleCodes.get(i).intValue();
            List<Driver> group = new ArrayList<Driver>();
            Iterator<Driver> iterator = getDrivers();
            while (iterator.hasNext()) {
                Driver driver = iterator.next();
                if (driver.getRole() == code) {
                    group.add(driver);
                }
            }
            if (group.isEmpty()) {
                System.out.println(roleHeadings.get(i) + ": NIL");
            } else {
                System.out.println(roleHeadings.get(i) + ":");
                for (int d = 0; d < group.size(); d++) {
                    Driver driver = group.get(d);
                    System.out.println(driver.getDriverID() + ", " + driver.getName());
                }
            }
        }
    }

    public String getSummary() {
        return getKindTitle() + " " + fleetName + " (" + fleetID + ")";
    }

    /** Menu and factory code for this fleet variety, for example {@code v}. */
    public abstract String getTypeCode();

    /** Title used when the fleet is printed, for example {@code Delivery Van Fleet}. */
    public abstract String getKindTitle();

    /** Phrase used in the undo record, for example {@code delivery van fleet}. */
    public abstract String getHistoryName();

    /** Confirmation printed when a fleet of this type is created. */
    public abstract String getCreatedMessage();

    /** Originator operation: capture the fleet name. */
    public FleetNameMemento createNameMemento() {
        return new FleetNameMemento(fleetName);
    }

    /** Originator operation: restore a fleet name from a memento. */
    public void setNameMemento(FleetNameMemento memento) {
        setName(memento.getName());
    }

    private int roleIndex(int role) {
        for (int i = 0; i < roleCodes.size(); i++) {
            if (roleCodes.get(i).intValue() == role) {
                return i;
            }
        }
        return -1;
    }
}
