/**
 * Abstract Factory for one family of fleet products.
 * <p>
 * Each concrete factory creates the {@link VehicleFleet} subclass and the
 * {@link Driver} objects that belong to that fleet type. Adding a fleet
 * variety means adding a new factory and registering it. Existing factories
 * stay unchanged (Open-Closed Principle).
 * </p>
 */
public interface FleetComponentFactory {

    /** Menu code, for example {@code v} or {@code r}. */
    String getTypeCode();

    /** Words used in the fleet-type prompt, for example {@code delivery van}. */
    String getTypeLabel();

    VehicleFleet createFleet(String fleetID);

    Driver createDriver(String driverID);
}
