import java.util.AbstractList;
import java.util.Iterator;
import java.util.Vector;

/**
 * ITP4507 SDFMS
 *
 * Abstract fleet. The attributes and operations are the ones on the class
 * diagram, and no others are added. {@code drivers} is an AbstractList.
 * The assignment allows Vector or LinkedList as the concrete list. The
 * Vector is created here, in the constructor, so that choice stays in one
 * place. addDriver, dropDriver and getDrivers use the AbstractList field.
 *
 * A new fleet type is a new subclass. This class does not grow a branch
 * for each type.
 */
public abstract class VehicleFleet {
    private String fleetID;
    private String fleetName;
    private AbstractList<Driver> drivers;

    /**
     * @param fleetID the fleet id. The name is set later with {@link #setName(String)}.
     */
    public VehicleFleet(String fleetID) {
        this.fleetID = fleetID;
        this.drivers = new Vector<Driver>();
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

    public Iterator<Driver> getDrivers() {
        return drivers.iterator();
    }

    /**
     * Presents this fleet's role choices.
     * The diagram operation has no arguments, so the subclass cannot be
     * handed a driver or a new role. It prints the role prompt. The command
     * reads the number and applies it with {@link Driver#setRole(int)}.
     */
    public abstract void updateDriverRole();

    /**
     * Prints this fleet and its drivers, grouped by role.
     */
    public abstract void showFleet();
}
