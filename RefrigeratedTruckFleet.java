/**
 * ITP4507 SDFMS
 *
 * Refrigerated truck fleet.
 * Role 1 is a refrigerated-truck driver.
 * Role 2 is a cold-chain delivery driver.
 * The constants and the two abstract operations from the class diagram
 * are implemented here. No further operation is added.
 */
public class RefrigeratedTruckFleet extends VehicleFleet {
    private final int REFRIGERATED_TRUCK_DRIVER_ROLE = 1;
    private final int COLD_CHAIN_DELIVERY_DRIVER_ROLE = 2;

    /**
     * @param fleetID the fleet id
     */
    public RefrigeratedTruckFleet(String fleetID) {
        super(fleetID);
    }

    @Override
    public void updateDriverRole() {
        System.out.print("Role (1 = refrigerated-truck driver | 2 = cold-chain delivery driver) :- ");
    }

    @Override
    public void showFleet() {
        System.out.println("Refrigerated Truck Fleet " + getName() + " (" + getFleetID() + ")");
        FleetDrivers.printRole(this, REFRIGERATED_TRUCK_DRIVER_ROLE, "Refrigerated-Truck Driver");
        FleetDrivers.printRole(this, COLD_CHAIN_DELIVERY_DRIVER_ROLE, "Cold-Chain Delivery Driver");
    }
}
