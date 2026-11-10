/**
 * Abstract Factory for the refrigerated-truck product family.
 */
public class RefrigeratedTruckFleetFactory implements FleetComponentFactory {

    private final DriverFactory driverFactory = new DriverFactory();

    @Override
    public String getTypeCode() {
        return "r";
    }

    @Override
    public String getTypeLabel() {
        return "refrigerated truck";
    }

    @Override
    public VehicleFleet createFleet(String fleetID) {
        return new RefrigeratedTruckFleet(fleetID);
    }

    @Override
    public Driver createDriver(String driverID) {
        return driverFactory.createDriver(driverID);
    }
}
