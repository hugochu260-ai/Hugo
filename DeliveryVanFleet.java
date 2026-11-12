// Delivery van fleet. Role 1 is a van driver. Role 2 is a courier driver.
public class DeliveryVanFleet extends VehicleFleet {
    private final int VAN_DRIVER_ROLE = 1;
    private final int COURIER_DRIVER_ROLE = 2;

    public DeliveryVanFleet(String fleetID) {
        super(fleetID);
    }

    @Override
    public void updateDriverRole() {
        System.out.print("Role (1 = van driver | 2 = courier driver) :- ");
    }

    @Override
    public void showFleet() {
        System.out.println("Delivery Van Fleet " + getName() + " (" + getFleetID() + ")");
        FleetDrivers.printRole(this, VAN_DRIVER_ROLE, "Van Driver");
        FleetDrivers.printRole(this, COURIER_DRIVER_ROLE, "Courier Driver");
    }
}
