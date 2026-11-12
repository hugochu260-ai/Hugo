/**
 * ITP4507 SDFMS
 *
 * Factory for {@link Driver}. Callers do not use {@code new Driver}
 * themselves. The name is applied with {@link Driver#setName(String)},
 * which is the operation on the class diagram. The role is set by the
 * command after the user has chosen a legal role for that fleet.
 */
public class DriverFactory {
    /**
     * @param driverID the driver id
     * @param name     the driver name
     * @return a new driver with no role yet
     */
    public Driver createDriver(String driverID, String name) {
        Driver driver = new Driver(driverID);
        driver.setName(name);
        return driver;
    }
}
