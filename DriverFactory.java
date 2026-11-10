/**
 * Simple Factory that creates {@link Driver} objects.
 * <p>
 * Callers do not invoke {@code new Driver} directly. Fleet factories delegate
 * here so every driver is created in one place.
 * </p>
 */
public class DriverFactory {

    public Driver createDriver(String driverID) {
        return new Driver(driverID);
    }
}
