// Creates a Driver and sets the name.
public class DriverFactory {

    public Driver createDriver(String driverID, String name) {
        Driver driver = new Driver(driverID);
        driver.setName(name);
        return driver;
    }
}
