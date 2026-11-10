/**
 * Delivery van fleet. Role 1 is a van driver and role 2 is a courier driver.
 */
public class DeliveryVanFleet extends VehicleFleet {

    private final int VAN_DRIVER_ROLE = 1;
    private final int COURIER_DRIVER_ROLE = 2;

    @SuppressWarnings("this-escape")
    public DeliveryVanFleet(String fleetID) {
        super(fleetID);
        defineRole(VAN_DRIVER_ROLE, "van driver", "Van Driver");
        defineRole(COURIER_DRIVER_ROLE, "courier driver", "Courier Driver");
    }

    @Override
    public void updateDriverRole() {
        Driver driver = getPendingDriver();
        int role = getPendingRole();
        if (driver != null && (role == VAN_DRIVER_ROLE || role == COURIER_DRIVER_ROLE)) {
            driver.setRole(role);
        }
    }

    @Override
    public void showFleet() {
        printFleet();
    }

    @Override
    public String getTypeCode() {
        return "v";
    }

    @Override
    public String getKindTitle() {
        return "Delivery Van Fleet";
    }

    @Override
    public String getHistoryName() {
        return "delivery van fleet";
    }

    @Override
    public String getCreatedMessage() {
        return "Delivery van fleet is created.";
    }
}
