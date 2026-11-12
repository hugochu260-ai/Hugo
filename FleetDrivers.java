// Finds and reprints drivers using getDrivers, addDriver and dropDriver only.
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public final class FleetDrivers {
    private FleetDrivers() {
    }

    public static Driver find(VehicleFleet fleet, String driverID) {
        Iterator<Driver> iterator = fleet.getDrivers();
        while (iterator.hasNext()) {
            Driver driver = iterator.next();
            if (driver.getDriverID().equals(driverID)) {
                return driver;
            }
        }
        return null;
    }

    public static List<Driver> copy(VehicleFleet fleet) {
        List<Driver> drivers = new ArrayList<Driver>();
        Iterator<Driver> iterator = fleet.getDrivers();
        while (iterator.hasNext()) {
            drivers.add(iterator.next());
        }
        return drivers;
    }

    public static void restore(VehicleFleet fleet, List<Driver> order) {
        List<Driver> current = copy(fleet);
        for (int i = 0; i < current.size(); i++) {
            fleet.dropDriver(current.get(i));
        }
        for (int i = 0; i < order.size(); i++) {
            fleet.addDriver(order.get(i));
        }
    }

    public static void printRole(VehicleFleet fleet, int role, String heading) {
        List<Driver> matches = new ArrayList<Driver>();
        Iterator<Driver> iterator = fleet.getDrivers();
        while (iterator.hasNext()) {
            Driver driver = iterator.next();
            if (driver.getRole() == role) {
                matches.add(driver);
            }
        }
        if (matches.isEmpty()) {
            System.out.println(heading + ": NIL");
        } else {
            System.out.println(heading + ":");
            for (int i = 0; i < matches.size(); i++) {
                Driver driver = matches.get(i);
                System.out.println(driver.getDriverID() + ", " + driver.getName());
            }
        }
    }
}
