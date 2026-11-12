// Abstract fleet from the class diagram. The driver list is a Vector stored as an AbstractList.
import java.util.AbstractList;
import java.util.Iterator;
import java.util.Vector;

public abstract class VehicleFleet {
    private String fleetID;
    private String fleetName;
    private AbstractList<Driver> drivers;

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

    public abstract void updateDriverRole();

    public abstract void showFleet();
}
