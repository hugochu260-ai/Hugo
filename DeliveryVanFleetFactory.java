/**
 * Abstract Factory for the delivery-van product family.
 */
public class DeliveryVanFleetFactory implements FleetComponentFactory {

    private final DriverFactory driverFactory = new DriverFactory();

    @Override
    public String getTypeCode() {
        return "v";
    }

    @Override
    public String getTypeLabel() {
        return "delivery van";
    }

    @Override
    public VehicleFleet createFleet(String fleetID) {
        return new DeliveryVanFleet(fleetID);
    }

    @Override
    public Driver createDriver(String driverID) {
        return driverFactory.createDriver(driverID);
    }
}
