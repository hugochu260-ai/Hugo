import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * ITP4507 SDFMS
 *
 * Works with the drivers of a fleet without adding operations to
 * {@link VehicleFleet}. Every read uses {@link VehicleFleet#getDrivers()}.
 * Putting a deleted driver back uses {@link VehicleFleet#dropDriver(Driver)}
 * and {@link VehicleFleet#addDriver(Driver)} only.
 */
public final class FleetDrivers {
    private FleetDrivers() {
    }

    /**
     * @param fleet    the fleet to search
     * @param driverID the id to find
     * @return the driver in this fleet, or {@code null}
     */
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

    /**
     * @param fleet the fleet to copy
     * @return the drivers in their current order
     */
    public static List<Driver> copy(VehicleFleet fleet) {
        List<Driver> drivers = new ArrayList<Driver>();
        Iterator<Driver> iterator = fleet.getDrivers();
        while (iterator.hasNext()) {
            drivers.add(iterator.next());
        }
        return drivers;
    }

    /**
     * Replaces the fleet's drivers with {@code order}.
     * Used when a delete is undone, so the deleted driver returns to the
     * position it had. Later role changes stay on the driver objects.
     *
     * @param fleet the fleet to rebuild
     * @param order the drivers in the required order
     */
    public static void restore(VehicleFleet fleet, List<Driver> order) {
        List<Driver> current = copy(fleet);
        for (int i = 0; i < current.size(); i++) {
            fleet.dropDriver(current.get(i));
        }
        for (int i = 0; i < order.size(); i++) {
            fleet.addDriver(order.get(i));
        }
    }

    /**
     * Prints one role group. An empty group is {@code Heading: NIL}.
     * Drivers stay in the order they were added.
     *
     * @param fleet   the fleet to print
     * @param role    the role number
     * @param heading the label, for example {@code "Van Driver"}
     */
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
